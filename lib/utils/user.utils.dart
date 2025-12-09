import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.model.dart';

class UserUtils {
  Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isEmpty) {
        return '';
      }
      return packageInfo.version;
    } catch (e) {
      debugPrint('❌ Error loading app version');
      return '';
    }
  }

  // save user details to shared preferences
  Future<void> saveUserDetails(UserModel userDetails) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'current_user_details',
      jsonEncode(userDetails.toJson()),
    );
  }

  // get user details from shared preferences
  Future<UserModel?> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    String? userJson = prefs.getString('current_user_details');

    if (userJson == null) return null;

    // Decode JSON string back to UserModel
    return UserModel.fromJson(jsonDecode(userJson));
  }

  // update the user details in shared preferences
  Future<void> updateUserDetails(UserModel userDetails) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the existing user data
    String? userJson = prefs.getString('current_user_details');

    if (userJson == null) return; // No user data saved yet

    // Decode existing map
    UserModel existingUser = UserModel.fromJson(jsonDecode(userJson));

    // Update the specific field
    final updatedUser = existingUser.copyWith(
      name: userDetails.name,
      profilePic: userDetails.profilePic,
    );

    // Save updated map back to SharedPreferences
    await prefs.setString(
      'current_user_details',
      jsonEncode(updatedUser.toJson()),
    );
  }

  // clear user details from shared preferences
  Future<void> clearUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_details');
  }
}
