-- ============================================================
-- Migration 003: Performance indexes for patients listing
-- Target: healthtrack-db (MySQL 8.4.8 on Aiven)
-- Uses a procedure to guard against duplicate index errors.
-- Safe to re-run: skips indexes that already exist.
-- ============================================================

DROP PROCEDURE IF EXISTS _add_index_if_missing;

DELIMITER $$

CREATE PROCEDURE _add_index_if_missing(
  IN tbl   VARCHAR(64),
  IN idx   VARCHAR(64),
  IN cols  VARCHAR(256)
)
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = tbl
       AND INDEX_NAME   = idx
  ) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD INDEX `', idx, '` (', cols, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('Created index ', idx, ' on ', tbl) AS status;
  ELSE
    SELECT CONCAT('Index ', idx, ' on ', tbl, ' already exists — skipped.') AS status;
  END IF;
END$$

DELIMITER ;

-- ── patients(service_type, created_at) ──────────────────────
-- Covers: WHERE service_type = ?  +  ORDER BY created_at DESC
-- Eliminates the full-table scan on every pagination COUNT(*)
-- (~1400 calls, max 43 ms each per Aiven query stats).
CALL _add_index_if_missing(
  'patients',
  'idx_patients_service_created',
  'service_type, created_at'
);

-- ── health_records(patient_id, created_at) ───────────────────
-- Covers: GROUP BY patient_id + MAX(created_at) in hr_agg / hr_last
-- derived tables used by the report endpoints.
CALL _add_index_if_missing(
  'health_records',
  'idx_health_records_patient_created',
  'patient_id, created_at'
);

-- ── appointments(patient_id, appointment_date) ───────────────
-- Covers: WHERE appointment_date >= CURDATE() GROUP BY patient_id
-- in the appt_next derived table used by all three report endpoints.
CALL _add_index_if_missing(
  'appointments',
  'idx_appointments_patient_date',
  'patient_id, appointment_date'
);

DROP PROCEDURE IF EXISTS _add_index_if_missing;
