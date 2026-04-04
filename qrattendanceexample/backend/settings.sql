-- Settings table for system configuration
USE qrattendance;

CREATE TABLE IF NOT EXISTS system_settings (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(100) NOT NULL UNIQUE,
  setting_value TEXT NOT NULL,
  setting_type ENUM('boolean', 'integer', 'string', 'json') NOT NULL DEFAULT 'string',
  description TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_setting_key (setting_key),
  INDEX idx_is_active (is_active)
);

-- Insert default settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('auto_status_detection', 'false', 'boolean', 'Enable automatic detection of late arrivals and early departures'),
('late_grace_period', '15', 'integer', 'Grace period in minutes after event start before marking as late'),
('update_frequency', 'realtime', 'string', 'How often status updates are processed (realtime, batch, manual)'),
('system_status', 'active', 'string', 'Overall system status (active, maintenance, disabled)'),
('last_settings_update', '', 'string', 'Timestamp of last settings update')
ON DUPLICATE KEY UPDATE
  setting_value = VALUES(setting_value),
  updated_at = CURRENT_TIMESTAMP; 