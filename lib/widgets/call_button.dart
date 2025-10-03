import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';

class CallButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, child) {
        final hasActiveCall = callService.hasActiveCall;

        if (isIconOnly) {
          return IconButton(
            onPressed: hasActiveCall
                ? null
                : () => _initiateCall(context, callService),
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
              : () => _initiateCall(context, callService),
          icon: const Icon(Icons.call),
          label: const Text('Call'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
        );
      },
    );
  }

  void _initiateCall(BuildContext context, CallService callService) async {
    try {
      await callService.initiateCall(userId, userName, userProfilePic);
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
