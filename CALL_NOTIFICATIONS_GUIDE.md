# Call Push Notifications with Tap Actions

This guide explains the call push notification system with Accept/Decline tap actions.

## Features

### ✅ **Call Notifications with Actions**
- **Accept Call** button - Accepts the incoming call
- **Decline Call** button - Declines the incoming call
- **Tap notification** - Opens incoming call screen
- **Full-screen intent** - Shows notification even on lock screen
- **Ongoing notification** - Prevents accidental dismissal
- **Custom icons** - Green checkmark for accept, red X for decline

### ✅ **Notification Types**
1. **Incoming Call** - Shows when someone calls you
2. **Call Accepted** - Shows when you accept a call
3. **Call Declined** - Shows when you decline a call
4. **Call Updates** - Shows call status changes

## How It Works

### 1. **Incoming Call Flow**
```
User A calls User B
    ↓
Backend sends WebSocket message to User B
    ↓
If User B is offline, backend sends FCM push notification
    ↓
Android shows full-screen call notification with Accept/Decline buttons
    ↓
User B taps Accept/Decline
    ↓
App handles action and sends WebSocket message to backend
    ↓
Backend notifies User A of the action
```

### 2. **Notification Actions**
- **Accept**: Sends `call:accept` WebSocket message, navigates to call screen
- **Decline**: Sends `call:decline` WebSocket message, clears notification
- **Tap**: Opens incoming call screen for manual handling

## Implementation Details

### **Files Created/Modified**

#### **New Files:**
- `lib/services/call_notification_handler.dart` - Handles call notification actions
- `lib/services/call_notification_demo.dart` - Test functions
- `android/app/src/main/res/drawable/ic_call_accept.xml` - Accept button icon
- `android/app/src/main/res/drawable/ic_call_decline.xml` - Decline button icon

#### **Modified Files:**
- `lib/services/notification_service.dart` - Enhanced with call actions
- `lib/main.dart` - Added call notification handler initialization

### **Key Components**

#### **1. Call Notification Handler**
```dart
class CallNotificationHandler {
  // Handles accept/decline actions
  void _handleAcceptCall(String callId, String? callerId, String? callerName, String? callType)
  void _handleDeclineCall(String callId, String? callerId)
  void _handleTapCallNotification(String callId, String? callerId, String? callerName, String? callType)
}
```

#### **2. Enhanced Notification Service**
```dart
// Call notification with actions
Future<void> _showCallNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
})

// Call notification management
Future<void> clearCallNotification(String callId)
Future<void> updateCallNotification({...})
```

#### **3. Notification Actions**
```dart
actions: [
  AndroidNotificationAction(
    'accept_call',
    'Accept',
    icon: DrawableResourceAndroidBitmap('ic_call_accept'),
    showsUserInterface: true,
  ),
  AndroidNotificationAction(
    'decline_call',
    'Decline',
    icon: DrawableResourceAndroidBitmap('ic_call_decline'),
    showsUserInterface: true,
  ),
]
```

## Testing

### **Automatic Test**
The app includes an automatic test that shows a call notification 5 seconds after startup:

```dart
// In main.dart - remove in production
void _testCallNotification() {
  Future.delayed(const Duration(seconds: 5), () {
    CallNotificationDemo().testCallNotification();
  });
}
```

### **Manual Test**
```dart
// Test call notification
await CallNotificationDemo().testCallNotification();

// Test message notification
await CallNotificationDemo().testMessageNotification();
```

### **Test Steps**
1. Run the app
2. Wait 5 seconds for automatic test
3. You should see a call notification with Accept/Decline buttons
4. Tap Accept - should show "Call Accepted" notification
5. Tap Decline - should show "Call Declined" notification
6. Tap notification body - should open incoming call screen

## Configuration

### **Android Permissions**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
```

### **Notification Channels**
- **Calls**: High priority, full-screen intent, ongoing
- **Messages**: High priority, groupable

### **Notification Properties**
```dart
const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'calls',
  'Calls',
  importance: Importance.max,
  priority: Priority.high,
  playSound: true,
  enableVibration: true,
  fullScreenIntent: true,
  category: AndroidNotificationCategory.call,
  ongoing: true,
  autoCancel: false,
);
```

## Integration with Backend

### **WebSocket Messages**
- `call:accept` - Sent when user accepts call
- `call:decline` - Sent when user declines call
- `call:ringing` - Received when incoming call

### **FCM Payload**
```json
{
  "type": "call",
  "callId": "12345",
  "callerId": "67890",
  "callerName": "John Doe",
  "callType": "audio",
  "callerProfilePic": "https://example.com/profile.jpg"
}
```

## Customization

### **Icons**
- Replace `ic_call_accept.xml` and `ic_call_decline.xml` with your custom icons
- Icons should be 24dp x 24dp vector drawables

### **Colors**
- Accept button: Green (#4CAF50)
- Decline button: Red (#F44336)
- Modify colors in the XML files

### **Text**
- Customize notification titles and bodies
- Modify action button labels

### **Behavior**
- Change notification priority and importance
- Modify sound and vibration patterns
- Adjust full-screen intent behavior

## Troubleshooting

### **Common Issues**

1. **No notification appears**
   - Check notification permissions
   - Verify Firebase configuration
   - Check notification channels

2. **Actions don't work**
   - Verify action IDs match exactly
   - Check notification payload parsing
   - Ensure WebSocket connection is active

3. **Icons don't show**
   - Verify icon files are in correct location
   - Check icon file format (should be vector drawable)
   - Ensure proper naming convention

### **Debug Steps**

1. Check logs for notification creation
2. Verify action button taps are received
3. Test WebSocket message sending
4. Verify notification payload format

## Production Notes

### **Remove Test Code**
- Remove `_testCallNotification()` from main.dart
- Remove `CallNotificationDemo` class
- Remove test imports

### **Security Considerations**
- Validate call data before processing
- Implement proper authentication for call actions
- Add rate limiting for call notifications

### **Performance**
- Clear old notifications regularly
- Limit notification history
- Optimize payload size

## Future Enhancements

- **Video call preview** in notification
- **Caller photo** in notification
- **Custom ringtones** per caller
- **Snooze call** option
- **Call recording** from notification
- **Quick reply** messages for missed calls
