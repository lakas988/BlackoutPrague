import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  DeviceIdService._();

  static final DeviceIdService instance = DeviceIdService._();
  static const _deviceIdKey = 'blackout_prague_device_id';
  static const _alphabet = '0123456789ABCDEF';

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedDeviceId = preferences.getString(_deviceIdKey);
    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      _cachedDeviceId = storedDeviceId;
      return storedDeviceId;
    }

    final generatedDeviceId = _generateDeviceId();
    await preferences.setString(_deviceIdKey, generatedDeviceId);
    _cachedDeviceId = generatedDeviceId;
    return generatedDeviceId;
  }

  String _generateDeviceId() {
    final random = math.Random.secure();
    final suffix = List.generate(5, (_) => _alphabet[random.nextInt(_alphabet.length)]).join();
    return 'D$suffix';
  }
}


