import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version-gate.service.dart';
import '../ui/snackbar.dart';

/// Full-screen blocking gate shown when the running build is below the
/// backend-supplied `min_build`. Single CTA: open the store listing.
/// No back button, no skip — this is the whole UI until the user updates.
class VersionGateScreen extends StatelessWidget {
  final VersionGateState state;

  const VersionGateScreen({super.key, required this.state});

  Future<void> _openStore(BuildContext context) async {
    final url = state.storeUrl;
    if (url == null || url.isEmpty) {
      Snack.error('No update URL configured.');
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Snack.error('Could not open the store.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = state.latestVersion;
    final message = state.message;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    color: Colors.blue.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'A newer version of Amigo is required to continue. '
                          'Please update to keep using the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (latest != null && latest.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Latest version: $latest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: () => _openStore(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Update on Play Store',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => VersionGateService().check(),
                  child: Text(
                    'I\'ve updated — re-check',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
