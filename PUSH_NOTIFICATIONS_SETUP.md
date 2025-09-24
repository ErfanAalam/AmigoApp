# Push Notifications Setup Guide

This guide explains how to set up push notifications for the Amigo chat app.

## Overview

The app now supports push notifications for:
- **Incoming messages** when the app is in background/closed
- **Incoming calls** when the app is in background/closed

## Setup Required

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Add Android app with package name: `com.example.amigo`
4. Download `google-services.json` and replace the placeholder file at:
   ```
   android/app/google-services.json
   ```
5. Update `firebase_options.dart` with your actual Firebase configuration

### 2. Backend Firebase Admin Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate a new private key
3. Download the JSON file and place it in your backend project
4. Update the Firebase Admin initialization in `src/services/fcm.service.ts`

### 3. Environment Variables

Add to your backend `.env` file:
```env
GOOGLE_APPLICATION_CREDENTIALS=path/to/your/service-account-key.json
```

## Features Implemented

### Flutter App
- ✅ Firebase Cloud Messaging integration
- ✅ Local notifications for foreground messages
- ✅ Notification permission handling
- ✅ FCM token management and backend sync
- ✅ Notification channels for messages and calls
- ✅ Background message handling

### Backend
- ✅ FCM service for sending notifications
- ✅ WebSocket integration for offline users
- ✅ Database schema for FCM tokens
- ✅ API endpoints for token management
- ✅ Call notification support
- ✅ Message notification support

## How It Works

### Message Notifications
1. User sends a message via WebSocket
2. Backend broadcasts to online users via WebSocket
3. For offline users, backend sends push notification via FCM
4. Android receives notification and displays it
5. User taps notification to open the app

### Call Notifications
1. User initiates a call via WebSocket
2. Backend tries to send WebSocket message to callee
3. If callee is offline, backend sends push notification
4. Android shows full-screen call notification
5. User can accept/decline from notification

## Testing

### Test Message Notifications
1. Install app on two devices
2. Login with different accounts
3. Close one app (or put in background)
4. Send message from other device
5. Should receive push notification

### Test Call Notifications
1. Install app on two devices
2. Login with different accounts
3. Close one app (or put in background)
4. Initiate call from other device
5. Should receive call notification

## Troubleshooting

### Common Issues

1. **No notifications received**
   - Check Firebase configuration
   - Verify FCM token is being sent to backend
   - Check notification permissions

2. **Notifications not showing**
   - Check Android notification settings
   - Verify notification channels are created
   - Check if app is in battery optimization whitelist

3. **Backend errors**
   - Verify Firebase Admin SDK setup
   - Check service account permissions
   - Verify database migration ran successfully

### Debug Steps

1. Check logs for FCM token generation
2. Verify token is sent to backend
3. Check backend logs for notification sending
4. Test with Firebase Console messaging tool

## Files Modified

### Flutter App
- `pubspec.yaml` - Added Firebase dependencies
- `android/app/build.gradle.kts` - Added Firebase plugin
- `android/build.gradle.kts` - Added Google services
- `android/app/src/main/AndroidManifest.xml` - Added permissions and services
- `lib/services/notification_service.dart` - Main notification service
- `lib/main.dart` - Initialize notification service
- `lib/api/api_service.dart` - Added FCM token update method

### Backend
- `src/services/fcm.service.ts` - FCM service implementation
- `src/models/user.model.ts` - Added FCM token field
- `src/routes/user.routes.ts` - Added FCM token update endpoint
- `src/sockets/web-socket.ts` - Integrated push notifications
- Database migration for FCM token field

## Next Steps

1. Replace placeholder Firebase configuration with real values
2. Test on physical devices
3. Configure notification sounds and icons
4. Add notification analytics
5. Implement notification preferences in app settings
