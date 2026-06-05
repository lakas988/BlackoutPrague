import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoModeService extends ChangeNotifier {
  DemoModeService._();

  static final DemoModeService instance = DemoModeService._();
  static const _demoModeKey = 'blackout_prague_demo_mode_enabled';

  bool _isLoaded = false;
  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    _isEnabled = preferences.getBool(_demoModeKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    await load();
    if (_isEnabled == enabled) {
      return;
    }

    _isEnabled = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_demoModeKey, enabled);
    notifyListeners();
  }
}