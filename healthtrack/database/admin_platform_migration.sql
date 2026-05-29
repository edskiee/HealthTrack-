-- HealthTrack admin platform: sessions, preferences, audit, role
-- Run on MySQL 8.x healthtrack database

USE healthtrack;

-- Role and password-change tracking on admins (re-run skips if columns already exist)
ALTER TABLE admins
  ADD COLUMN role VARCHAR(64) NOT NULL DEFAULT 'Administrator';

ALTER TABLE admins
  ADD COLUMN password_changed_at TIMESTAMP NULL DEFAULT NULL;

-- Per-admin preferences & security flags
CREATE TABLE IF NOT EXISTS admin_preferences (
  admin_id INT NOT NULL PRIMARY KEY,
  theme_mode ENUM('light', 'dark', 'system') NOT NULL DEFAULT 'light',
  auto_logout_enabled TINYINT(1) NOT NULL DEFAULT 0,
  analytics_enabled TINYINT(1) NOT NULL DEFAULT 0,
  data_sharing_enabled TINYINT(1) NOT NULL DEFAULT 0,
  appointment_reminders_enabled TINYINT(1) NOT NULL DEFAULT 1,
  appointment_notify_email TINYINT(1) NOT NULL DEFAULT 1,
  appointment_notify_push TINYINT(1) NOT NULL DEFAULT 1,
  appointment_notify_sms TINYINT(1) NOT NULL DEFAULT 0,
  system_alerts_enabled TINYINT(1) NOT NULL DEFAULT 1,
  system_alert_email TINYINT(1) NOT NULL DEFAULT 1,
  system_alert_push TINYINT(1) NOT NULL DEFAULT 1,
  system_alert_sms TINYINT(1) NOT NULL DEFAULT 0,
  avatar_url VARCHAR(512) DEFAULT NULL,
  phone VARCHAR(32) DEFAULT NULL,
  totp_secret VARCHAR(128) DEFAULT NULL,
  totp_pending_secret VARCHAR(128) DEFAULT NULL,
  totp_enabled TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_prefs_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_sessions (
  id CHAR(36) NOT NULL PRIMARY KEY,
  admin_id INT NOT NULL,
  token_hash CHAR(64) NOT NULL,
  user_agent TEXT,
  ip_address VARCHAR(64) DEFAULT NULL,
  socket_client_id VARCHAR(128) DEFAULT NULL,
  device_label VARCHAR(128) DEFAULT NULL,
  browser_label VARCHAR(160) DEFAULT NULL,
  approximate_location VARCHAR(160) DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_sessions_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  UNIQUE KEY uq_admin_sessions_hash (token_hash),
  INDEX idx_admin_sessions_admin (admin_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  admin_id INT DEFAULT NULL,
  action VARCHAR(255) NOT NULL,
  ip_address VARCHAR(64) DEFAULT NULL,
  user_agent TEXT,
  metadata JSON DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE SET NULL,
  INDEX idx_audit_created (created_at DESC)
);

CREATE TABLE IF NOT EXISTS deployment_metadata (
  singleton_id TINYINT NOT NULL PRIMARY KEY DEFAULT 1,
  last_deployed_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO deployment_metadata (singleton_id, last_deployed_at) VALUES (1, CURRENT_TIMESTAMP);

