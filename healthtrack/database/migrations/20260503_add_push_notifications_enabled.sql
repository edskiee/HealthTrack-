-- Per-user server-side flag: when 0, backend must not call FCM for this user.
-- Backward compatible: existing rows default to enabled (1).
ALTER TABLE users
  ADD COLUMN push_notifications_enabled TINYINT(1) NOT NULL DEFAULT 1
  COMMENT '1=allow FCM, 0=user disabled push in app'
  AFTER fcm_token;
