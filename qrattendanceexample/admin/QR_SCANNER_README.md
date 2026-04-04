# QR Code Scanner - Admin Dashboard

## Overview
The QR Code Scanner is a powerful feature in the admin dashboard that allows administrators to scan QR codes to mark student attendance for events. It includes both automatic scanning via camera and manual entry options.

## Features

### 🎥 Camera Scanner
- **Real-time QR Code Detection**: Uses device camera to scan QR codes in real-time
- **High-Quality Video**: Supports up to 720p video resolution for better scanning accuracy
- **Automatic Detection**: Continuously scans for QR codes and processes them automatically

### 📝 Manual Entry
- **Student ID Input**: Manually enter student IDs for attendance marking
- **Event Selection**: Choose from available events for attendance tracking
- **Quick Processing**: Immediate attendance marking without scanning

### 🧪 Test QR Code Generator
- **QR Code Creation**: Generate test QR codes for testing the scanner
- **Customizable Content**: Input any student ID to generate corresponding QR code
- **High-Quality Output**: 200x200 pixel QR codes with clean design

### 📊 Recent Scans
- **Scan History**: View the last 10 scans with status and timestamps
- **Success/Error Tracking**: Color-coded results for easy identification
- **Real-time Updates**: Live updates as new scans are processed

## How to Use

### Starting the Scanner
1. Navigate to the **QR Scanner** section in the admin dashboard
2. Select an event from the dropdown menu
3. Click **"Start Scanner"** button
4. Allow camera access when prompted
5. Point the camera at a QR code

### Scanning QR Codes
1. **Automatic Mode**: Simply point the camera at any QR code
2. **Real-time Processing**: QR codes are detected and processed automatically
3. **Attendance Marking**: Successful scans automatically mark attendance
4. **Feedback**: Notifications show scan results and attendance status

### Manual Entry
1. Enter the student ID in the **Student ID** field
2. Select the appropriate event from the dropdown
3. Click **"Mark Attendance"** button
4. The system will process the request and show results

### Generating Test QR Codes
1. Enter a student ID in the **Generate Test QR Code** section
2. Click the QR code icon button
3. A QR code will be generated for testing purposes
4. Use this QR code to test the scanner functionality

## Technical Details

### QR Code Format
The scanner supports multiple QR code formats:
- **Plain Text**: Simple student ID strings
- **JSON Format**: Structured data with student_id/studentId fields
- **Custom Formats**: Extensible for future enhancements

### Camera Requirements
- **Device Camera**: Requires access to device camera
- **Browser Support**: Works in modern browsers with camera access
- **Resolution**: Optimized for 720p video quality
- **Framerate**: 10 FPS scanning for optimal performance

### Libraries Used
- **jsQR**: For QR code detection and parsing
- **QRCode.js**: For generating test QR codes
- **MediaDevices API**: For camera access and video streaming

## Troubleshooting

### Common Issues

#### Camera Not Working
- Ensure camera permissions are granted
- Check if another application is using the camera
- Try refreshing the page and granting permissions again

#### QR Codes Not Detected
- Ensure good lighting conditions
- Hold the QR code steady and centered
- Check if the QR code is damaged or low quality
- Verify the QR code contains valid data

#### Scanner Won't Start
- Make sure an event is selected
- Check browser console for error messages
- Ensure the page is loaded completely
- Try refreshing the page

### Error Messages
- **"Please select an event first!"**: Select an event before starting the scanner
- **"Failed to start scanner"**: Camera access issue or browser compatibility
- **"Network error"**: Backend connection issue
- **"Failed to mark attendance"**: Database or API error

## Best Practices

### For Administrators
1. **Event Selection**: Always select the correct event before scanning
2. **Camera Setup**: Ensure good lighting and stable camera position
3. **QR Code Quality**: Use high-quality, well-lit QR codes
4. **Regular Testing**: Test the scanner before major events

### For Students
1. **QR Code Display**: Show QR codes clearly on mobile devices
2. **Screen Brightness**: Ensure maximum screen brightness
3. **Steady Holding**: Keep the QR code steady during scanning
4. **Clean Screens**: Avoid smudges or damage to QR codes

## Security Features

### Access Control
- **Admin Only**: QR scanner is restricted to admin users
- **Event Validation**: Attendance can only be marked for valid events
- **Audit Trail**: All scans are logged with timestamps
- **Data Validation**: Input validation for all manual entries

### Data Protection
- **Secure API Calls**: All requests use secure HTTP methods
- **Input Sanitization**: All user inputs are validated and sanitized
- **Error Handling**: Comprehensive error handling without data exposure
- **Session Management**: Secure admin session validation

## Future Enhancements

### Planned Features
- **Batch Processing**: Scan multiple QR codes simultaneously
- **Offline Mode**: Work without internet connection
- **Advanced Analytics**: Detailed scanning statistics and reports
- **Mobile App**: Dedicated mobile application for scanning
- **Biometric Integration**: Fingerprint or face recognition support

### API Extensions
- **Webhook Support**: Real-time notifications for attendance events
- **Third-party Integration**: Connect with external attendance systems
- **Custom QR Formats**: Support for industry-standard QR code formats
- **Multi-language Support**: Internationalization for global use

## Support

For technical support or feature requests, please contact the development team or refer to the main project documentation.

---

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Compatibility**: Modern browsers with camera support 