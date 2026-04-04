-- Migration: Add course field to users table
-- Run this SQL to add the course field

USE qrattendance;

-- Add course column to users table
ALTER TABLE users ADD COLUMN course VARCHAR(100) NOT NULL DEFAULT 'BSIT' AFTER department;

-- Update existing records with a default course (optional)
-- UPDATE users SET course = 'BSIT' WHERE course = '';

-- Add index for course field for better query performance
CREATE INDEX idx_course ON users(course); 