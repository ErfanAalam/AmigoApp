import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/blurred-dialog.widget.dart';
import '../utils/navigation-helper.util.dart';
import 'contact-sync.service.dart';

/// Owns the *escalation* around the contacts permission so that
/// [ContactSyncService] can stay a pure offline reconciler that never prompts.
///
/// We can only show contact names when the OS has granted us contacts access.
/// This service is the single place that nudges the user toward granting it:
///
///   1. Ask for the permission (native system sheet).
///   2. If denied, wait 8 seconds, then show our frosted-glass warning
///      explaining that contact *names* won't show without access.
///   3. The warning's "Allow access" button re-surfaces the native system
///      sheet when the OS still allows it — we deliberately hold the second
///      native prompt back for this, so the user gets the real in-app dialog
///      rather than being dumped into Settings. We only deep-link to Settings
///      once the OS has permanently locked us out (iOS after its single
///      prompt, or Android after the final decline), where the native sheet
///      can no longer be shown by design.
///
/// Whenever permission is (or becomes) granted we kick [ContactSyncService] so
/// names populate immediately. Safe to call on every app load: if permission
/// is already granted it short-circuits straight to a sync.
class ContactPermissionService {
  static final ContactPermissionService _instance =
      ContactPermissionService._internal();
  factory ContactPermissionService() => _instance;
  ContactPermissionService._internal();

  static const String _tag = '[ContactPermission]';

  /// Re-entrancy guard. The escalation spans an 8-second wait plus async
  /// dialogs, and our entry point fires on every app resume — without this a
  /// resume mid-flow would stack a duplicate prompt sequence.
  bool _running = false;

  /// In-memory (per app launch) guard so we don't re-pop the warning on every
  /// resume once we've already nudged the user this session. Deliberately NOT
  /// persisted: a cold start should be allowed to nudge again (that's the
  /// "we try every load" intent), and persisting it made the whole flow look
  /// dead in development because the flag stuck across restarts.
  bool _warnedThisSession = false;

  /// Entry point. Call wherever you'd previously have called
  /// `ContactSyncService().sync()` at the app level. Pass [force] through to
  /// the underlying sync for explicit, debounce-skipping triggers (e.g. the
  /// first sync right after authentication).
  Future<void> ensure({bool force = false}) async {
    if (_running) {
      debugPrint('$_tag ensure() skipped — flow already running');
      return;
    }
    _running = true;
    try {
      final status = await Permission.contacts.status;
      debugPrint('$_tag ensure(force: $force) — current status: $status');

      // Fast path — already granted. Preserves the old "sync on every load"
      // behavior exactly.
      if (status.isGranted) {
        await ContactSyncService().sync(force: force);
        return;
      }

      // Already locked out by the OS (user denied in a previous session, or
      // hit "don't ask again"). request() would return instantly with no
      // system sheet, so skip straight to our own warning popup.
      if (status.isPermanentlyDenied || status.isRestricted) {
        debugPrint('$_tag permission permanently denied — showing warning');
        await _maybeShowWarning();
        return;
      }

      // Askable (denied / limited / provisional). First ask — the system
      // sheet shows here.
      final result = await Permission.contacts.request();
      debugPrint('$_tag after 1st request: $result');
      if (result.isGranted) {
        await ContactSyncService().sync(force: force);
        return;
      }

      // Denied. Wait 8 seconds, then show OUR popup. Crucially we DON'T fire a
      // bare second request() here: Android only ever grants two native
      // prompts, so we save the second one for the popup's "Allow access"
      // button. That lets the button re-surface the real system dialog (while
      // still askable) instead of dead-ending at Settings. The popup itself
      // decides at tap time whether a native ask is still possible or whether
      // the OS has locked us out (→ Settings).
      debugPrint('$_tag denied once, showing warning in 8s…');
      await Future.delayed(const Duration(seconds: 8));
      final after = await Permission.contacts.status;
      if (after.isGranted) {
        await ContactSyncService().sync(force: force);
        return;
      }
      await _maybeShowWarning();
    } catch (e, st) {
      debugPrint('$_tag flow failed: $e\n$st');
    } finally {
      _running = false;
    }
  }

  Future<void> _maybeShowWarning() async {
    if (_warnedThisSession) {
      debugPrint('$_tag warning already shown this session — skipping');
      return;
    }
    _warnedThisSession = true;

    // The dialog needs a live navigator. On a fast launch the route may not
    // be mounted yet, so wait briefly for one rather than no-op'ing. Read the
    // context fresh right before use (no await in between) so it can't go
    // stale across the wait.
    for (
      var i = 0;
      NavigationHelper.navigatorKey.currentContext == null && i < 10;
      i++
    ) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (NavigationHelper.navigatorKey.currentContext == null) {
      debugPrint('$_tag no navigator context — cannot show warning');
      _warnedThisSession = false; // let a later trigger try again
      return;
    }

    debugPrint('$_tag showing warning dialog');
    final allow = await showBlurredConfirm(
      // Inline access (not a captured local) — global navigator context,
      // safe across the wait above and accepted by the lint.
      context: NavigationHelper.navigatorKey.currentContext!,
      title: 'Show contact names',
      message:
          "Amigo can't read your contacts, so you'll only see usernames "
          "instead of your friends' names. To avoid confusion, Allow contacts access to show "
          'their names throughout the app.',
      confirmLabel: 'Allow access',
      cancelLabel: 'Not now',
      confirmIcon: Icons.contacts_outlined,
    );
    debugPrint('$_tag warning dialog result: allow=$allow');
    if (allow != true) return;

    // Decide live, at tap time, whether the native system dialog can still be
    // shown. While the permission is merely `denied` (Android, one prompt
    // still in the tank) request() surfaces the real system sheet — no
    // Settings detour. Only once it's `permanentlyDenied`/`restricted` (iOS
    // after its single prompt, or Android after the final decline) does the OS
    // suppress the sheet, leaving Settings as the only path in.
    final current = await Permission.contacts.status;
    debugPrint('$_tag "Allow access" tapped — status: $current');
    if (current.isPermanentlyDenied || current.isRestricted) {
      debugPrint('$_tag locked out by OS — opening app settings');
      await openAppSettings();
      return;
    }

    final result = await Permission.contacts.request(); // native system sheet
    debugPrint('$_tag after native re-request: $result');
    if (result.isGranted) {
      await ContactSyncService().sync(force: true);
    }
    // If they decline this fresh native sheet, respect it — don't yank them
    // off to Settings; they just made their choice in the system dialog.
  }
}
