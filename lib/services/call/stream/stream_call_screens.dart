import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Wraps Stream Video's prebuilt [StreamCallContainer] in a route. Centralised
/// here so the rest of the app doesn't need to know about Stream widget types.
///
/// We track an [isMounted] flag at the class level so the call service can
/// avoid pushing the screen twice when, for example, the user accepts an
/// incoming call from CallKit while the app is already foregrounded.
class StreamCallScreen extends StatefulWidget {
  final Call call;

  const StreamCallScreen({super.key, required this.call});

  static bool isMounted = false;

  @override
  State<StreamCallScreen> createState() => _StreamCallScreenState();
}

class _StreamCallScreenState extends State<StreamCallScreen> {
  @override
  void initState() {
    super.initState();
    StreamCallScreen.isMounted = true;
  }

  @override
  void dispose() {
    StreamCallScreen.isMounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamCallContainer(
          call: widget.call,
          // Auto-leave when the call enters a terminal state so the user lands
          // back on whatever screen they came from.
          onLeaveCallTap: () {
            widget.call.leave();
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
