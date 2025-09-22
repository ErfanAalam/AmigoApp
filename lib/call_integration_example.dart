// Example integration file showing how to set up the call system
// This file demonstrates how to integrate the call functionality into your existing app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/call_service.dart';
import 'widgets/call_manager.dart';
import 'widgets/call_banner.dart';
import 'widgets/call_button.dart';
import 'screens/call/in_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';

class CallIntegrationExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add CallService to your existing providers
        ChangeNotifierProvider<CallService>(
          create: (_) => CallService()..initialize(),
        ),
        // ... your other providers
      ],
      child: MaterialApp(
        title: 'Chat App with Calls',
        theme: ThemeData(primarySwatch: Colors.blue),
        // Wrap your app with CallEnabledApp
        home: CallEnabledApp(child: MainAppScreen()),
        routes: {
          '/call': (context) => const InCallScreen(),
          '/incoming-call': (context) => const IncomingCallScreen(),
        },
      ),
    );
  }
}

class MainAppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Call banner at the top
          const CallBanner(),

          // Your existing app content
          Expanded(child: YourExistingContent()),
        ],
      ),
    );
  }
}

class YourExistingContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Your existing app content'),

          // Example: Add call button to chat header
          ChatHeaderWithCall(
            userId: 123,
            userName: 'John Doe',
            userProfilePic: 'https://example.com/avatar.jpg',
          ),

          // Example: Add call button to contact list
          ContactListItem(
            userId: 456,
            userName: 'Jane Smith',
            userProfilePic: null,
          ),
        ],
      ),
    );
  }
}

// Example: Chat header with call button
class ChatHeaderWithCall extends StatelessWidget {
  final int userId;
  final String userName;
  final String? userProfilePic;

  const ChatHeaderWithCall({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfilePic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            backgroundImage: userProfilePic != null
                ? NetworkImage(userProfilePic!)
                : null,
            child: userProfilePic == null
                ? Text(userName[0].toUpperCase())
                : null,
          ),

          const SizedBox(width: 12),

          // User name
          Expanded(
            child: Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),

          // Call button
          CallButton(
            userId: userId,
            userName: userName,
            userProfilePic: userProfilePic,
          ),
        ],
      ),
    );
  }
}

// Example: Contact list item with call button
class ContactListItem extends StatelessWidget {
  final int userId;
  final String userName;
  final String? userProfilePic;

  const ContactListItem({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfilePic,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: userProfilePic != null
            ? NetworkImage(userProfilePic!)
            : null,
        child: userProfilePic == null ? Text(userName[0].toUpperCase()) : null,
      ),
      title: Text(userName),
      trailing: CallButton(
        userId: userId,
        userName: userName,
        userProfilePic: userProfilePic,
      ),
    );
  }
}

/*
=== INTEGRATION STEPS ===

1. Add dependencies to pubspec.yaml:
   - flutter_webrtc: ^0.12.2
   - wakelock_plus: ^1.2.8

2. Update your main.dart:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     runApp(
       MultiProvider(
         providers: [
           ChangeNotifierProvider<CallService>(
             create: (_) => CallService()..initialize(),
           ),
           // ... your other providers
         ],
         child: CallEnabledApp(
           child: MyApp(),
         ),
       ),
     );
   }
   ```

3. Wrap your main content with call functionality:
   ```dart
   Scaffold(
     body: Column(
       children: [
         const CallBanner(), // Shows ongoing call banner
         Expanded(child: YourContent()),
       ],
     ),
   )
   ```

4. Add call buttons where needed:
   ```dart
   CallButton(
     userId: otherUserId,
     userName: otherUserName,
     userProfilePic: otherUserProfilePic,
   )
   ```

5. Add routes to your app:
   ```dart
   routes: {
     '/call': (context) => const InCallScreen(),
     '/incoming-call': (context) => const IncomingCallScreen(),
   }
   ```

6. Backend setup:
   - Run the database migration: drizzle/0006_create_calls_table.sql
   - The WebSocket handlers are automatically added to your existing web-socket.ts
   - Make sure users have call_access = true in the database

=== PRODUCTION CONSIDERATIONS ===

1. STUN/TURN Servers:
   - Current config uses Google's free STUN server
   - For production, add TURN servers for NAT traversal:
     ```dart
     {'urls': 'turn:your-turn-server.com:3478', 'username': 'user', 'credential': 'pass'}
     ```

2. Permissions:
   - Add microphone permissions to AndroidManifest.xml and Info.plist
   - Handle permission requests in your app

3. Background calls:
   - Integrate with CallKit (iOS) and ConnectionService (Android)
   - Add push notifications for missed calls

4. Security:
   - JWT authentication is already implemented
   - Consider adding call recording consent
   - Implement call quality monitoring

5. Audio quality:
   - Current config has echo cancellation and noise suppression
   - Test on various devices and network conditions
   - Consider codec preferences for better quality

=== CALL LIFECYCLE ===

1. Caller initiates call → Backend creates call record → Callee receives notification
2. Callee accepts → WebRTC negotiation begins (offer/answer/ICE)
3. Connection established → Call timer starts
4. Either party ends call → Cleanup and duration calculation
5. Auto-timeout after 30 seconds if not answered (marked as missed)

=== DEBUGGING TIPS ===

1. Check WebSocket connection in browser dev tools
2. Monitor WebRTC connection state changes
3. Verify microphone permissions
4. Test on real devices (not just simulator)
5. Check backend logs for call state transitions

*/
