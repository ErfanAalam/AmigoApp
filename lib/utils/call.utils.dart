import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call.model.dart';

class CallUtils {
  // Save call details to shared preferences
  Future<void> saveCallDetails(CallDetails callDetails) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'current_call_details',
      jsonEncode(callDetails.toJson()),
    );
  }

  // Get call details from shared preferences
  Future<CallDetails?> getCallDetails() async {
    final prefs = await SharedPreferences.getInstance();

    String? callJson = prefs.getString('current_call_details');

    if (callJson == null) return null;

    // Decode JSON string back to CallDetails
    return CallDetails.fromJson(jsonDecode(callJson));
  }

  // Update call details in shared preferences
  Future<void> updateCallDetails(CallDetails callDetails) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the existing call data
    String? callJson = prefs.getString('current_call_details');

    if (callJson == null) {
      // No call data saved yet, just save the new one
      await saveCallDetails(callDetails);
      return;
    }

    // Decode existing map
    CallDetails existingCall = CallDetails.fromJson(jsonDecode(callJson));

    // Update with new values
    final updatedCall = existingCall.copyWith(
      callId: callDetails.callId,
      callerId: callDetails.callerId,
      callerName: callDetails.callerName,
      callerProfilePic: callDetails.callerProfilePic,
      callStatus: callDetails.callStatus,
    );

    // Save updated map back to SharedPreferences
    await prefs.setString(
      'current_call_details',
      jsonEncode(updatedCall.toJson()),
    );
  }

  // ── Incoming-call name seed ────────────────────────────────────────────
  // A dedicated, collision-free record (separate from `current_call_details`,
  // which main.dart and the WebRTC path also use) that bridges the FCM
  // background isolate → the cold-started main isolate. The Stream FCM handler
  // writes the caller id + already-resolved display name here when it shows the
  // incoming-call notification; the cold-start accept reads it to seed the call
  // screen's name BEFORE the first paint, so the contact name resolves up front
  // instead of flickering in after the SFU/DB round-trip.
  static const String _incomingCallSeedKey = 'incoming_call_name_seed';

  Future<void> saveIncomingCallSeed({
    required String cid,
    required String callerId,
    String? name,
    String? profilePic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _incomingCallSeedKey,
      jsonEncode({
        'cid': cid,
        'callerId': callerId,
        'name': name,
        'profilePic': profilePic,
      }),
    );
  }

  /// Returns the seed only when it matches [cid] (guards against a stale record
  /// from a previous call seeding the wrong name). Keys: callerId, name,
  /// profilePic.
  Future<Map<String, String?>?> getIncomingCallSeed(String cid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incomingCallSeedKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['cid']?.toString() != cid) return null;
      return {
        'callerId': m['callerId']?.toString(),
        'name': m['name']?.toString(),
        'profilePic': m['profilePic']?.toString(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearIncomingCallSeed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_incomingCallSeedKey);
  }

  // Clear call details from shared preferences
  Future<void> clearCallDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_call_id');
    await prefs.remove('current_caller_id');
    await prefs.remove('current_caller_name');
    await prefs.remove('current_caller_profile_pic');
    await prefs.remove('call_status');
    await prefs.remove('current_call_details');
  }

  // Save individual call fields (for backward compatibility)
  Future<void> saveCallId(String callId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_call_id', callId);

    // Also update the CallDetails object
    final existing = await getCallDetails();
    if (existing != null) {
      await updateCallDetails(existing.copyWith(callId: callId));
    }
  }

  Future<void> saveCallerId(String callerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_caller_id', callerId);

    // Also update the CallDetails object
    final existing = await getCallDetails();
    if (existing != null) {
      await updateCallDetails(existing.copyWith(callerId: callerId));
    }
  }

  Future<void> saveCallerName(String callerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_caller_name', callerName);

    // Also update the CallDetails object
    final existing = await getCallDetails();
    if (existing != null) {
      await updateCallDetails(existing.copyWith(callerName: callerName));
    }
  }

  Future<void> saveCallerProfilePic(String? callerProfilePic) async {
    final prefs = await SharedPreferences.getInstance();
    if (callerProfilePic != null) {
      await prefs.setString('current_caller_profile_pic', callerProfilePic);
    } else {
      await prefs.remove('current_caller_profile_pic');
    }

    // Also update the CallDetails object
    final existing = await getCallDetails();
    if (existing != null) {
      await updateCallDetails(
        existing.copyWith(callerProfilePic: callerProfilePic),
      );
    }
  }

  Future<void> saveCallStatus(String callStatus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('call_status', callStatus);

    // Also update the CallDetails object
    final existing = await getCallDetails();
    if (existing != null) {
      await updateCallDetails(existing.copyWith(callStatus: callStatus));
    }
  }

  // Get individual call fields (for backward compatibility)
  Future<String?> getCallId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_call_id');
  }

  Future<String?> getCallerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_caller_id');
  }

  Future<String?> getCallerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_caller_name');
  }

  Future<String?> getCallerProfilePic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_caller_profile_pic');
  }

  Future<String?> getCallStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('call_status');
  }

  // Check if there's an active call
  Future<bool> hasActiveCall() async {
    final callDetails = await getCallDetails();
    if (callDetails == null) return false;
    return callDetails.isActive;
  }

  // Sync from legacy SharedPreferences keys to CallDetails model
  Future<void> syncFromLegacyKeys() async {
    final prefs = await SharedPreferences.getInstance();

    final callIdStr = prefs.getString('current_call_id');
    final callerIdStr = prefs.getString('current_caller_id');
    final callerName = prefs.getString('current_caller_name');
    final callerProfilePic = prefs.getString('current_caller_profile_pic');
    final callStatus = prefs.getString('call_status');

    // Only sync if we have at least one value and CallDetails doesn't exist
    if (prefs.getString('current_call_details') == null &&
        (callIdStr != null ||
            callerIdStr != null ||
            callerName != null ||
            callerProfilePic != null ||
            callStatus != null)) {
      final callDetails = CallDetails(
        callId: callIdStr,
        callerId: callerIdStr,
        callerName: callerName,
        callerProfilePic: callerProfilePic,
        callStatus: callStatus,
      );
      await saveCallDetails(callDetails);
    }
  }
}
