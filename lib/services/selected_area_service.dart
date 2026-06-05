import 'package:shared_preferences/shared_preferences.dart';

class SelectedAreaService {
  static const _selectedAreaKey = 'blackout_prague_selected_area';

  Future<String?> loadSelectedAreaId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedAreaKey);
  }

  Future<void> saveSelectedAreaId(String areaId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedAreaKey, areaId);
  }
}