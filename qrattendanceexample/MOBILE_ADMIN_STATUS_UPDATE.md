# Mobile Admin Status Update Feature

## Overview
This feature allows mobile admin users to manually update attendance statuses directly from the Flutter app's event details screen.

## Features
- **Status Toggle**: Edit button next to each attendance status
- **Status Selection**: Choose from Present, Late, Left Early, or Absent
- **Notes Field**: Optional notes for status changes
- **Real-time Updates**: Changes are immediately reflected in the UI
- **Audit Trail**: Status changes are logged in the database

## How to Use

### 1. Access the Feature
- Navigate to an event in the admin dashboard
- Tap on "Event Details" to open the detailed view
- Scroll down to see the attendance list

### 2. Edit Status
- Each attendance record has an edit button (pencil icon) next to the status
- Tap the edit button to open the status edit dialog
- Select the new status from the available options
- Add optional notes explaining the status change
- Tap "Update" to save changes

### 3. Available Statuses
- **Present**: Student attended the full event
- **Late**: Student arrived after the grace period
- **Left Early**: Student left before the event ended
- **Absent**: Student did not attend

## Technical Implementation

### Frontend (Flutter)
- **File**: `lib/screens/admin/event_details_screen.dart`
- **Methods**: 
  - `_showStatusEditDialog()`: Displays the edit dialog
  - `_buildStatusChip()`: Creates selectable status chips
- **UI Components**: Status chips, notes field, update button

### Backend (PHP)
- **API Endpoint**: `backend/api/attendance/update.php`
- **Method**: POST
- **Parameters**: 
  - `id`: Attendance record ID
  - `status`: New status value
  - `notes`: Optional notes

### Database
- **Table**: `attendance` (existing)
- **Fields Updated**: `status`, `notes`
- **Logging**: `attendance_log` table (optional)

## API Response Format

### Success Response
```json
{
  "success": true,
  "message": "Attendance status updated successfully",
  "attendance": {
    "id": "123",
    "eventId": "456",
    "studentId": "789",
    "studentName": "John Doe",
    "checkInTime": "2024-01-15 09:00:00",
    "checkOutTime": "2024-01-15 10:30:00",
    "status": "late",
    "notes": "Arrived 20 minutes late due to traffic"
  }
}
```

### Error Response
```json
{
  "error": "Attendance record not found"
}
```

## Database Migration

Run the following SQL to add required fields:

```sql
-- Add missing fields to attendance table
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS student_name VARCHAR(100) NULL AFTER user_id,
ADD COLUMN IF NOT EXISTS updated_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Create attendance_log table for tracking status changes
CREATE TABLE IF NOT EXISTS attendance_log (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  attendance_id INT UNSIGNED NOT NULL,
  old_status ENUM('present','late','absent','left_early') NOT NULL,
  new_status ENUM('present','late','absent','left_early') NOT NULL,
  notes TEXT NULL,
  changed_by VARCHAR(100) NOT NULL DEFAULT 'system',
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_attendance_id (attendance_id),
  INDEX idx_changed_at (changed_at),
  FOREIGN KEY (attendance_id) REFERENCES attendance(id) ON DELETE CASCADE
);
```

## Security Considerations

- **Authentication**: Ensure only admin users can access this feature
- **Validation**: Status values are validated against allowed enum values
- **Audit Trail**: All status changes are logged with user and timestamp
- **Input Sanitization**: Notes field is properly handled to prevent SQL injection

## Error Handling

- **Network Errors**: Graceful fallback with user-friendly error messages
- **Validation Errors**: Clear feedback for invalid status values
- **Database Errors**: Proper error logging and user notification
- **Loading States**: Visual feedback during API calls

## Future Enhancements

- **Bulk Updates**: Update multiple students at once
- **Status History**: View all status changes for a student
- **Approval Workflow**: Require approval for certain status changes
- **Notifications**: Alert relevant parties of status changes
- **Export**: Generate reports of status changes 