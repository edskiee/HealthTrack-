-- HealthTrack Performance Optimization Indexes
-- Run this script once against your MySQL database to add performance indexes
-- for the 550+ patient records performance issue.

USE healthtrack;

-- 1. Composite index on patients(service_type, status)
--    Speeds up filtered list queries by service type and status.
ALTER TABLE patients
  ADD INDEX idx_patients_service_status (service_type, status);

-- 2. Index on patients(created_at)
--    Speeds up ORDER BY created_at DESC + pagination.
ALTER TABLE patients
  ADD INDEX idx_patients_created_at (created_at);

-- 3. Composite index on health_records(patient_id, created_at)
--    Speeds up per-patient record lookups ordered by date.
ALTER TABLE health_records
  ADD INDEX idx_health_records_patient_created (patient_id, created_at);

-- Optional: full-text index for faster LIKE searches on name columns.
-- Only add if your MySQL version supports FULLTEXT on InnoDB (5.6+).
-- ALTER TABLE patients ADD FULLTEXT INDEX ft_patient_names (child_fullname, mother_fullname, father_fullname);

SELECT 'Performance indexes created successfully.' AS status;
