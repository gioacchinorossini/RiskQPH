# Calendar of Events Feature

## Overview
The Calendar of Events feature provides a visual calendar interface for viewing and managing events in the QR Attendance App. This feature allows both administrators and students to view events in a monthly calendar format with easy navigation and event details.

## Features

### Calendar View
- **Modern Timeline Design**: Clean, minimalist interface with horizontal date picker
- **Horizontal Date Scroller**: Scrollable date picker showing days with event indicators
- **Date Selection**: Tap on any date to view events for that specific day
- **Timeline Layout**: Events displayed in a vertical timeline with visual connectors
- **Today Highlighting**: Current date is highlighted with a border
- **Event Indicators**: Small dots show which dates have events

### Event Information
- **Event Cards**: Each event displayed as a modern card with title, time, and description
- **Timeline Design**: Events arranged in a vertical timeline with visual connectors
- **Featured Event**: First event of the day is highlighted with dark background
- **Event Details**: Shows title, time, location, organizer, and attendee avatars
- **Quick Access**: Tap on any event to view full details
- **Bottom Navigation**: Modern navigation bar with home, list, add, notifications, and profile icons

### User Access
- **Admin Access**: Available through the "Calendar View" button in the Quick Actions section
- **Student Access**: Available through the calendar icon in the app bar

## How to Use

### For Administrators
1. Open the Admin Dashboard
2. Scroll down to the "Quick Actions" section
3. Tap on "Calendar View" card
4. Navigate through months using swipe gestures or navigation buttons
5. Tap on any date to view events for that day
6. Tap on any event to view detailed information

### For Students
1. Open the Student Dashboard
2. Tap the calendar icon in the top-right corner of the app bar
3. Navigate through months using swipe gestures or navigation buttons
4. Tap on any date to view events for that day
5. Tap on any event to view detailed information

## Technical Implementation

### Dependencies
- Custom implementation using Flutter's built-in widgets
- No external calendar dependencies required

### Files Added
- `lib/screens/common/calendar_events_screen.dart` - Main calendar screen implementation

### Navigation Integration
- Added to Admin Dashboard as a Quick Action card
- Added to Student Dashboard as an app bar action button

### Features
- **Responsive Design**: Works on all screen sizes
- **Error Handling**: Shows appropriate messages when events fail to load
- **Loading States**: Displays loading indicators during data fetching
- **Pull to Refresh**: Refresh events by pulling down on the calendar
- **Offline Support**: Uses cached events when network is unavailable

## Design Features
- **Modern Minimalist Design**: Clean, flat design with subtle shadows and rounded corners
- **Monochromatic Color Scheme**: Black, white, and grey color palette for professional appearance
- **Responsive Layout**: Adapts to different screen sizes and orientations
- **Smooth Animations**: Smooth scrolling and transitions for better user experience
- **Visual Hierarchy**: Clear distinction between selected dates, today, and regular dates

## Future Enhancements
- Add event creation directly from calendar view (admin only)
- Implement event filtering by status or organizer
- Add recurring event support
- Include attendance statistics in calendar view
- Add export functionality for calendar data 