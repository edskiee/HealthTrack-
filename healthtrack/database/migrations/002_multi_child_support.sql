-- =============================================================================
-- Migration 002: Multi-Child Per Parent Account Support
-- Compatible with MySQL 5.7+ (Aiven)
-- =============================================================================

-- ─── 1. Add child_sort_order column if missing ───────────────────────────────
SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME   = 'patients'
    AND COLUMN_NAME  = 'child_sort_order'
);

SET @sql = IF(
  @col_exists = 0,
  'ALTER TABLE patients ADD COLUMN child_sort_order INT NOT NULL DEFAULT 0 AFTER user_id',
  'SELECT ''child_sort_order already exists'' AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ─── 2. dob_needs_verification guard (idempotent) ────────────────────────────
SET @col2_exists = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME   = 'patients'
    AND COLUMN_NAME  = 'dob_needs_verification'
);

SET @sql2 = IF(
  @col2_exists = 0,
  'ALTER TABLE patients ADD COLUMN dob_needs_verification TINYINT(1) NOT NULL DEFAULT 0 AFTER dob',
  'SELECT ''dob_needs_verification already exists'' AS info'
);
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

-- ─── 3. Drop unique index on user_id if one exists ───────────────────────────
DROP PROCEDURE IF EXISTS _drop_unique_user_id;

CREATE PROCEDURE _drop_unique_user_id()
BEGIN
  DECLARE idx_name VARCHAR(255) DEFAULT NULL;
  SELECT INDEX_NAME INTO idx_name
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME   = 'patients'
    AND INDEX_NAME  != 'PRIMARY'
    AND NON_UNIQUE   = 0
    AND COLUMN_NAME  = 'user_id'
    AND SEQ_IN_INDEX = 1
  LIMIT 1;

  IF idx_name IS NOT NULL THEN
    SET @drop_sql = CONCAT('ALTER TABLE patients DROP INDEX `', idx_name, '`');
    PREPARE d FROM @drop_sql; EXECUTE d; DEALLOCATE PREPARE d;
    SELECT CONCAT('Dropped unique index: ', idx_name) AS info;
  ELSE
    SELECT 'No unique index on patients.user_id - nothing to drop' AS info;
  END IF;
END;

CALL _drop_unique_user_id();
DROP PROCEDURE IF EXISTS _drop_unique_user_id;

-- ─── 4. Add composite index (drop old one first via procedure) ───────────────
DROP PROCEDURE IF EXISTS _add_child_index;

CREATE PROCEDURE _add_child_index()
BEGIN
  DECLARE idx_exists INT DEFAULT 0;
  SELECT COUNT(*) INTO idx_exists
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME   = 'patients'
    AND INDEX_NAME   = 'idx_patients_user_child_order';

  IF idx_exists > 0 THEN
    ALTER TABLE patients DROP INDEX idx_patients_user_child_order;
  END IF;

  ALTER TABLE patients ADD INDEX idx_patients_user_child_order (user_id, child_sort_order);
  SELECT 'Index idx_patients_user_child_order created' AS info;
END;

CALL _add_child_index();
DROP PROCEDURE IF EXISTS _add_child_index;

-- ─── 5. Seed child_sort_order = 0 for all existing rows ─────────────────────
UPDATE patients SET child_sort_order = 0 WHERE child_sort_order IS NULL OR child_sort_order = 0;

-- ─── Verify ──────────────────────────────────────────────────────────────────
SELECT 'Migration 002 complete' AS status;
SELECT
  COUNT(*)                                        AS total_patients,
  COUNT(DISTINCT user_id)                         AS unique_parents,
  SUM(CASE WHEN child_sort_order = 0 THEN 1 END) AS first_children,
  SUM(CASE WHEN child_sort_order > 0 THEN 1 END) AS additional_children
FROM patients;
