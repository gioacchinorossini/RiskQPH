-- Migration: Add optional audience targeting to events

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS target_department VARCHAR(100) NULL AFTER thumbnail,
  ADD COLUMN IF NOT EXISTS target_year_level VARCHAR(50) NULL AFTER target_department;

