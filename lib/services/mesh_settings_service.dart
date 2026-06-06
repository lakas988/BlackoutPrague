import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeshSettingsService extends ChangeNotifier {
  MeshSettingsService._();

  static final MeshSettingsService instance = MeshSettingsService._();

  static const _autoStartKey = 'blackout_prague_mesh_auto_start';
  static const _backgroundKey = 'blackout_prague_mesh_background';
  static const _notificationsKey = 'blackout_prague_mesh_notifications';

  bool _isLoaded = false;
  bool _autoStartBleMesh = false;
  bool _backgroundMeshEnabled = false;
  bool _notificationsEnabled = false;

  bool get autoStartBleMesh => _autoStartBleMesh;
  bool get backgroundMeshEnabled => _backgroundMeshEnabled;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    _autoStartBleMesh = preferences.getBool(_autoStartKey) ?? false;
    _backgroundMeshEnabled = preferences.getBool(_backgroundKey) ?? false;
    _notificationsEnabled = preferences.getBool(_notificationsKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setAutoStartBleMesh(bool value) async {
    await load();
    _autoStartBleMesh = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoStartKey, value);
    notifyListeners();
  }

  Future<void> setBackgroundMeshEnabled(bool value) async {
    await load();
    _backgroundMeshEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_backgroundKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await load();
    _notificationsEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, value);
    notifyListeners();
  }
}
