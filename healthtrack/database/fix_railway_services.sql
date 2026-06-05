-- =============================================================================
-- HealthTrack — Railway Database Fix Script
-- Run this in Railway Dashboard → MySQL → Query tab
-- =============================================================================
-- Purpose: Restore missing Immunization and Maternal Care service records
--          and fix the services_config table schema.
--
-- This script is IDEMPOTENT — safe to run multiple times.
-- =============================================================================

USE railway;

-- ─── Step 1: Add missing columns to services_config ──────────────────────────
-- Add is_enabled column if it does not exist (some deployments only have is_active)
SET @col_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'services_config'
    AND COLUMN_NAME = 'is_enabled'
);

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE services_config ADD COLUMN is_enabled TINYINT(1) NOT NULL DEFAULT 1',
  'SELECT "is_enabled column already exists" AS info'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add service_description column if missing (renamed from description in some versions)
SET @col_exists2 = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'services_config'
    AND COLUMN_NAME = 'service_description'
);

SET @sql2 = IF(@col_exists2 = 0,
  'ALTER TABLE services_config ADD COLUMN service_description TEXT NULL',
  'SELECT "service_description column already exists" AS info'
);
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

-- Add required_fields column if missing
SET @col_exists3 = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'services_config'
    AND COLUMN_NAME = 'required_fields'
);

SET @sql3 = IF(@col_exists3 = 0,
  'ALTER TABLE services_config ADD COLUMN required_fields JSON NULL',
  'SELECT "required_fields column already exists" AS info'
);
PREPARE stmt3 FROM @sql3;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;

-- Add available_days column if missing
SET @col_exists4 = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'services_config'
    AND COLUMN_NAME = 'available_days'
);

SET @sql4 = IF(@col_exists4 = 0,
  'ALTER TABLE services_config ADD COLUMN available_days JSON NULL',
  'SELECT "available_days column already exists" AS info'
);
PREPARE stmt4 FROM @sql4;
EXECUTE stmt4;
DEALLOCATE PREPARE stmt4;

-- Add max_appointments_per_day column if missing
SET @col_exists5 = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'services_config'
    AND COLUMN_NAME = 'max_appointments_per_day'
);

SET @sql5 = IF(@col_exists5 = 0,
  'ALTER TABLE services_config ADD COLUMN max_appointments_per_day INT NOT NULL DEFAULT 50',
  'SELECT "max_appointments_per_day column already exists" AS info'
);
PREPARE stmt5 FROM @sql5;
EXECUTE stmt5;
DEALLOCATE PREPARE stmt5;

-- ─── Step 2: Fix ENUM to include all needed service_type values ────────────────
-- Only run this if the ENUM does not already have the needed values.
-- This ALTER safely expands the ENUM without data loss.
ALTER TABLE services_config
  MODIFY COLUMN service_type
    ENUM('immunization','maternal','dental','epi','checkup','general','other')
    NOT NULL DEFAULT 'general';

-- ─── Step 3: Sync is_enabled = is_active for any existing rows ────────────────
UPDATE services_config SET is_enabled = is_active;

-- ─── Step 4: Insert the two required services ─────────────────────────────────
-- INSERT IGNORE skips the row if service_name already exists (UNIQUE constraint)
INSERT IGNORE INTO services_config
    (service_name, service_description, service_type, is_active, is_enabled,
     duration_minutes, required_fields, available_days, max_appointments_per_day)
VALUES
(
    'Immunization',
    'Child immunization and vaccination services',
    'immunization', 1, 1, 30,
    '["child_name", "vaccine_type", "date_of_birth", "parent_guardian"]',
    '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
    30
),
(
    'Maternal Care',
    'Prenatal and postnatal care services for mothers',
    'maternal', 1, 1, 30,
    '["mother_name", "expected_delivery_date", "contact_number", "address"]',
    '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
    20
);

-- ─── Step 5: Verify the results ───────────────────────────────────────────────
SELECT
    id,
    service_name,
    service_type,
    is_active,
    is_enabled,
    duration_minutes,
    max_appointments_per_day
FROM services_config
ORDER BY id;

SELECT
    CONCAT('Total services: ', COUNT(*)) AS summary,
    CONCAT('Active+Enabled: ',
           SUM(CASE WHEN is_active = 1 AND is_enabled = 1 THEN 1 ELSE 0 END)) AS active_enabled
FROM services_config;

SELECT 'Fix script completed successfully!' AS status;
