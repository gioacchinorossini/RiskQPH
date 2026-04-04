# Attendance App with QR Code

A comprehensive Flutter application for managing student attendance using QR codes. The app supports both student and administrator roles with modern UI design and efficient attendance tracking.

## Features

### For Students
- **User Registration & Login**: Students can create accounts and log in securely
- **Event Dashboard**: View upcoming and past events
- **QR Code Generation**: Generate unique QR codes for each event
- **Attendance History**: Track personal attendance records and statistics
- **Profile Management**: View and manage personal information

### For Administrators
- **Event Management**: Create, edit, and manage events
- **QR Code Scanner**: Scan student QR codes to mark attendance
- **Attendance Tracking**: View detailed attendance statistics and records
- **Dashboard Analytics**: Monitor attendance across all events
- **User Management**: Manage student accounts and permissions

## Technology Stack

- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **QR Code**: qr_flutter & qr_code_scanner
- **Local Storage**: SharedPreferences
- **UI/UX**: Material Design 3
- **Date/Time**: intl package

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Android/iOS device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd attendance_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Demo Credentials

#### Admin Account
- **Email**: admin@school.com
- **Password**: admin123

#### Student Account
- **Email**: student@school.com
- **Password**: student123

## App Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── event.dart
│   └── attendance.dart
├── providers/               # State management
│   ├── auth_provider.dart
│   ├── event_provider.dart
│   └── attendance_provider.dart
├── screens/                 # UI screens
│   ├── auth/               # Authentication screens
│   ├── student/            # Student screens
│   └── admin/              # Admin screens
└── utils/                  # Utilities
    └── theme.dart          # App theme configuration
```

## Key Features Explained

### QR Code System
- Each event generates a unique QR code containing event information
- Students display QR codes on their devices
- Administrators scan QR codes to mark attendance
- QR codes are event-specific and time-sensitive

### Attendance Tracking
- Automatic status detection (present/late/absent)
- Real-time attendance statistics
- Historical attendance records
- Export capabilities (future enhancement)

### Security Features
- Role-based access control
- Secure authentication
- QR code validation
- Duplicate attendance prevention

## Usage Guide

### For Students

1. **Registration/Login**
   - Create a new account or log in with existing credentials
   - Provide student ID and personal information

2. **View Events**
   - Browse upcoming and past events
   - View event details, location, and timing

3. **Generate QR Code**
   - Select an upcoming event
   - Generate and display QR code
   - Show QR code to administrator for scanning

4. **Track Attendance**
   - View personal attendance history
   - Check attendance statistics
   - Monitor attendance patterns

### For Administrators

1. **Event Management**
   - Create new events with details
   - Set event date, time, and location
   - Manage event status (active/inactive)

2. **QR Code Scanning**
   - Use camera to scan student QR codes
   - Automatic attendance marking
   - Real-time validation

3. **Attendance Monitoring**
   - View attendance statistics
   - Track individual student attendance
   - Generate attendance reports

## Configuration

### Theme Customization
Edit `lib/utils/theme.dart` to customize:
- Primary colors
- Secondary colors
- Typography
- Component styles

### Mock Data
The app currently uses mock data for demonstration. To integrate with a real backend:
1. Replace mock API calls in providers
2. Implement proper authentication
3. Add real database connectivity
4. Configure API endpoints

## Future Enhancements

- [ ] Real-time notifications
- [ ] Offline mode support
- [ ] Attendance reports export
- [ ] Push notifications
- [ ] Multi-language support
- [ ] Advanced analytics
- [ ] Bulk attendance marking
- [ ] Integration with school management systems

## Troubleshooting

### Common Issues

1. **Camera Permission**
   - Ensure camera permission is granted for QR scanning
   - Check device settings if permission is denied

2. **QR Code Not Scanning**
   - Ensure good lighting conditions
   - Hold device steady
   - Check QR code clarity

3. **App Crashes**
   - Clear app cache
   - Restart the app
   - Check Flutter version compatibility

### Debug Mode
Run in debug mode for detailed logs:
```bash
flutter run --debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

---

**Note**: This is a demonstration app with mock data. For production use, implement proper backend services and security measures. 