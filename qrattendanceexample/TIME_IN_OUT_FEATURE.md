# Time In/Time Out Feature

## Overview

The QR Attendance App now supports a comprehensive time in/time out system that allows students to check in when they arrive at an event and check out when they leave. This provides better tracking of student attendance and duration.

## Features

### 1. **Dual Time Tracking**
- **Check-in Time**: Records when a student arrives at an event
- **Check-out Time**: Records when a student leaves an event
- **Duration Calculation**: Automatically calculates how long a student stayed

### 2. **Smart Status Management**
- **Present**: Student checked in and checked out within event time
- **Late**: Student checked in after event start time + 15 minutes
- **Left Early**: Student checked out before event end time
- **Absent**: Student never checked in

### 3. **Event Time Management**
- **Start Time**: When the event begins
- **End Time**: When the event ends
- **Validation**: Ensures end time is after start time

## How It Works

### For Students
1. **First Scan**: Student scans QR code → **CHECKED IN**
2. **Second Scan**: Student scans QR code again → **CHECKED OUT**
3. **Status Update**: System automatically determines if student left early

### For Administrators
1. **Create Events**: Set start and end times for events
2. **Monitor Attendance**: View real-time check-in/check-out status
3. **Generate Reports**: See attendance duration and patterns

## Database Changes

### Events Table
```sql
ALTER TABLE events ADD COLUMN end_time DATETIME NOT NULL AFTER start_time;
```

### Attendance Table
```sql
ALTER TABLE attendance 
DROP COLUMN scanned_at,
ADD COLUMN check_in_time DATETIME NULL,
ADD COLUMN check_out_time DATETIME NULL,
ADD COLUMN notes TEXT NULL,
MODIFY COLUMN status ENUM('present','late','absent','left_early') NOT NULL DEFAULT 'present';
```

## API Endpoints

### Mark Attendance
- **POST** `/api/attendance/mark.php`
- **Behavior**: 
  - First call → Creates check-in record
  - Second call → Updates check-out time
  - Returns action type (`check_in` or `check_out`)

### List Attendance
- **GET** `/api/attendance/list_by_event.php?eventId={id}`
- **GET** `/api/attendance/list_recent.php?limit={number}`
- **Returns**: Both check-in and check-out times

## Flutter App Changes

### Models
- `Event`: Added `startTime` and `endTime` fields
- `Attendance`: Added `checkOutTime` and `notes` fields

### Screens
- **QR Scanner**: Shows check-in/check-out status
- **Event Details**: Displays attendance with time information
- **Create Event**: Separate start and end time pickers

### Providers
- **AttendanceProvider**: Handles dual actions and status updates
- **EventProvider**: Manages events with time ranges

## Usage Examples

### Creating an Event
```dart
await eventProvider.createEvent(
  title: 'Morning Lecture',
  description: 'Introduction to Flutter',
  startTime: DateTime(2024, 1, 15, 9, 0), // 9:00 AM
  endTime: DateTime(2024, 1, 15, 11, 0),  // 11:00 AM
  location: 'Room 101',
  createdBy: currentUser.id,
);
```

### Marking Attendance
```dart
final result = await attendanceProvider.markAttendance(
  eventId: event.id,
  studentId: student.id,
  studentName: student.name,
  qrCodeData: qrCode,
);

if (result != null) {
  final action = result['action']; // 'check_in' or 'check_out'
  final attendance = result['attendance'];
  // Handle the result
}
```

## Benefits

1. **Better Tracking**: Know exactly when students arrive and leave
2. **Duration Analysis**: Understand student engagement patterns
3. **Compliance**: Meet requirements for attendance duration tracking
4. **Flexibility**: Support for late arrivals and early departures
5. **Data Quality**: More accurate attendance records

## Migration Notes

### Existing Data
- Events without end times will need to be updated
- Existing attendance records will need to be migrated
- Consider setting default end times for old events

### Testing
- Test both check-in and check-out flows
- Verify status calculations (late, left early)
- Test edge cases (same time, invalid times)

## Future Enhancements

1. **Batch Operations**: Bulk check-in/check-out
2. **Notifications**: Alert when students leave early
3. **Analytics**: Attendance duration reports
4. **Integration**: Export to external systems
5. **Mobile App**: Student self-check-in/out

## Support

For questions or issues with the time in/time out feature, please refer to the API documentation or contact the development team. 