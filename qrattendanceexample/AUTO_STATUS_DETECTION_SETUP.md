# Auto Status Detection Setup Guide

This guide explains how to set up and use the Auto Status Detection feature in the QR Attendance System.

## Overview

The Auto Status Detection feature automatically determines whether students are:
- **Late**: Arriving more than the configured grace period after an event starts
- **Left Early**: Leaving before an event ends

## Features

- **Toggle Switch**: Enable/disable auto status detection
- **Configurable Grace Period**: Set how many minutes after event start to allow before marking as late
- **Real-time Updates**: Immediate status updates or batch processing options
- **Emergency Disable**: Quickly turn off the feature if needed

## Setup Instructions

### 1. Database Setup

Run the SQL script to create the settings table:

```sql
-- Execute this in your MySQL database
source backend/settings.sql
```

This will create:
- `system_settings` table
- Default configuration values
- Required indexes

### 2. Backend Files

The following files have been created/modified:

- `backend/settings.sql` - Database schema
- `backend/api/settings.php` - Settings API endpoint
- `backend/api/attendance/mark.php` - Modified to respect settings

### 3. Frontend Files

- `admin/dashboard.html` - Added settings section
- `admin/styles.css` - Added toggle switch styles
- `admin/script.js` - Added settings management

## Usage

### Accessing Settings

1. Log into the admin dashboard
2. Click on "Settings" in the sidebar
3. Navigate to the "Attendance Settings" section

### Configuring Auto Status Detection

1. **Toggle the Switch**: Click the toggle to enable/disable the feature
2. **Set Grace Period**: Configure how many minutes after event start to allow before marking as late
3. **Choose Update Frequency**: Select how often status updates are processed
4. **Save Settings**: Click "Save Settings" to apply changes

### How It Works

#### When Enabled:
- **Late Detection**: Students scanning QR codes more than X minutes after event start are marked as "late"
- **Early Departure Detection**: Students checking out before event end are marked as "left early"

#### When Disabled:
- All students are marked as "present" regardless of timing
- No automatic status changes occur

### Settings Options

- **Auto Status Detection**: Master toggle for the feature
- **Late Arrival Grace Period**: Minutes allowed after event start (default: 15)
- **Status Update Frequency**: 
  - Real-time (immediate)
  - Batch (every 5 minutes)
  - Manual (admin approval required)

## API Endpoints

### Get Settings
```
GET /backend/api/settings.php
```

### Update Settings
```
POST /backend/api/settings.php
Content-Type: application/json

{
  "settings": {
    "auto_status_detection": true,
    "late_grace_period": 20,
    "update_frequency": "realtime"
  }
}
```

## Database Schema

```sql
CREATE TABLE system_settings (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(100) NOT NULL UNIQUE,
  setting_value TEXT NOT NULL,
  setting_type ENUM('boolean', 'integer', 'string', 'json') NOT NULL DEFAULT 'string',
  description TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## Troubleshooting

### Common Issues

1. **Settings not saving**: Check database connection and permissions
2. **Toggle not working**: Verify JavaScript console for errors
3. **Status not updating**: Ensure the feature is enabled in settings

### Debug Mode

Enable browser developer tools to see:
- API requests/responses
- JavaScript errors
- Network connectivity issues

## Security Considerations

- Settings are stored in the database, not in browser localStorage
- Admin authentication required to modify settings
- All API endpoints validate input data
- Database transactions ensure data integrity

## Future Enhancements

- **Audit Logging**: Track who changed what settings and when
- **Role-based Access**: Different permission levels for different settings
- **Bulk Operations**: Apply settings to multiple events at once
- **Scheduled Changes**: Automatically enable/disable features at specific times

## Support

For technical support or questions about this feature:
1. Check the browser console for error messages
2. Verify database connectivity
3. Review the API endpoint responses
4. Check the system logs for backend errors 