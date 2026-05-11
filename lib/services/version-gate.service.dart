import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_service.dart';

/// Result of comparing the running build against backend-supplied minimums.
enum VersionGateStatus {
  /// Check hasn't run yet — UI should keep showing whatever it had.
  unknown,

  /// Build is at or above `min_build` — let the user through.
  ok,

  /// Build is below `min_build` — block the user behind the gate screen.
  blocked,
}

class VersionGateState {
  final VersionGateStatus status;
  final String? latestVersion;
  final String? storeUrl;
  final String? message;

  const VersionGateState({
    required this.status,
    this.latestVersion,
    this.storeUrl,
    this.message,
  });

  static const unknown = VersionGateState(status: VersionGateStatus.unknown);
}

/// Singleton that asks the backend whether the running build is still
/// allowed. Read once at app start and again on resume from background.
///
/// Failure to reach the backend is treated as `ok` — a server outage
/// shouldn't lock everyone out of the app.
class VersionGateService {
  VersionGateService._internal();
  static final VersionGateService _instance = VersionGateService._internal();
  factory VersionGateService() => _instance;

  final ValueNotifier<VersionGateState> state = ValueNotifier(
    VersionGateState.unknown,
  );

  bool _checkInFlight = false;

  Future<void> check() async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    try {
      final platform = _platformKey();
      if (platform == null) {
        state.value = const VersionGateState(status: VersionGateStatus.ok);
        return;
      }

      final pkg = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;

      final result = await ApiService().version.getAppVersion(platform);
      if (!result.isSuccess || result.data is! Map<String, dynamic>) {
        // Fail open — backend down, no Redis entry, etc. shouldn't block users.
        debugPrint('[version-gate] check skipped: ${result.message}');
        state.value = const VersionGateState(status: VersionGateStatus.ok);
        return;
      }

      final data = result.data as Map<String, dynamic>;
      final minBuild = (data['min_build'] as num?)?.toInt() ?? 0;
      final latestVersion = data['latest_version']?.toString();
      final storeUrl = data['store_url']?.toString();
      final message = data['message']?.toString();

      final blocked = currentBuild > 0 && currentBuild < minBuild;
      debugPrint(
        '[version-gate] currentBuild=$currentBuild minBuild=$minBuild '
        'latestVersion=$latestVersion blocked=$blocked',
      );

      state.value = VersionGateState(
        status: blocked ? VersionGateStatus.blocked : VersionGateStatus.ok,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
        message: (message != null && message.isNotEmpty) ? message : null,
      );
    } catch (e) {
      debugPrint('[version-gate] check failed: $e');
      state.value = const VersionGateState(status: VersionGateStatus.ok);
    } finally {
      _checkInFlight = false;
    }
  }

  static String? _platformKey() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }
}
