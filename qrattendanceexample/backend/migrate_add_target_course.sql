-- Migration: Add target_course to events
USE qrattendance;

ALTER TABLE events
  ADD COLUMN target_course VARCHAR(100) NULL AFTER target_department;

CREATE INDEX idx_target_course ON events(target_course);