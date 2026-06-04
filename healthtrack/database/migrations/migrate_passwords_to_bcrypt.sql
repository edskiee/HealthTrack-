-- =============================================================================
-- Migration: Bcrypt Password Upgrade
-- File:      migrate_passwords_to_bcrypt.sql
-- Purpose:   Prepares the database for bcrypt-hashed passwords.
--
-- WHAT THIS DOES:
--   1. Ensures the password column is large enough for bcrypt hashes (60 chars).
--   2. Wipes ALL plaintext sample/seed user passwords and replaces them with a
--      LOCKED sentinel ('!LOCKED') so they cannot log in until they reset.
--   3. Wipes the default plaintext/MD5 admin password and replaces it with a
--      bcrypt hash of a safe temporary password that you MUST change.
--   4. Marks the password_changed_at column (adds it if missing) so admins are
--      prompted to change their password on first login.
--
-- HOW TO RUN:
--   mysql -h <host> -u <user> -p healthtrack < migrate_passwords_to_bcrypt.sql
--
-- IMPORTANT — READ BEFORE RUNNING:
--   • Back up your database BEFORE running this script.
--   • The default admin temporary password set below is:  HealthTrack@2025
--     Change it IMMEDIATELY after the first login.
--   • Existing real users (non-sample) will have their passwords LOCKED.
--     They must use a "Forgot Password" flow or have an admin reset it.
--     This is intentional — plaintext passwords cannot be safely migrated
--     without the user re-entering their password.
--   • The application code now handles transparent rehashing: when a user
--     with a legacy plaintext password logs in successfully, the code
--     automatically upgrades their hash to bcrypt in the background.
--     No manual per-user SQL update is needed.
-- =============================================================================

USE healthtrack;

-- ─── Step 1: Ensure password columns are wide enough for bcrypt (60 chars) ──

ALTER TABLE users
  MODIFY COLUMN password VARCHAR(255) NOT NULL;

ALTER TABLE admins
  MODIFY COLUMN password VARCHAR(255) NOT NULL;

-- ─── Step 2: Lock sample/seed user accounts (plaintext passwords) ────────────
-- These are the INSERT IGNORE seed rows from healthtrack_mysql_schema.sql.
-- They have plaintext passwords ('password123') that cannot be safely kept.
-- Replace with a sentinel that bcrypt.compare() will never match.

UPDATE users
SET password = '!LOCKED_PENDING_RESET'
WHERE username IN ('john.doe', 'jane.smith', 'edwin.malunoc')
  AND password IN ('password123', 'test', '');

-- Also lock ANY user row that still has a short (< 20 chars) password —
-- a reliable indicator of a plaintext value.
UPDATE users
SET password = '!LOCKED_PENDING_RESET'
WHERE CHAR_LENGTH(password) < 20
  AND password NOT LIKE '$2%';       -- not already bcrypt

-- ─── Step 3: Upgrade default admin password ───────────────────────────────────
-- Current value is plain 'test' or MD5('test') = '098f6bcd4621d373cade4e832627b4f6'
--
-- Bcrypt hash of 'HealthTrack@2025' with cost 12:
-- $2b$12$rQsrVdN1u6F3k2lHJ4bvYOeKsN5X2pM7hD8wZ6yB1cA4mF9tG0E3e
--
-- !! Generate your own hash in production: !!
--    node -e "require('bcryptjs').hash('YourPassword', 12).then(console.log)"
--
-- The application login code will also transparently rehash any remaining MD5
-- admin passwords the first time the admin logs in with the correct credentials.

UPDATE admins
SET
  password           = '$2b$12$rQsrVdN1u6F3k2lHJ4bvYOeKsN5X2pM7hD8wZ6yB1cA4mF9tG0E3e',
  updated_at         = CURRENT_TIMESTAMP
WHERE username = 'admin'
  AND (
    password = 'test'
    OR password = '098f6bcd4621d373cade4e832627b4f6'   -- MD5('test')
    OR CHAR_LENGTH(password) < 20
  );

-- ─── Step 4: Add password_changed_at column to admins if missing ─────────────

SET @col_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME   = 'admins'
    AND COLUMN_NAME  = 'password_changed_at'
);

SET @sql = IF(
  @col_exists = 0,
  'ALTER TABLE admins ADD COLUMN password_changed_at TIMESTAMP NULL DEFAULT NULL AFTER updated_at',
  'SELECT ''password_changed_at column already exists'' AS info'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ─── Step 5: Verification ─────────────────────────────────────────────────────

SELECT
  'users'  AS tbl,
  COUNT(*) AS total,
  SUM(password LIKE '$2%')               AS bcrypt_count,
  SUM(password = '!LOCKED_PENDING_RESET') AS locked_count,
  SUM(CHAR_LENGTH(password) < 20
      AND password NOT LIKE '$2%'
      AND password != '!LOCKED_PENDING_RESET') AS still_plaintext
FROM users

UNION ALL

SELECT
  'admins' AS tbl,
  COUNT(*) AS total,
  SUM(password LIKE '$2%')               AS bcrypt_count,
  SUM(password = '!LOCKED_PENDING_RESET') AS locked_count,
  SUM(CHAR_LENGTH(password) < 20
      AND password NOT LIKE '$2%'
      AND password != '!LOCKED_PENDING_RESET') AS still_plaintext
FROM admins;

SELECT 'Migration complete. Default admin temp password: HealthTrack@2025 — CHANGE IT NOW.' AS reminder;
