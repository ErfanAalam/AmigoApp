import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
}
