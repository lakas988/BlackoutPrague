import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/prague_areas.dart';
import '../models/emergency_message.dart';
import 'device_id_service.dart';
import 'selected_area_service.dart';

class MessageService extends ChangeNotifier {
  MessageService._();

  static final MessageService instance = MessageService._();
  static const _messagesKey = 'blackout_prague_emergency_messages';
  static const _defaultMaxHops = 5;

  final _selectedAreaService = SelectedAreaService();
  final _deviceIdService = DeviceIdService.instance;
  final List<EmergencyMessage> _messages = [];
  final math.Random _random = math.Random.secure();
  bool _isLoaded = false;

  List<EmergencyMessage> get messages => List.unmodifiable(_sortedMessages());
  List<EmergencyMessage> get outgoingMessages => messages.where((message) => message.isOutgoing).toList(growable: false);
  List<EmergencyMessage> get incomingMessages => messages.where((message) => !message.isOutgoing).toList(growable: false);

  Future<void> loadMessages() async {
    if (_isLoaded) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final rawMessages = preferences.getString(_messagesKey);
    _messages.clear();

    if (rawMessages != null && rawMessages.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMessages) as List<dynamic>;
        _messages.addAll(decoded.whereType<Map<String, dynamic>>().map(EmergencyMessage.fromJson));
      } on FormatException {
        _messages.clear();
      } on TypeError {
        _messages.clear();
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<EmergencyMessage> createOutgoingMessage({
    required EmergencyMessageType type,
    required String text,
    required EmergencyMessagePriority priority,
    int ttlMinutes = 60,
    bool isCustomTextMessage = false,
  }) async {
    await loadMessages();
    final areaName = await _currentAreaName();
    final deviceId = await _deviceIdService.getDeviceId();
    final message = EmergencyMessage(
      id: _createMeshMessageId(),
      originDeviceId: deviceId,
      type: type,
      text: text,
      createdAt: DateTime.now(),
      senderAlias: 'Já',
      approximateArea: areaName,
      priority: priority,
      ttlMinutes: ttlMinutes,
      hopCount: 0,
      maxHops: _defaultMaxHops,
      verifiedCount: 0,
      isOutgoing: true,
      isOutdated: false,
      isCustomTextMessage: isCustomTextMessage,
    );
    await _addMessage(message);
    return message;
  }

  Future<EmergencyMessage> addIncomingSample({
    required EmergencyMessageType type,
    required String text,
    required EmergencyMessagePriority priority,
    required String senderAlias,
    required String approximateArea,
    int ttlMinutes = 120,
    int hopCount = 1,
    int verifiedCount = 0,
    bool isDemo = false,
  }) async {
    await loadMessages();
    final message = EmergencyMessage(
      id: _createId(isDemo ? 'demo' : 'in'),
      originDeviceId: isDemo ? 'DEMO' : 'UNKNOWN',
      type: type,
      text: text,
      createdAt: DateTime.now(),
      senderAlias: senderAlias,
      approximateArea: approximateArea,
      priority: priority,
      ttlMinutes: ttlMinutes,
      hopCount: hopCount,
      maxHops: _defaultMaxHops,
      verifiedCount: verifiedCount,
      isOutgoing: false,
      isOutdated: false,
      isCustomTextMessage: false,
    );
    await _addMessage(message);
    return message;
  }

  Future<void> addDemoMessagesIfNeeded() async {
    await loadMessages();
    if (_messages.any((message) => message.isDemo)) {
      return;
    }

    final now = DateTime.now();
    final demoMessages = [
      EmergencyMessage(
        id: 'demo_water_${now.microsecondsSinceEpoch}',
        originDeviceId: 'DEMO',
        type: EmergencyMessageType.water,
        text: 'Demo: Výdej vody hlášen u školy.',
        createdAt: now.subtract(const Duration(minutes: 8)),
        senderAlias: 'Demo uzel 104',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.medium,
        ttlMinutes: 180,
        hopCount: 2,
        maxHops: _defaultMaxHops,
        verifiedCount: 1,
        isOutgoing: false,
        isOutdated: false,
        isCustomTextMessage: false,
      ),
      EmergencyMessage(
        id: 'demo_charge_${now.microsecondsSinceEpoch}',
        originDeviceId: 'DEMO',
        type: EmergencyMessageType.info,
        text: 'Demo: Dobíjecí místo dostupné u komunitního centra.',
        createdAt: now.subtract(const Duration(minutes: 15)),
        senderAlias: 'Demo uzel 221',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.medium,
        ttlMinutes: 180,
        hopCount: 1,
        maxHops: _defaultMaxHops,
        verifiedCount: 2,
        isOutgoing: false,
        isOutdated: false,
        isCustomTextMessage: false,
      ),
      EmergencyMessage(
        id: 'demo_crossing_${now.microsecondsSinceEpoch}',
        originDeviceId: 'DEMO',
        type: EmergencyMessageType.danger,
        text: 'Demo: Nefunkční křižovatka.',
        createdAt: now.subtract(const Duration(minutes: 22)),
        senderAlias: 'Demo uzel 317',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.high,
        ttlMinutes: 120,
        hopCount: 3,
        maxHops: _defaultMaxHops,
        verifiedCount: 1,
        isOutgoing: false,
        isOutdated: false,
        isCustomTextMessage: false,
      ),
      EmergencyMessage(
        id: 'demo_meds_${now.microsecondsSinceEpoch}',
        originDeviceId: 'DEMO',
        type: EmergencyMessageType.medication,
        text: 'Demo: Osoba potřebuje léky.',
        createdAt: now.subtract(const Duration(minutes: 30)),
        senderAlias: 'Demo uzel 508',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.high,
        ttlMinutes: 120,
        hopCount: 2,
        maxHops: _defaultMaxHops,
        verifiedCount: 0,
        isOutgoing: false,
        isOutdated: false,
        isCustomTextMessage: false,
      ),
    ];

    _messages.insertAll(0, demoMessages);
    await _saveMessages();
    notifyListeners();
  }

  Future<void> clearDemoMessages() async {
    await loadMessages();
    _messages.removeWhere((message) => message.isDemo);
    await _saveMessages();
    notifyListeners();
  }

  Future<bool> hasMessage(String messageId) async {
    await loadMessages();
    return _messages.any((message) => message.id == messageId);
  }

  Future<bool> addIncomingMessageIfNew(EmergencyMessage message) async {
    await loadMessages();
    if (_messages.any((storedMessage) => storedMessage.id == message.id)) {
      return false;
    }

    await _addMessage(message);
    return true;
  }

  Future<void> confirmMessage(String messageId) async {
    await _updateMessage(messageId, (message) => message.copyWith(verifiedCount: message.verifiedCount + 1));
  }

  Future<void> relayMessage(String messageId) async {
    await relayMessageAndReturn(messageId);
  }

  Future<EmergencyMessage?> relayMessageAndReturn(String messageId) async {
    return _updateMessageAndReturn(messageId, (message) {
      if (message.isExpired || message.hopCount >= message.maxHops) {
        return message;
      }
      return message.copyWith(hopCount: message.hopCount + 1);
    });
  }

  Future<void> markMessageOutdated(String messageId) async {
    await _updateMessage(messageId, (message) => message.copyWith(isOutdated: true));
  }

  Future<void> deleteMessage(String messageId) async {
    await loadMessages();
    _messages.removeWhere((message) => message.id == messageId);
    await _saveMessages();
    notifyListeners();
  }

  Future<void> deleteMessagesById(Set<String> messageIds) async {
    await loadMessages();
    if (messageIds.isEmpty) {
      return;
    }

    _messages.removeWhere((message) => messageIds.contains(message.id));
    await _saveMessages();
    notifyListeners();
  }

  Future<void> _addMessage(EmergencyMessage message) async {
    _messages.insert(0, message);
    await _saveMessages();
    notifyListeners();
  }

  Future<void> _updateMessage(String messageId, EmergencyMessage Function(EmergencyMessage message) update) async {
    await _updateMessageAndReturn(messageId, update);
  }

  Future<EmergencyMessage?> _updateMessageAndReturn(
    String messageId,
    EmergencyMessage Function(EmergencyMessage message) update,
  ) async {
    await loadMessages();
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      return null;
    }

    final updatedMessage = update(_messages[index]);
    _messages[index] = updatedMessage;
    await _saveMessages();
    notifyListeners();
    return updatedMessage;
  }

  Future<void> _saveMessages() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _messagesKey,
      jsonEncode(_messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<String> _currentAreaName() async {
    final areaId = await _selectedAreaService.loadSelectedAreaId();
    return getPragueAreaById(areaId).name;
  }

  List<EmergencyMessage> _sortedMessages() {
    final sorted = [..._messages];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  String _createId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_messages.length}';
  }

  String _createMeshMessageId() {
    final nowPart = DateTime.now().microsecondsSinceEpoch & 0xFFFFFF;
    final randomPart = _random.nextInt(0xFFFFFF);
    return (nowPart ^ randomPart).toRadixString(16).toUpperCase().padLeft(6, '0').substring(0, 6);
  }
}
