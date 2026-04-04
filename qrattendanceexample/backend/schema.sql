-- Database: qrattendance
CREATE DATABASE IF NOT EXISTS qrattendance CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE qrattendance;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  student_id VARCHAR(50) NOT NULL UNIQUE,
  year_level VARCHAR(50) NOT NULL,
  department VARCHAR(100) NOT NULL,
  course VARCHAR(100) NOT NULL,
  gender ENUM('male','female','other','prefer_not_to_say') NOT NULL,
  birthdate DATE NULL,
  role ENUM('student','admin') NOT NULL DEFAULT 'student',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_email (email),
  INDEX idx_student_id (student_id)
);

-- Events table (for later)
CREATE TABLE IF NOT EXISTS events (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  location VARCHAR(200) NULL,
  organizer VARCHAR(200) NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  thumbnail VARCHAR(255) NULL,
  -- Optional audience restrictions. NULL = open to all
  target_department VARCHAR(100) NULL,
  target_course VARCHAR(100) NULL,
  target_year_level VARCHAR(50) NULL,
  INDEX idx_start_time (start_time),
  INDEX idx_end_time (end_time)
);

-- Attendance table with time in/time out support
CREATE TABLE IF NOT EXISTS attendance (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  event_id INT UNSIGNED NOT NULL,
  check_in_time DATETIME NULL,
  check_out_time DATETIME NULL,
  status ENUM('present','late','absent','left_early') NOT NULL DEFAULT 'present',
  notes TEXT NULL,
  UNIQUE KEY uniq_user_event (user_id, event_id),
  INDEX idx_check_in_time (check_in_time),
  INDEX idx_check_out_time (check_out_time),
  INDEX idx_user_id (user_id),
  INDEX idx_event_id (event_id)
);

