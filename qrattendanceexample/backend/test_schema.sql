-- Test script for the updated database schema
-- Run this after updating your database with the new schema

USE qrattendance;

-- Check if the new columnrs exist
DESCRIBE events;
DESCRIBE attendance;

-- Insert a test event with start and end times
INSERT INTO events (title, description, start_time, end_time, location, created_by, created_at, is_active) 
VALUES (
    'Test Event - Time In/Out',
    'This is a test event to verify the time in/time out functionality',
    '2024-01-15 09:00:00',
    '2024-01-15 11:00:00',
    'Test Location',
    1,
    NOW(),
    1
);

-- Insert a test user if not exists
INSERT IGNORE INTO users (name, email, password_hash, student_id, role, created_at) 
VALUES (
    'Test Student',
    'test@example.com',
    'dummy_hash',
    'TEST001',
    'student',
    NOW()
);

-- Check the inserted data
SELECT * FROM events WHERE title LIKE '%Test Event%';
SELECT * FROM users WHERE email = 'test@example.com';

-- Test attendance marking (this would normally be done via the API)
-- First check-in
INSERT INTO attendance (user_id, event_id, check_in_time, status) 
VALUES (1, 1, '2024-01-15 09:05:00', 'late');

-- Then check-out
UPDATE attendance 
SET check_out_time = '2024-01-15 10:45:00', status = 'left_early' 
WHERE user_id = 1 AND event_id = 1;

-- View the attendance record
SELECT 
    a.id,
    u.name as student_name,
    e.title as event_title,
    a.check_in_time,
    a.check_out_time,
    a.status,
    a.notes
FROM attendance a
JOIN users u ON a.user_id = u.id
JOIN events e ON a.event_id = e.id
WHERE a.user_id = 1 AND a.event_id = 1; 