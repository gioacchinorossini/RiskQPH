# Course Field Migration

This document explains how to add the course field to the existing QR Attendance system.

## What's Added

A new `course` field has been added to the users table to store the student's course/program.

## Available Courses

The following courses are available in the dropdown:

- **BSA** - Bachelor of Science in Accountancy
- **BSAIS** - Bachelor of Science in Accounting Information System
- **BSBA-MM** - Bachelor of Science in Business Administration – Marketing Management
- **BSIT** - Bachelor of Science in Information Technology
- **BSTMG** - Bachelor of Science in Tourism Management
- **BSHM** - Bachelor of Science in Hospitality Management
- **BSPsych** - Bachelor of Science in Psychology
- **BEEd** - Bachelor of Elementary Education (General Education)
- **BSEd** - Bachelor of Secondary Education (English, Math, Filipino)
- **BCAEd** - Bachelor of Culture and Arts Education
- **BPEd** - Bachelor of Physical Education
- **TCP** - Teacher Certificate Program
- **BSCE** - Bachelor of Science in Civil Engineering
- **BSCHE** - Bachelor of Science in Chemical Engineering
- **BSME** - Bachelor of Science in Mechanical Engineering
- **BSN** - Bachelor of Science in Nursing
- **BSMT** - Bachelor of Science in Medical Technology
- **BSP** - Bachelor of Science in Pharmacy

## Database Migration

### Option 1: Run the Migration File

1. Open your MySQL database (e.g., through phpMyAdmin)
2. Navigate to the `qrattendance` database
3. Run the SQL from `backend/migrate_add_course.sql`:

```sql
USE qrattendance;

-- Add course column to users table
ALTER TABLE users ADD COLUMN course VARCHAR(100) NOT NULL DEFAULT 'BSIT' AFTER department;

-- Add index for course field for better query performance
CREATE INDEX idx_course ON users(course);
```

### Option 2: Manual SQL

If you prefer to run the SQL manually:

```sql
USE qrattendance;
ALTER TABLE users ADD COLUMN course VARCHAR(100) NOT NULL DEFAULT 'BSIT' AFTER department;
CREATE INDEX idx_course ON users(course);
```

## Files Modified

### Backend
- `backend/api/register.php` - Added course field handling
- `backend/schema.sql` - Updated schema to include course field
- `backend/migrate_add_course.sql` - Migration file

### Flutter App
- `lib/models/user.dart` - Added course field to User model
- `lib/providers/auth_provider.dart` - Updated register method to include course
- `lib/screens/auth/register_screen.dart` - Added course dropdown field

## Testing

After applying the migration:

1. **Test Registration**: Try registering a new user and verify the course field is saved
2. **Test Login**: Verify existing users can still log in (they'll have a default course value)
3. **Check Database**: Verify the course field appears in the users table

## Default Values

- Existing users will have a default course value of 'BSIT'
- New registrations will require selecting a course
- The course field is required and validated

## Rollback (if needed)

If you need to remove the course field:

```sql
USE qrattendance;
ALTER TABLE users DROP COLUMN course;
DROP INDEX idx_course ON users;
```

## Notes

- The course field is positioned after the department field in the form
- Course validation ensures a course is selected before registration
- The field is indexed for better query performance
- All existing functionality remains intact 