import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class ProfileStorageService {
  static const _profileKey = 'blackout_prague_user_profile';
  static const _onboardingCompletedKey = 'blackout_prague_onboarding_completed';

  Future<UserProfile?> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final rawProfile = preferences.getString(_profileKey);

    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawProfile) as Map<String, dynamic>;
      return UserProfile.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<bool> isOnboardingCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    await preferences.setBool(_onboardingCompletedKey, true);
  }
}