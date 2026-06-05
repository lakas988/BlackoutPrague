import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/emergency_message.dart';
import 'message_service.dart';

class RealBleMeshService extends ChangeNotifier {
  RealBleMeshService._();

  static final RealBleMeshService instance = RealBleMeshService._();
  static const int _manufacturerId = 0x4247;
  static const Duration _advertisingWindow = Duration(seconds: 30);

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final MessageService _messageService = MessageService.instance;
  final Set<String> _seenProtocolIds = <String>{};

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _advertisingTimer;

  bool _isEnabled = false;
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isAdvertisingSupported = true;
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
    } catch (error) {
      _permissionStatus = 'Nelze ověřit';
      _lastError = 'Bluetooth oprávnění se nepodařilo ověřit.';
      notifyListeners();
      return false;
    }
  }

  Future<void> startRealBle() async {
    _isEnabled = true;
    notifyListeners();

    final granted = await requestBluetoothPermissions();
    if (!granted) {
      await stopScan();
      return;
    }

    await startScan();
  }

  Future<void> stopRealBle() async {
    _isEnabled = false;
    await stopScan();
    await stopAdvertising();
    notifyListeners();
  }

  Future<void> startScan() async {
    if (!_isEnabled || _isScanning) {
      return;
    }

    try {
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
    } catch (error) {
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

    final granted = await requestBluetoothPermissions();
    if (!granted) {
      return false;
    }

    try {
      final supported = await _peripheral.isSupported;
      _isAdvertisingSupported = supported;
      if (!supported) {
        _lastError = 'Toto zařízení nepodporuje BLE vysílání.';
        notifyListeners();
        return false;
      }

      final protocolId = _protocolIdForMessage(message);
      _seenProtocolIds.add(protocolId);
      final payload = _encodeMessage(message, protocolId: protocolId);
      await stopAdvertising();
      await _peripheral.start(
        advertiseData: AdvertiseData(
          manufacturerId: _manufacturerId,
          manufacturerData: Uint8List.fromList(ascii.encode(payload)),
          includeDeviceName: false,
        ),
      );

      _isAdvertising = true;
      _lastError = null;
      _advertisingTimer?.cancel();
      _advertisingTimer = Timer(_advertisingWindow, stopAdvertising);
      notifyListeners();
      return true;
    } catch (error) {
      _isAdvertising = false;
      _lastError = 'Toto zařízení nepodporuje BLE vysílání.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> relayMessage(EmergencyMessage message) async {
    final relayedMessage = message.copyWith(hopCount: message.hopCount + 1);
    return broadcastMessage(relayedMessage);
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
    if (parsed == null || _seenProtocolIds.contains(parsed.id)) {
      return;
    }

    final messageId = 'ble_${parsed.id}';
    final alreadyStored = await _messageService.hasMessage(messageId);
    if (alreadyStored) {
      _seenProtocolIds.add(parsed.id);
      return;
    }

    final message = EmergencyMessage(
      id: messageId,
      type: parsed.type,
      text: _incomingText(parsed.type),
      createdAt: DateTime.now(),
      senderAlias: 'BLE uzel',
      approximateArea: parsed.areaName,
      priority: _priorityForType(parsed.type),
      ttlMinutes: _ttlForType(parsed.type),
      hopCount: parsed.hopCount,
      verifiedCount: 0,
      isOutgoing: false,
      isOutdated: false,
    );

    final added = await _messageService.addIncomingMessageIfNew(message);
    if (added) {
      _seenProtocolIds.add(parsed.id);
      _receivedCount += 1;
      notifyListeners();
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
      final payload = ascii.decode(data, allowInvalid: false);
      return payload.startsWith('BP|') ? payload : null;
    } catch (_) {
      return null;
    }
  }

  String _encodeMessage(EmergencyMessage message, {required String protocolId}) {
    final type = _protocolType(message.type);
    final area = _areaCode(message.approximateArea);
    final time = _timeCode(message.createdAt);
    final hop = message.hopCount.clamp(0, 9);
    return 'BP|$type|$area|$time|$protocolId|$hop';
  }

  String _protocolIdForMessage(EmergencyMessage message) {
    if (message.id.startsWith('ble_')) {
      return message.id.substring(4).toUpperCase();
    }

    var hash = 0;
    for (final unit in message.id.codeUnits) {
      hash = ((hash * 31) + unit) & 0xFFFFFF;
    }
    final randomSalt = math.Random(message.createdAt.microsecondsSinceEpoch).nextInt(0xFFFFFF);
    final mixed = (hash ^ randomSalt) & 0xFFFFFF;
    return mixed.toRadixString(16).toUpperCase().padLeft(6, '0').substring(0, 6);
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
}

class _ParsedBleMessage {
  const _ParsedBleMessage({
    required this.type,
    required this.areaName,
    required this.id,
    required this.hopCount,
  });

  final EmergencyMessageType type;
  final String areaName;
  final String id;
  final int hopCount;

  static _ParsedBleMessage? tryParse(String payload) {
    final parts = payload.split('|');
    if (parts.length != 6 || parts[0] != 'BP') {
      return null;
    }

    final type = _typeFromProtocol(parts[1]);
    if (type == null || parts[4].isEmpty) {
      return null;
    }

    return _ParsedBleMessage(
      type: type,
      areaName: _areaNameFromCode(parts[2]),
      id: parts[4].toUpperCase(),
      hopCount: int.tryParse(parts[5]) ?? 0,
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
}
