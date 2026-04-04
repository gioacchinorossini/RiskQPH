-- Migration: Add organizers table and organizer column on events

CREATE TABLE IF NOT EXISTS organizers (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL UNIQUE,
  description TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_name (name)
);

-- Add organizer column to events if not exists
ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer VARCHAR(200) NULL AFTER location;

