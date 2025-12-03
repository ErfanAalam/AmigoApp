import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/call.provider.dart';

class CallButton extends ConsumerWidget {
  final int userId;
  final String userName;
  final String? userProfilePic;
  final bool isIconOnly;

  const CallButton({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    this.isIconOnly = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callServiceState = ref.watch(callServiceProvider);
    final callServiceNotifier = ref.read(callServiceProvider.notifier);
    final hasActiveCall = callServiceState.hasActiveCall;

    if (isIconOnly) {
      return IconButton(
        onPressed: hasActiveCall
            ? null
            : () => _initiateCall(context, callServiceNotifier),
        icon: Icon(
          Icons.call,
          color: hasActiveCall ? Colors.grey : Colors.green,
        ),
        tooltip: hasActiveCall ? 'Already in a call' : 'Start audio call',
      );
    }

    return ElevatedButton.icon(
      onPressed: hasActiveCall
          ? null
          : () => _initiateCall(context, callServiceNotifier),
      icon: const Icon(Icons.call),
      label: const Text('Call'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  void _initiateCall(
    BuildContext context,
    CallServiceNotifier callServiceNotifier,
  ) async {
    try {
      await callServiceNotifier.initiateCall(userId, userName, userProfilePic);
      // CallKitParams params = CallKitParams(
      //   id: userId.toString(),
      //   nameCaller: userName,
      //   handle: '0123456789',
      //   type: 0,
      //   extra: <String, dynamic>{'userId': userId},
      //   ios: IOSParams(handleType: 'generic'),
      //   callingNotification: const NotificationParams(
      //     showNotification: true,
      //     isShowCallback: true,
      //     subtitle: 'Calling...',
      //     callbackText: 'Hang Up',
      //   ),
      //   android: const AndroidParams(
      //     isCustomNotification: true,
      //     isShowCallID: true,
      //   ),
      // );
      // await FlutterCallkitIncoming.startCall(params);

      // Navigate to in-call screen
      if (context.mounted) {
        Navigator.of(context).pushNamed('/call');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
