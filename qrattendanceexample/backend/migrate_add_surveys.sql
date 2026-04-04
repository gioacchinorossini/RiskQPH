-- Surveys feature schema
-- Tables: surveys, survey_questions, survey_options, survey_responses, survey_answers

CREATE TABLE IF NOT EXISTS surveys (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_event_id (event_id)
);

CREATE TABLE IF NOT EXISTS survey_questions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  survey_id INT UNSIGNED NOT NULL,
  question_text TEXT NOT NULL,
  question_type ENUM('single_choice','multiple_choice','text') NOT NULL DEFAULT 'single_choice',
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX idx_survey_id (survey_id)
);

CREATE TABLE IF NOT EXISTS survey_options (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  question_id INT UNSIGNED NOT NULL,
  option_text VARCHAR(255) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX idx_question_id (question_id)
);

CREATE TABLE IF NOT EXISTS survey_responses (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  survey_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_survey_user (survey_id, user_id),
  INDEX idx_survey_id_user_id (survey_id, user_id)
);

CREATE TABLE IF NOT EXISTS survey_answers (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  response_id INT UNSIGNED NOT NULL,
  question_id INT UNSIGNED NOT NULL,
  option_id INT UNSIGNED NULL,
  answer_text TEXT NULL,
  INDEX idx_response_id (response_id),
  INDEX idx_question_id (question_id)
);

