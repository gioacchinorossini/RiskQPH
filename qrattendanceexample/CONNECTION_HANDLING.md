# Connection Handling Features

This document describes the connection handling features implemented to fix the reload issue when IP addresses change.

## Overview

The app now includes robust connection testing and error handling to prevent the app from getting stuck on the loading screen when the server IP address changes.

## Features

### 1. Connection Testing
- **Automatic Testing**: The app tests the connection to the server on startup
- **Database Validation**: Tests both network connectivity and database connection
- **Timeout Handling**: 5-second timeout to prevent hanging

### 2. Error Handling
- **Connection Error Screen**: Shows when connection fails with retry options
- **Pull-to-Refresh**: Users can pull down to retry connection
- **Manual Retry Button**: Button to manually retry connection
- **Server URL Display**: Shows the current server URL for debugging

### 3. Connection Status Widget
- **Reusable Component**: Can be used in any screen to show connection status
- **Visual Indicators**: Green for connected, red for disconnected
- **Quick Retry**: Tap the refresh icon to retry connection

### 4. Connection Error Dialog
- **Modal Dialog**: Shows connection error details
- **Server Information**: Displays current server URL
- **Retry Option**: Button to retry connection

## Implementation Details

### Files Modified/Created

1. **`lib/utils/connection_test.dart`** - Connection testing utility
2. **`lib/providers/auth_provider.dart`** - Added connection status and testing
3. **`lib/screens/common/startup_screen.dart`** - Enhanced with connection testing
4. **`lib/widgets/connection_status_widget.dart`** - Reusable connection status widget
5. **`backend/api/connection_test.php`** - Server-side connection test endpoint

### Key Methods

#### AuthProvider
- `testConnection()` - Tests connection to server
- `refreshConnection()` - Refreshes connection status
- `clearConnectionCache()` - Clears cached connection status
- `handleConnectionError(context)` - Shows error dialog

#### ConnectionTest
- `testConnection()` - Static method to test connection
- `getConnectionInfo()` - Gets connection information

## Usage

### In Startup Screen
The startup screen automatically tests connection and shows error screen if connection fails.

### In Other Screens
```dart
// Add connection status widget to app bar
AppBar(
  title: const Text('Dashboard'),
  actions: [
    const ConnectionStatusWidget(),
  ],
)

// Handle connection errors in API calls
final auth = Provider.of<AuthProvider>(context, listen: false);
if (!await auth.handleConnectionError(context)) {
  return; // Stop execution if connection fails
}
```

### Manual Connection Testing
```dart
final auth = Provider.of<AuthProvider>(context, listen: false);
await auth.refreshConnection();
```

## Configuration

### Server URL Configuration
The server URL is configured in `lib/config/api_config.dart`:

```dart
static String get baseUrl {
  if (_definedBaseUrl.isNotEmpty) {
    return _definedBaseUrl;
  }
  
  if (kIsWeb) {
    return 'http://192.168.254.112/qrattendancebyxiansqlstepbasefunctions/backend';
  }
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://192.168.254.112/qrattendancebyxiansqlstepbasefunctions/backend';
  }
  
  return 'http://localhost/qrattendancebyxiansqlstep/backend';
}
```

### Environment Variable Override
You can override the server URL using environment variables:
```bash
flutter run --dart-define=API_BASE_URL=http://your-server-ip/path
```

## Troubleshooting

### Common Issues

1. **Connection Timeout**: Check if the server is running and accessible
2. **Wrong IP Address**: Update the IP address in `api_config.dart`
3. **Database Connection**: Ensure the database is running and accessible
4. **Network Issues**: Check network connectivity and firewall settings

### Debug Information
- The connection error screen shows the current server URL
- Connection status is displayed in the UI
- Server response includes timestamp and database connection status

## Future Enhancements

1. **Automatic IP Detection**: Automatically detect server IP on local network
2. **Multiple Server Support**: Support for multiple server endpoints
3. **Connection History**: Track connection attempts and failures
4. **Offline Mode**: Support for offline functionality when server is unavailable 