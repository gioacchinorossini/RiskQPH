-- Migration: add updated_at column to events
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS updated_at DATETIME NULL;

-- Backfill existing rows
UPDATE events
SET updated_at = COALESCE(updated_at, created_at);

