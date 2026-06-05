import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/prague_areas.dart';
import '../models/emergency_message.dart';
import 'selected_area_service.dart';

class MessageService extends ChangeNotifier {
  MessageService._();

  static final MessageService instance = MessageService._();
  static const _messagesKey = 'blackout_prague_emergency_messages';

  final _selectedAreaService = SelectedAreaService();
  final List<EmergencyMessage> _messages = [];
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
    int ttlMinutes = 180,
  }) async {
    await loadMessages();
    final areaName = await _currentAreaName();
    final message = EmergencyMessage(
      id: _createId('out'),
      type: type,
      text: text,
      createdAt: DateTime.now(),
      senderAlias: 'Já',
      approximateArea: areaName,
      priority: priority,
      ttlMinutes: ttlMinutes,
      hopCount: 0,
      verifiedCount: 0,
      isOutgoing: true,
      isOutdated: false,
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
  }) async {
    await loadMessages();
    final message = EmergencyMessage(
      id: _createId('in'),
      type: type,
      text: text,
      createdAt: DateTime.now(),
      senderAlias: senderAlias,
      approximateArea: approximateArea,
      priority: priority,
      ttlMinutes: ttlMinutes,
      hopCount: hopCount,
      verifiedCount: verifiedCount,
      isOutgoing: false,
      isOutdated: false,
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
        type: EmergencyMessageType.water,
        text: 'Demo: Výdej vody hlášen u školy.',
        createdAt: now.subtract(const Duration(minutes: 8)),
        senderAlias: 'Demo uzel 104',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.medium,
        ttlMinutes: 180,
        hopCount: 2,
        verifiedCount: 1,
        isOutgoing: false,
        isOutdated: false,
      ),
      EmergencyMessage(
        id: 'demo_charge_${now.microsecondsSinceEpoch}',
        type: EmergencyMessageType.info,
        text: 'Demo: Dobíjecí místo dostupné u komunitního centra.',
        createdAt: now.subtract(const Duration(minutes: 15)),
        senderAlias: 'Demo uzel 221',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.medium,
        ttlMinutes: 180,
        hopCount: 1,
        verifiedCount: 2,
        isOutgoing: false,
        isOutdated: false,
      ),
      EmergencyMessage(
        id: 'demo_crossing_${now.microsecondsSinceEpoch}',
        type: EmergencyMessageType.danger,
        text: 'Demo: Nefunkční křižovatka.',
        createdAt: now.subtract(const Duration(minutes: 22)),
        senderAlias: 'Demo uzel 317',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.high,
        ttlMinutes: 120,
        hopCount: 3,
        verifiedCount: 1,
        isOutgoing: false,
        isOutdated: false,
      ),
      EmergencyMessage(
        id: 'demo_meds_${now.microsecondsSinceEpoch}',
        type: EmergencyMessageType.medication,
        text: 'Demo: Osoba potřebuje léky.',
        createdAt: now.subtract(const Duration(minutes: 30)),
        senderAlias: 'Demo uzel 508',
        approximateArea: 'Praha 10',
        priority: EmergencyMessagePriority.high,
        ttlMinutes: 120,
        hopCount: 2,
        verifiedCount: 0,
        isOutgoing: false,
        isOutdated: false,
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

  Future<void> confirmMessage(String messageId) async {
    await _updateMessage(messageId, (message) => message.copyWith(verifiedCount: message.verifiedCount + 1));
  }

  Future<void> relayMessage(String messageId) async {
    await _updateMessage(messageId, (message) => message.copyWith(hopCount: message.hopCount + 1));
  }

  Future<void> markMessageOutdated(String messageId) async {
    await _updateMessage(messageId, (message) => message.copyWith(isOutdated: true));
  }

  Future<void> _addMessage(EmergencyMessage message) async {
    _messages.insert(0, message);
    await _saveMessages();
    notifyListeners();
  }

  Future<void> _updateMessage(String messageId, EmergencyMessage Function(EmergencyMessage message) update) async {
    await loadMessages();
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      return;
    }

    _messages[index] = update(_messages[index]);
    await _saveMessages();
    notifyListeners();
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
}