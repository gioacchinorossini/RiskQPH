# Offline Mode Implementation

## Overview

This implementation provides a robust offline mode for the QR Attendance app with the following features:

1. **Loading Screen with Circular Animation**: Shows a beautiful rotating circle animation during app startup
2. **5-Second Connection Timeout**: If no connection is established within 5 seconds, shows offline mode option
3. **Offline Mode Button**: Appears after 5 seconds allowing users to continue with cached data
4. **Offline Indicator**: Orange bar at the top of screens when in offline mode
5. **Pull-to-Refresh Resync**: Users can pull down to attempt reconnection
6. **Quick Sync Button**: Tap the sync button in the offline bar for instant reconnection

## Implementation Details

### 1. Startup Screen Flow (`lib/screens/common/startup_screen.dart`)

The startup screen now implements the following flow:

```dart
// Circular loading animation with rotation
AnimatedBuilder(
  animation: _loadingAnimation,
  builder: (context, child) {
    return Transform.rotate(
      angle: _loadingAnimation.value * 2 * 3.14159,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 4,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ),
    );
  },
)
```

**Flow Steps:**
1. App starts with circular loading animation
2. Connection test begins immediately
3. After 5 seconds, if still connecting, offline button appears
4. If connection succeeds, proceed to normal navigation
5. If connection fails, keep showing loading with offline option
6. User can tap "Use Offline Mode" to continue with cached data

### 2. Offline Indicator Widget (`lib/widgets/offline_indicator.dart`)

A reusable widget that shows an orange bar at the top when the app is offline:

```dart
class OfflineIndicator extends StatelessWidget {
  final VoidCallback? onRefresh;
  final Widget child;

  // Shows orange bar with offline status and sync button
  // Automatically hides when connection is restored
}
```

**Features:**
- Orange background with offline bolt icon
- "Offline Mode - Using cached data" text
- Optional sync button for quick reconnection
- Automatically shows/hides based on connection status

### 3. Connection Testing (`lib/utils/connection_test.dart`)

Enhanced connection testing with 3-second timeout:

```dart
static Future<bool> testConnection() async {
  try {
    final response = await http.get(uri).timeout(
      const Duration(seconds: 3), // Reduced from 5 seconds
      onTimeout: () {
        throw Exception('Connection timeout');
      },
    );
    // ... rest of implementation
  } catch (e) {
    return false;
  }
}
```

### 4. Auth Provider Updates (`lib/providers/auth_provider.dart`)

Enhanced connection management:

```dart
Future<bool> testConnection() async {
  setLoading(true);
  _connectionStatus = 'Testing connection...';
  notifyListeners();

  try {
    final isConnected = await ConnectionTest.testConnection();
    _isConnected = isConnected;
    _connectionStatus = isConnected ? 'Connected' : 'Connection failed';
    setLoading(false);
    notifyListeners(); // Ensure UI updates
    return isConnected;
  } catch (e) {
    _isConnected = false;
    _connectionStatus = 'Connection error: $e';
    setLoading(false);
    notifyListeners(); // Ensure UI updates
    return false;
  }
}
```

## Usage Examples

### 1. Using OfflineIndicator in Screens

Wrap your screen content with the OfflineIndicator:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('My Screen')),
    body: OfflineIndicator(
      onRefresh: () async {
        // Refresh connection and data
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshConnection();
        if (authProvider.isConnected) {
          // Refresh your data here
        }
      },
      child: YourMainContent(),
    ),
  );
}
```

### 2. Testing Offline Mode

1. **Disconnect from internet** (turn off WiFi/mobile data)
2. **Restart the app** - you'll see the loading screen
3. **Wait 5 seconds** - offline button will appear
4. **Tap "Use Offline Mode"** - app continues with cached data
5. **Reconnect to internet** - pull down to refresh or tap sync button

### 3. Demo Screen

Use the demo screen to test offline functionality:

```dart
// Navigate to demo screen
Navigator.pushNamed(context, '/offline_demo');
```

## Key Features

### ✅ Implemented
- [x] Circular loading animation
- [x] 5-second connection timeout
- [x] Offline mode button
- [x] Offline indicator bar
- [x] Pull-to-refresh resync
- [x] Quick sync button
- [x] Cached data support
- [x] Connection status monitoring

### 🔄 User Experience Flow
1. **App Launch** → Circular loading animation starts
2. **Connection Test** → Attempts to connect to server
3. **5-Second Wait** → If still connecting, show offline option
4. **Offline Mode** → User can continue with cached data
5. **Reconnection** → Pull down or tap sync to reconnect
6. **Online Mode** → Normal app functionality restored

### 🎨 Visual Design
- **Loading Animation**: Rotating circle with gradient
- **Offline Indicator**: Orange bar with bolt icon
- **Sync Button**: Compact button with refresh icon
- **Status Messages**: Clear, user-friendly text

## Technical Notes

### Performance Optimizations
- 3-second connection timeout for faster response
- Efficient animation with `TickerProviderStateMixin`
- Proper disposal of animation controllers
- Minimal UI updates with `notifyListeners()`

### Error Handling
- Graceful timeout handling
- Connection error recovery
- Cached data fallback
- User-friendly error messages

### State Management
- Connection status in AuthProvider
- Offline mode state management
- Proper widget lifecycle handling
- Memory leak prevention

## Future Enhancements

1. **Background Sync**: Automatically sync when connection is restored
2. **Offline Queue**: Queue actions for when connection returns
3. **Data Compression**: Compress cached data for storage efficiency
4. **Sync Progress**: Show sync progress indicator
5. **Conflict Resolution**: Handle data conflicts when reconnecting

## Testing

To test the offline mode functionality:

1. Run the app on a device/emulator
2. Disconnect from internet
3. Restart the app
4. Observe the loading screen and offline button
5. Test offline mode features
6. Reconnect and test resync functionality

The implementation provides a smooth, user-friendly offline experience while maintaining app functionality with cached data. 