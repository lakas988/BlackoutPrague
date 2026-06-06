import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_message.dart';
import 'device_id_service.dart';
import 'mesh_foreground_service.dart';
import 'mesh_notification_service.dart';
import 'mesh_settings_service.dart';
import 'message_service.dart';

class RealBleMeshService extends ChangeNotifier {
  RealBleMeshService._();

  static final RealBleMeshService instance = RealBleMeshService._();
  static const int _manufacturerId = 0x4247;
  static const Duration _advertisingWindow = Duration(seconds: 30);
  static const Duration _seenRetention = Duration(hours: 24);
  static const String _seenMessagesKey = 'blackout_prague_seen_mesh_messages';

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final MessageService _messageService = MessageService.instance;
  final DeviceIdService _deviceIdService = DeviceIdService.instance;
  final MeshSettingsService _meshSettingsService = MeshSettingsService.instance;
  final MeshForegroundService _meshForegroundService = MeshForegroundService.instance;
  final MeshNotificationService _meshNotificationService = MeshNotificationService.instance;
  final Map<String, DateTime> _seenMessageIds = <String, DateTime>{};

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _advertisingTimer;

  bool _isEnabled = false;
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isAdvertisingSupported = true;
  bool _seenMessagesLoaded = false;
  int _receivedCount = 0;
  String _permissionStatus = 'Neověřeno';
  String? _lastError;

  bool get isEnabled => _isEnabled;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  bool get isAdvertisingSupported => _isAdvertisingSupported;
  int get receivedCount => _receivedCount;
  String get permissionStatus => _permissionStatus;
  String? get lastError => _lastError;

  Future<bool> hasBluetoothPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    final scanGranted = await Permission.bluetoothScan.isGranted;
    final advertiseGranted = await Permission.bluetoothAdvertise.isGranted;
    final connectGranted = await Permission.bluetoothConnect.isGranted;
    final locationGranted = await Permission.locationWhenInUse.isGranted;
    return scanGranted && advertiseGranted && connectGranted && locationGranted;
  }

  Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      _permissionStatus = 'Reálné BLE je dostupné jen na Androidu';
      _lastError = _permissionStatus;
      notifyListeners();
      return false;
    }

    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final advertiseGranted = statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      final peripheralState = await _peripheral.requestPermission();
      final peripheralGranted = peripheralState == BluetoothPeripheralState.granted;

      final granted = scanGranted && advertiseGranted && connectGranted && locationGranted && peripheralGranted;
      _permissionStatus = granted ? 'Povoleno' : 'Nepovoleno';
      _lastError = granted ? null : 'Bluetooth oprávnění nebyla povolena.';
      notifyListeners();
      return granted;
    } catch (_) {
      _permissionStatus = 'Nelze ověřit';
      _lastError = 'Bluetooth oprávnění se nepodařilo ověřit.';
      notifyListeners();
      return false;
    }
  }

  Future<void> startRealBle({bool requestPermissions = true}) async {
    _isEnabled = true;
    notifyListeners();

    final granted = requestPermissions ? await requestBluetoothPermissions() : await hasBluetoothPermissions();
    if (!granted) {
      _permissionStatus = 'Nepovoleno';
      _lastError = 'BLE mesh nelze spustit bez oprávnění Bluetooth.';
      await stopScan();
      notifyListeners();
      return;
    }

    await startScan();
    await updateForegroundServiceForSettings();
  }

  Future<void> stopRealBle() async {
    _isEnabled = false;
    await stopScan();
    await stopAdvertising();
    await _meshForegroundService.stop();
    notifyListeners();
  }

  Future<void> updateForegroundServiceForSettings() async {
    await _meshSettingsService.load();
    if (_isEnabled && _isScanning && _meshSettingsService.backgroundMeshEnabled) {
      await _meshForegroundService.start();
    } else {
      await _meshForegroundService.stop();
    }
  }

  Future<void> startScan() async {
    if (!_isEnabled || _isScanning) {
      return;
    }

    try {
      await _loadSeenMessages();
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _lastError = 'Toto zařízení nepodporuje Bluetooth LE.';
        notifyListeners();
        return;
      }

      _scanSubscription ??= FlutterBluePlus.onScanResults.listen(_handleScanResults);
      await FlutterBluePlus.startScan(
        withMsd: [MsdFilter(_manufacturerId, data: ascii.encode('BP'), mask: [0xFF, 0xFF])],
        androidScanMode: AndroidScanMode.lowPower,
        androidUsesFineLocation: true,
        androidCheckLocationServices: false,
        continuousUpdates: true,
        oneByOne: true,
      );
      _isScanning = true;
      _lastError = null;
      notifyListeners();
    } catch (_) {
      _isScanning = false;
      _lastError = 'Skenování BLE se nepodařilo spustit.';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Scan may already be stopped by the platform.
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> broadcastMessage(EmergencyMessage message) async {
    if (!_isEnabled) {
      _lastError = 'Zapněte BLE mesh pro odeslání.';
      notifyListeners();
      return false;
    }

    if (message.isExpired) {
      debugPrint('BLE mesh: message expired ${message.id}');
      _lastError = 'Zpráva je po platnosti a nebude odeslána.';
      notifyListeners();
      return false;
    }

    if (message.hopCount >= message.maxHops) {
      debugPrint('BLE mesh: max hops reached ${message.id}');
      _lastError = 'Zpráva dosáhla limitu předání.';
      notifyListeners();
      return false;
    }

    final granted = await requestBluetoothPermissions();
    if (!granted) {
      return false;
    }

    try {
      await _loadSeenMessages();
      final supported = await _peripheral.isSupported;
      _isAdvertisingSupported = supported;
      if (!supported) {
        _lastError = 'Toto zařízení nepodporuje BLE vysílání.';
        notifyListeners();
        return false;
      }

      await _rememberSeenMessage(message.id);
      final payload = _encodeMessage(message);
      await stopAdvertising();
      await _peripheral.start(
        advertiseData: AdvertiseData(
          manufacturerId: _manufacturerId,
          manufacturerData: Uint8List.fromList(utf8.encode(payload)),
          includeDeviceName: false,
        ),
      );

      _isAdvertising = true;
      _lastError = null;
      _advertisingTimer?.cancel();
      _advertisingTimer = Timer(_advertisingWindow, stopAdvertising);
      notifyListeners();
      return true;
    } catch (_) {
      _isAdvertising = false;
      _lastError = 'Toto zařízení nepodporuje BLE vysílání.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> relayMessage(EmergencyMessage message) async {
    if (message.isExpired) {
      debugPrint('BLE mesh: message expired ${message.id}');
      _lastError = 'Zpráva je po platnosti a nebude předána dál.';
      notifyListeners();
      return false;
    }

    if (message.hopCount >= message.maxHops) {
      debugPrint('BLE mesh: max hops reached ${message.id}');
      _lastError = 'Zpráva dosáhla limitu předání.';
      notifyListeners();
      return false;
    }

    return broadcastMessage(message.copyWith(hopCount: message.hopCount + 1));
  }

  Future<void> stopAdvertising() async {
    _advertisingTimer?.cancel();
    _advertisingTimer = null;
    try {
      await _peripheral.stop();
    } catch (_) {
      // Advertising may already be stopped by the platform.
    }
    _isAdvertising = false;
    notifyListeners();
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      _handleScanResult(result);
    }
  }

  Future<void> _handleScanResult(ScanResult result) async {
    final payload = _payloadFromAdvertisement(result.advertisementData);
    if (payload == null) {
      return;
    }

    final parsed = _ParsedBleMessage.tryParse(payload);
    if (parsed == null) {
      return;
    }

    await _loadSeenMessages();
    final myDeviceId = await _deviceIdService.getDeviceId();
    if (parsed.originDeviceId == myDeviceId) {
      debugPrint('BLE mesh: own message ignored ${parsed.messageId}');
      await _rememberSeenMessage(parsed.messageId);
      return;
    }

    if (_hasSeenMessage(parsed.messageId) || await _messageService.hasMessage(parsed.messageId)) {
      debugPrint('BLE mesh: duplicate ignored ${parsed.messageId}');
      await _rememberSeenMessage(parsed.messageId);
      return;
    }

    if (parsed.hopCount >= parsed.maxHops) {
      debugPrint('BLE mesh: max hops reached ${parsed.messageId}');
      await _rememberSeenMessage(parsed.messageId);
      return;
    }

    final message = EmergencyMessage(
      id: parsed.messageId,
      originDeviceId: parsed.originDeviceId,
      type: parsed.type,
      text: parsed.isProfileInfoMessage
          ? _profileInfoText(parsed.profileRoleCode ?? 'CIT', parsed.profileFlags ?? '-', parsed.areaName)
          : parsed.text ?? _incomingText(parsed.type),
      createdAt: parsed.createdAt,
      senderAlias: 'BLE uzel',
      approximateArea: parsed.areaName,
      priority: _priorityForType(parsed.type),
      ttlMinutes: _ttlForType(parsed.type),
      hopCount: parsed.hopCount,
      maxHops: parsed.maxHops,
      verifiedCount: 0,
      isOutgoing: false,
      isOutdated: false,
      isCustomTextMessage: parsed.isCustomTextMessage,
      isProfileInfoMessage: parsed.isProfileInfoMessage,
      profileRoleCode: parsed.profileRoleCode,
      profileFlags: parsed.profileFlags,
    );

    if (message.isExpired) {
      debugPrint('BLE mesh: message expired ${parsed.messageId}');
      await _rememberSeenMessage(parsed.messageId);
      return;
    }

    final added = await _messageService.addIncomingMessageIfNew(message);
    await _rememberSeenMessage(parsed.messageId);
    if (added) {
      debugPrint('BLE mesh: message accepted ${parsed.messageId}');
      _receivedCount += 1;
      await _meshSettingsService.load();
      if (_meshSettingsService.notificationsEnabled) {
        await _meshNotificationService.showIncomingMessage(message);
      }
      notifyListeners();
    } else {
      debugPrint('BLE mesh: duplicate ignored ${parsed.messageId}');
    }
  }

  String? _payloadFromAdvertisement(AdvertisementData advertisementData) {
    final direct = advertisementData.manufacturerData[_manufacturerId];
    if (direct != null) {
      return _decodePayload(direct);
    }

    for (final data in advertisementData.manufacturerData.values) {
      final payload = _decodePayload(data);
      if (payload != null) {
        return payload;
      }
    }
    return null;
  }

  String? _decodePayload(List<int> data) {
    try {
      final payload = utf8.decode(data, allowMalformed: false);
      return payload.startsWith('BP|') ? payload : null;
    } catch (_) {
      return null;
    }
  }

  String _encodeMessage(EmergencyMessage message) {
    if (message.isProfileInfoMessage) {
      final area = _areaCode(message.approximateArea);
      final role = _compactToken(message.profileRoleCode ?? 'CIT', fallback: 'CIT');
      final flags = _profileFlagsToken(message.profileFlags ?? '-');
      final time = _timeCode(message.createdAt);
      final origin = _compactToken(message.originDeviceId, fallback: 'DX');
      final messageId = _compactToken(message.id, fallback: 'MSG');
      final hop = message.hopCount.clamp(0, message.maxHops);
      final max = message.maxHops.clamp(1, 9);
      return 'BP|PROF|$area|$role|$flags|$time|$origin|$messageId|$hop|$max';
    }

    final type = message.isCustomTextMessage ? 'TXT' : _protocolType(message.type);
    final area = _areaCode(message.approximateArea);
    final time = _timeCode(message.createdAt);
    final origin = _compactToken(message.originDeviceId, fallback: 'DX');
    final messageId = _compactToken(message.id, fallback: 'MSG');
    final hop = message.hopCount.clamp(0, message.maxHops);
    final max = message.maxHops.clamp(1, 9);
    if (message.isCustomTextMessage) {
      final customText = _payloadText(message.text);
      return 'BP|$type|$area|$time|$origin|$messageId|$hop|$max|$customText';
    }
    return 'BP|$type|$area|$time|$origin|$messageId|$hop|$max';
  }

  String _payloadText(String value) {
    final clean = value.replaceAll('|', '/').replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = clean.runes.toList(growable: false);
    if (runes.length <= 40) {
      return clean;
    }
    return String.fromCharCodes(runes.take(40));
  }

  String _profileFlagsToken(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp('[^MCSP-]'), '');
    if (compact.isEmpty) {
      return '-';
    }
    return compact.length <= 4 ? compact : compact.substring(0, 4);
  }

  String _compactToken(String value, {required String fallback}) {
    final compact = value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (compact.isEmpty) {
      return fallback;
    }
    return compact.length <= 10 ? compact : compact.substring(0, 10);
  }

  String _protocolType(EmergencyMessageType type) {
    return switch (type) {
      EmergencyMessageType.ok => 'OK',
      EmergencyMessageType.sos => 'SOS',
      EmergencyMessageType.medical => 'MED',
      EmergencyMessageType.water => 'WATER',
      EmergencyMessageType.medication => 'MEDS',
      EmergencyMessageType.danger => 'DANGER',
      EmergencyMessageType.info => 'INFO',
    };
  }

  String _areaCode(String areaName) {
    final match = RegExp(r'Praha\s*(\d+)', caseSensitive: false).firstMatch(areaName);
    if (match == null) {
      return 'PX';
    }
    return 'P${match.group(1)}';
  }

  String _timeCode(DateTime createdAt) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour$minute';
  }

  String _incomingText(EmergencyMessageType type) {
    return switch (type) {
      EmergencyMessageType.ok => 'Jsem v pořádku.',
      EmergencyMessageType.sos => 'SOS: osoba potřebuje okamžitou pomoc.',
      EmergencyMessageType.medical => 'Osoba potřebuje zdravotní pomoc.',
      EmergencyMessageType.water => 'Osoba potřebuje vodu.',
      EmergencyMessageType.medication => 'Osoba potřebuje léky.',
      EmergencyMessageType.danger => 'Hlášeno nebezpečí v okolí.',
      EmergencyMessageType.info => 'Krizová informace z BLE mesh.',
    };
  }

  String _profileInfoText(String roleCode, String flags, String areaName) {
    final role = switch (roleCode.toUpperCase()) {
      'VOL' => 'Dobrovolník',
      'MED' => 'Zdravotník',
      'FIR' => 'Hasič',
      'POL' => 'Policista',
      'TEC' => 'Technik',
      _ => 'Obyvatel',
    };
    final normalizedFlags = flags.toUpperCase();
    final needs = <String>[
      if (normalizedFlags.contains('M')) 'léky',
      if (normalizedFlags.contains('C')) 'děti',
      if (normalizedFlags.contains('S')) 'senior',
      if (normalizedFlags.contains('P')) 'mazlíček',
    ];
    final needsText = needs.isEmpty ? 'bez zvláštních příznaků' : needs.join(', ');
    return 'Profilová informace: $role, $areaName, $needsText.';
  }

  EmergencyMessagePriority _priorityForType(EmergencyMessageType type) {
    return switch (type) {
      EmergencyMessageType.ok => EmergencyMessagePriority.low,
      EmergencyMessageType.sos => EmergencyMessagePriority.critical,
      EmergencyMessageType.medical => EmergencyMessagePriority.high,
      EmergencyMessageType.water => EmergencyMessagePriority.medium,
      EmergencyMessageType.medication => EmergencyMessagePriority.high,
      EmergencyMessageType.danger => EmergencyMessagePriority.high,
      EmergencyMessageType.info => EmergencyMessagePriority.medium,
    };
  }

  int _ttlForType(EmergencyMessageType type) {
    return switch (type) {
      EmergencyMessageType.ok => 240,
      EmergencyMessageType.sos => 60,
      EmergencyMessageType.medical => 120,
      EmergencyMessageType.water => 180,
      EmergencyMessageType.medication => 120,
      EmergencyMessageType.danger => 90,
      EmergencyMessageType.info => 120,
    };
  }

  Future<void> _loadSeenMessages() async {
    if (_seenMessagesLoaded) {
      await _pruneSeenMessages();
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final rawSeenMessages = preferences.getString(_seenMessagesKey);
    _seenMessageIds.clear();

    if (rawSeenMessages != null && rawSeenMessages.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSeenMessages) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final seenAt = DateTime.tryParse(entry.value as String? ?? '');
          if (seenAt != null) {
            _seenMessageIds[entry.key] = seenAt;
          }
        }
      } on FormatException {
        _seenMessageIds.clear();
      } on TypeError {
        _seenMessageIds.clear();
      }
    }

    _seenMessagesLoaded = true;
    await _pruneSeenMessages();
  }

  bool _hasSeenMessage(String messageId) {
    return _seenMessageIds.containsKey(messageId);
  }

  Future<void> _rememberSeenMessage(String messageId) async {
    _seenMessageIds[messageId] = DateTime.now();
    await _saveSeenMessages();
  }

  Future<void> _pruneSeenMessages() async {
    final threshold = DateTime.now().subtract(_seenRetention);
    final beforeCount = _seenMessageIds.length;
    _seenMessageIds.removeWhere((_, seenAt) => seenAt.isBefore(threshold));
    if (_seenMessageIds.length != beforeCount) {
      await _saveSeenMessages();
    }
  }

  Future<void> _saveSeenMessages() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _seenMessagesKey,
      jsonEncode(_seenMessageIds.map((messageId, seenAt) => MapEntry(messageId, seenAt.toIso8601String()))),
    );
  }
}

class _ParsedBleMessage {
  const _ParsedBleMessage({
    required this.type,
    required this.areaName,
    required this.createdAt,
    required this.originDeviceId,
    required this.messageId,
    required this.hopCount,
    required this.maxHops,
    required this.isCustomTextMessage,
    required this.isProfileInfoMessage,
    this.text,
    this.profileRoleCode,
    this.profileFlags,
  });

  final EmergencyMessageType type;
  final String areaName;
  final DateTime createdAt;
  final String originDeviceId;
  final String messageId;
  final int hopCount;
  final int maxHops;
  final bool isCustomTextMessage;
  final bool isProfileInfoMessage;
  final String? text;
  final String? profileRoleCode;
  final String? profileFlags;

  static _ParsedBleMessage? tryParse(String payload) {
    final parts = payload.split('|');
    if (parts.firstOrNull != 'BP') {
      return null;
    }

    if (parts.length == 10 && parts[1] == 'PROF') {
      return _parseProfile(parts);
    }

    if (parts.length == 8 || parts.length == 9) {
      return _parseCurrent(parts);
    }

    if (parts.length == 6) {
      return _parseLegacy(parts);
    }

    return null;
  }

  static _ParsedBleMessage? _parseCurrent(List<String> parts) {
    final isTextMessage = parts[1] == 'TXT';
    final type = _typeFromProtocol(parts[1]);
    final createdAt = _createdAtFromTimeCode(parts[3]);
    final hopCount = int.tryParse(parts[6]);
    final maxHops = int.tryParse(parts[7]);
    if (type == null || createdAt == null || parts[4].isEmpty || parts[5].isEmpty || hopCount == null || maxHops == null) {
      return null;
    }

    return _ParsedBleMessage(
      type: type,
      areaName: _areaNameFromCode(parts[2]),
      createdAt: createdAt,
      originDeviceId: parts[4].toUpperCase(),
      messageId: parts[5].toUpperCase(),
      hopCount: hopCount,
      maxHops: maxHops,
      isCustomTextMessage: isTextMessage,
      isProfileInfoMessage: false,
      text: isTextMessage && parts.length == 9 ? parts[8] : null,
    );
  }

  static _ParsedBleMessage? _parseProfile(List<String> parts) {
    final createdAt = _createdAtFromTimeCode(parts[5]);
    final hopCount = int.tryParse(parts[8]);
    final maxHops = int.tryParse(parts[9]);
    if (createdAt == null || parts[6].isEmpty || parts[7].isEmpty || hopCount == null || maxHops == null) {
      return null;
    }

    return _ParsedBleMessage(
      type: EmergencyMessageType.info,
      areaName: _areaNameFromCode(parts[2]),
      createdAt: createdAt,
      originDeviceId: parts[6].toUpperCase(),
      messageId: parts[7].toUpperCase(),
      hopCount: hopCount,
      maxHops: maxHops,
      isCustomTextMessage: false,
      isProfileInfoMessage: true,
      profileRoleCode: parts[3].toUpperCase(),
      profileFlags: parts[4].toUpperCase(),
    );
  }

  static _ParsedBleMessage? _parseLegacy(List<String> parts) {
    final type = _typeFromProtocol(parts[1]);
    final createdAt = _createdAtFromTimeCode(parts[3]);
    final hopCount = int.tryParse(parts[5]);
    if (type == null || createdAt == null || parts[4].isEmpty || hopCount == null) {
      return null;
    }

    return _ParsedBleMessage(
      type: type,
      areaName: _areaNameFromCode(parts[2]),
      createdAt: createdAt,
      originDeviceId: 'UNKNOWN',
      messageId: parts[4].toUpperCase(),
      hopCount: hopCount,
      maxHops: 5,
      isCustomTextMessage: false,
      isProfileInfoMessage: false,
    );
  }

  static EmergencyMessageType? _typeFromProtocol(String value) {
    return switch (value) {
      'OK' => EmergencyMessageType.ok,
      'SOS' => EmergencyMessageType.sos,
      'MED' => EmergencyMessageType.medical,
      'WATER' => EmergencyMessageType.water,
      'MEDS' => EmergencyMessageType.medication,
      'DANGER' => EmergencyMessageType.danger,
      'INFO' => EmergencyMessageType.info,
      'TXT' => EmergencyMessageType.info,
      _ => null,
    };
  }

  static String _areaNameFromCode(String value) {
    final match = RegExp(r'P(\d+)', caseSensitive: false).firstMatch(value);
    if (match == null) {
      return 'Praha';
    }
    return 'Praha ${match.group(1)}';
  }

  static DateTime? _createdAtFromTimeCode(String value) {
    if (value.length != 4) {
      return null;
    }

    final hour = int.tryParse(value.substring(0, 2));
    final minute = int.tryParse(value.substring(2, 4));
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }

    final now = DateTime.now();
    var createdAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (createdAt.isAfter(now.add(const Duration(minutes: 5)))) {
      createdAt = createdAt.subtract(const Duration(days: 1));
    }
    return createdAt;
  }
}


