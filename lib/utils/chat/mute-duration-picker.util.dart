import 'package:flutter/material.dart';

import '../../ui/blurred-dialog.widget.dart';
import '../../ui/blurred-selection-dialog.widget.dart';

/// User's pick from [showMuteDurationPicker]. [until] is the absolute UTC
/// timestamp the chat should be muted until; null means "forever" (the
/// backend stores that as a far-future timestamp — see MUTED_FOREVER on
/// mute.service.ts).
class MuteDurationChoice {
  final DateTime? until;
  const MuteDurationChoice(this.until);
  bool get isForever => until == null;
}

// Internal sentinel for the "forever" radio option. We can't put `null` in
// a generic options list when other options carry DateTime values, so we
// use a single shared marker and map it back to MuteDurationChoice at the
// end. Kept private — callers only see MuteDurationChoice.
class _ForeverSentinel {
  const _ForeverSentinel();
}
const _foreverSentinel = _ForeverSentinel();

/// Ask the user how long to mute a chat for, using the blurred selection
/// dialog. Returns the chosen [MuteDurationChoice], or null if the user
/// cancelled / dismissed the dialog via the barrier.
///
/// The set of presets here intentionally matches what most messaging apps
/// offer: a short break (5h), a workweek (1w), a month, and indefinite.
Future<MuteDurationChoice?> showMuteDurationPicker(
  BuildContext context,
) async {
  // Compute absolute "until" timestamps now so the value remains stable
  // even if the user lingers in the dialog. Using UTC because the server
  // stores muted_until in UTC and the local DB mirror is ISO-UTC too.
  final now = DateTime.now().toUtc();
  // TEMPORARY: 1-minute option for end-to-end testing of mute expiration —
  // short enough to verify the send-path ZRANGEBYSCORE filter (the Redis
  // entry falls out by score) and the client-side isMuted getter
  // (mutedUntil < now() flips back to "not muted") in a single sitting.
  // Remove before GA.
  final oneMinute = now.add(const Duration(minutes: 1));
  final fiveHours = now.add(const Duration(hours: 5));
  final oneWeek = now.add(const Duration(days: 7));
  final oneMonth = now.add(const Duration(days: 30));

  final picked = await showBlurredSelectionDialog<Object>(
    context: context,
    title: 'Mute chat',
    body:
        "You won't get notifications for new messages. Messages still arrive in your chats list.",
    options: [
      BlurredSelectionOption<Object>(
        value: oneMinute,
        label: '1 minute',
        sublabel: 'Test option — remove before GA',
        icon: Icons.timer_outlined,
      ),
      BlurredSelectionOption<Object>(
        value: fiveHours,
        label: '5 hours',
        icon: Icons.access_time,
      ),
      BlurredSelectionOption<Object>(
        value: oneWeek,
        label: '1 week',
        icon: Icons.calendar_view_week,
      ),
      BlurredSelectionOption<Object>(
        value: oneMonth,
        label: '1 month',
        icon: Icons.calendar_month,
      ),
      const BlurredSelectionOption<Object>(
        value: _foreverSentinel,
        label: 'Forever',
        sublabel: 'Until you unmute',
        icon: Icons.all_inclusive,
      ),
    ],
    confirmLabel: 'Mute',
  );

  if (picked == null) return null;
  if (picked is DateTime) return MuteDurationChoice(picked);
  return const MuteDurationChoice(null); // forever
}

// Matches the backend's MUTED_FOREVER constant (Date.UTC(2125, 0, 1)) — see
// mute.service.ts. We compare by year rather than equality because the
// server may bump the constant later and the client shouldn't break.
bool _isForeverMute(DateTime until) => until.toUtc().year >= 2100;

/// Format a mutedUntil ISO string for display. Returns a string suitable for
/// dropping into a sentence like "Chat will automatically unmute [formatted]".
/// Returns null for "forever" (caller should phrase the prompt differently).
String? _formatMutedUntil(String? mutedUntilIso) {
  if (mutedUntilIso == null) return null;
  final until = DateTime.tryParse(mutedUntilIso);
  if (until == null) return null;
  if (_isForeverMute(until)) return null;

  final local = until.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final daysAway = thatDay.difference(today).inDays;

  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  if (daysAway == 0) return 'today at $time';
  if (daysAway == 1) return 'tomorrow at $time';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final monthLabel = months[local.month - 1];
  return 'on $monthLabel ${local.day} at $time';
}

/// Confirmation step for unmuting a chat. Shows a frosted-glass dialog that
/// tells the user when the chat would auto-unmute on its own (so they can
/// decide whether to act now or wait). Resolves true on confirm, false /
/// null on cancel or barrier dismiss.
///
/// The [mutedUntilIso] is the server-mirrored mute end timestamp from the
/// model — pass `conv.mutedUntil`, `group.mutedUntil`, etc. directly.
Future<bool?> showUnmuteConfirmation({
  required BuildContext context,
  required String? mutedUntilIso,
}) {
  final formatted = _formatMutedUntil(mutedUntilIso);
  final message = formatted != null
      ? 'This chat will automatically unmute $formatted.\n\nDo you want to unmute it now?'
      : "This chat is muted indefinitely. Do you want to unmute it now?";

  return showBlurredConfirm(
    context: context,
    title: 'Unmute chat?',
    message: message,
    confirmLabel: 'Unmute',
    confirmIcon: Icons.volume_up,
    cancelLabel: 'Cancel',
  );
}
