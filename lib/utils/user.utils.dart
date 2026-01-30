import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

  import '../db/repositories/user.repo.dart';
import '../models/call.model.dart';
import '../models/conversations.model.dart';
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

  /// Get display name for a user ID from local database
  /// Returns username (from contacts) if available, otherwise server name
  Future<String?> getDisplayNameForUserId(int userId) async {
    try {
      final userRepo = UserRepository();
      final user = await userRepo.getUserById(userId);
      return user?.displayName;
    } catch (e) {
      debugPrint('❌ Error getting display name for user $userId: $e');
      return null;
    }
  }

  /// Enrich DMs with display names from local users table
  /// This ensures contact names (username) are preserved instead of server names
  Future<List<DmModel>> enrichDmsWithDisplayNames(List<DmModel> dmList) async {
    try {
      final userRepo = UserRepository();
      final enrichedDms = <DmModel>[];

      for (final dm in dmList) {
        // Try to get user from local database
        final user = await userRepo.getUserById(dm.recipientId);

        if (user != null) {
          // Update DM with displayName from local user (includes username if available)
          final enrichedDm = dm.copyWith(
            recipientName: user.displayName,
          );
          enrichedDms.add(enrichedDm);
        } else {
          // User not found in local DB, keep original DM
          enrichedDms.add(dm);
        }
      }

      return enrichedDms;
    } catch (e) {
      debugPrint('❌ Error enriching DMs with display names: $e');
      // Return original list if enrichment fails
      return dmList;
    }
  }

  /// Enrich calls with display names from local users table
  /// This ensures contact names (username) are preserved instead of server names
  Future<List<CallModel>> enrichCallsWithDisplayNames(
    List<CallModel> calls,
    int currentUserId,
  ) async {
    try {
      final userRepo = UserRepository();
      final enrichedCalls = <CallModel>[];

      for (final call in calls) {
        // Determine which user is the contact (caller or callee)
        final isIncoming = call.calleeId == currentUserId;
        final contactUserId = isIncoming ? call.callerId : call.calleeId;

        // Try to get user from local database
        final user = await userRepo.getUserById(contactUserId);

        if (user != null) {
          // Update call with displayName from local user (includes username if available)
          final enrichedCall = call.copyWith(
            contactName: user.displayName,
            contactProfilePic: user.profilePic ?? call.contactProfilePic,
          );
          enrichedCalls.add(enrichedCall);
        } else {
          // User not found in local DB, keep original call
          enrichedCalls.add(call);
        }
      }

      return enrichedCalls;
    } catch (e) {
      debugPrint('❌ Error enriching calls with display names: $e');
      // Return original list if enrichment fails
      return calls;
    }
  }

  /// Enrich deleted chats with display names from local users table
  /// This ensures contact names (username) are preserved instead of server names
  Future<List<dynamic>> enrichDeletedChatsWithDisplayNames(
    List<dynamic> chats,
  ) async {
    try {
      final userRepo = UserRepository();
      final enrichedChats = <Map<String, dynamic>>[];

      for (final chat in chats) {
        if (chat is! Map<String, dynamic>) {
          enrichedChats.add(chat);
          continue;
        }

        final userId = chat['userId'] ?? chat['user_id'];
        if (userId == null) {
          enrichedChats.add(chat);
          continue;
        }

        // Try to get user from local database
        final user = await userRepo.getUserById(userId);

        if (user != null) {
          // Create enriched chat with displayName from local user
          final enrichedChat = Map<String, dynamic>.from(chat);
          enrichedChat['userName'] = user.displayName;
          enrichedChat['user_name'] = user.displayName;
          enrichedChats.add(enrichedChat);
        } else {
          // User not found in local DB, keep original chat
          enrichedChats.add(chat);
        }
      }

      return enrichedChats;
    } catch (e) {
      debugPrint('❌ Error enriching deleted chats with display names: $e');
      // Return original list if enrichment fails
      return chats;
    }
  }

  /// Enrich user list with display names from local database
  /// This ensures contact names (username) are preserved instead of server names
  Future<List<UserModel>> enrichUsersWithDisplayNames(
    List<UserModel> users,
  ) async {
    try {
      final userRepo = UserRepository();
      final enrichedUsers = <UserModel>[];

      for (final user in users) {
        // Try to get user from local database
        final localUser = await userRepo.getUserById(user.id);

        if (localUser != null && localUser.username != null) {
          // Update user with username from local database
          final enrichedUser = user.copyWith(
            username: localUser.username,
          );
          enrichedUsers.add(enrichedUser);
        } else {
          // User not found in local DB or no username, keep original user
          enrichedUsers.add(user);
        }
      }

      return enrichedUsers;
    } catch (e) {
      debugPrint('❌ Error enriching users with display names: $e');
      // Return original list if enrichment fails
      return users;
    }
  }
}
