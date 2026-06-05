import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_location.dart';

class LocationService {
  static const _lastKnownLocationKey = 'blackout_prague_last_known_location';

  Future<LocationPermissionResult> requestLocationPermission() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return LocationPermissionResult.servicesDisabled;
    }

    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted || status.isLimited) {
      return LocationPermissionResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return LocationPermissionResult.permanentlyDenied;
    }

    return LocationPermissionResult.denied;
  }

  Future<AppLocation?> getCurrentLocationOnce() async {
    final permission = await requestLocationPermission();
    if (permission != LocationPermissionResult.granted) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveLastKnownLocation(AppLocation location) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastKnownLocationKey, jsonEncode(location.toJson()));
  }

  Future<AppLocation?> getLastKnownLocation() async {
    final preferences = await SharedPreferences.getInstance();
    final rawLocation = preferences.getString(_lastKnownLocationKey);
    if (rawLocation == null || rawLocation.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawLocation) as Map<String, dynamic>;
      return AppLocation.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearLastKnownLocation() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lastKnownLocationKey);
  }

  Future<bool> hasLastKnownLocation() async {
    return getLastKnownLocation().then((location) => location != null);
  }
}