-- Migration script to update existing database to support time in/time out functionality
-- Run this script on your existing database before using the new features

USE qrattendance;

-- Step 1: Add end_time column to events table
-- If the column doesn't exist, add it with a default value
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS end_time DATETIME NULL AFTER start_time;

-- Step 2: Update existing events to have end times
-- Set end time to start time + 2 hours for existing events
UPDATE events 
SET end_time = DATE_ADD(start_time, INTERVAL 2 HOUR) 
WHERE end_time IS NULL;

-- Step 3: Make end_time NOT NULL after setting default values
ALTER TABLE events 
MODIFY COLUMN end_time DATETIME NOT NULL;

-- Step 4: Update attendance table structure
-- First, add new columns
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS check_in_time DATETIME NULL AFTER event_id,
ADD COLUMN IF NOT EXISTS check_out_time DATETIME NULL AFTER check_in_time,
ADD COLUMN IF NOT EXISTS notes TEXT NULL AFTER status;

-- Step 5: Migrate existing scanned_at data to check_in_time
UPDATE attendance 
SET check_in_time = scanned_at 
WHERE check_in_time IS NULL AND scanned_at IS NOT NULL;

-- Step 6: Update status enum to include new values
-- Note: This might require recreating the table in some MySQL versions
-- Alternative approach: Add new status values one by one
ALTER TABLE attendance 
MODIFY COLUMN status ENUM('present','late','absent','left_early') NOT NULL DEFAULT 'present';

-- Step 7: Remove old scanned_at column (after data migration)
-- ALTER TABLE attendance DROP COLUMN scanned_at;

-- Step 8: Add indexes for better performance
ALTER TABLE attendance 
ADD INDEX IF NOT EXISTS idx_check_in_time (check_in_time),
ADD INDEX IF NOT EXISTS idx_check_out_time (check_out_time),
ADD INDEX IF NOT EXISTS idx_user_id (user_id),
ADD INDEX IF NOT EXISTS idx_event_id (event_id);

-- Step 9: Verify the changes
DESCRIBE events;
DESCRIBE attendance;

-- Step 10: Show sample data to verify migration
SELECT 
    'Events Table' as table_name,
    COUNT(*) as total_records,
    COUNT(end_time) as events_with_end_time
FROM events
UNION ALL
SELECT 
    'Attendance Table' as table_name,
    COUNT(*) as total_records,
    COUNT(check_in_time) as records_with_check_in
FROM attendance;

-- Step 11: Show sample migrated data
SELECT 
    'Sample Event' as info,
    id,
    title,
    start_time,
    end_time
FROM events 
LIMIT 3;

SELECT 
    'Sample Attendance' as info,
    id,
    user_id,
    event_id,
    check_in_time,
    check_out_time,
    status
FROM attendance 
LIMIT 3;

-- Migration complete! Your database now supports time in/time out functionality.
-- You can now safely remove the scanned_at column if everything looks correct:
-- ALTER TABLE attendance DROP COLUMN scanned_at; 