import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_power_mode.dart';

class PowerModeService {
  static const _powerModeKey = 'blackout_prague_power_mode';

  Future<AppPowerMode> loadMode() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_powerModeKey, AppPowerMode.normal.storageValue);
    return AppPowerMode.normal;
  }

  Future<void> saveMode(AppPowerMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_powerModeKey, AppPowerMode.normal.storageValue);
  }
}
