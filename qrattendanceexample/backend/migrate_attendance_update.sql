-- Migration script to add missing fields for attendance update functionality
USE qrattendance;

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

-- Update existing attendance records to populate student_name if it's NULL
UPDATE attendance a 
JOIN users u ON a.user_id = u.id 
SET a.student_name = u.name 
WHERE a.student_name IS NULL;

-- Add indexes for better performance
ALTER TABLE attendance 
ADD INDEX IF NOT EXISTS idx_status (status),
ADD INDEX IF NOT EXISTS idx_updated_at (updated_at); 