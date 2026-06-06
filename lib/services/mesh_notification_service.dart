import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/emergency_message.dart';

class MeshNotificationService {
  MeshNotificationService._();

  static final MeshNotificationService instance = MeshNotificationService._();

  static const _channelId = 'blackout_prague_mesh';
  static const _channelName = 'Krizové mesh zprávy';
  static const _channelDescription =
      'Oznámení o přijatých krizových mesh zprávách.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _plugin.initialize(settings: settings);
    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? true;
  }

  Future<void> showIncomingMessage(EmergencyMessage message) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Nová krizová zpráva',
      body: _notificationBody(message),
      notificationDetails: details,
      payload: 'mesh',
    );
  }

  String _notificationBody(EmergencyMessage message) {
    if (message.isCustomTextMessage) {
      return _shortText(message.text);
    }

    return switch (message.type) {
      EmergencyMessageType.sos =>
        'SOS zpráva v oblasti ${message.approximateArea}',
      EmergencyMessageType.water =>
        'Žádost o vodu v oblasti ${message.approximateArea}',
      EmergencyMessageType.medical || EmergencyMessageType.medication =>
        'Zdravotní/léková pomoc v oblasti ${message.approximateArea}',
      EmergencyMessageType.danger =>
        'Hlášené nebezpečí v oblasti ${message.approximateArea}',
      EmergencyMessageType.ok =>
        'Někdo v okolí hlásí, že je v pořádku',
      EmergencyMessageType.info => _shortText(message.text),
    };
  }

  String _shortText(String value) {
    final clean = value.trim();
    final runes = clean.runes.toList(growable: false);
    if (runes.length <= 48) {
      return clean;
    }
    return '${String.fromCharCodes(runes.take(48))}...';
  }
}
