import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_mode.dart';

class MapModeService {
  static const _mapModeKey = 'blackout_prague_map_mode';

  Future<MapMode> loadMode() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_mapModeKey);
    return MapMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => MapMode.onlineTiles,
    );
  }

  Future<void> saveMode(MapMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_mapModeKey, mode.name);
  }
}