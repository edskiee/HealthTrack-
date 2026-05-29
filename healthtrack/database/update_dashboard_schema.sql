-- HealthTrack Database Update Script
-- Add service_type columns to users and patients tables for dashboard functionality
-- Run this script on your existing database to add the service_type columns

USE healthtrack;

-- Add service_type column to users table
ALTER TABLE users 
ADD COLUMN service_type ENUM('immunization', 'maternal') DEFAULT 'immunization' AFTER allergies;

-- Add service_type column to patients table
ALTER TABLE patients 
ADD COLUMN service_type ENUM('immunization', 'maternal') DEFAULT 'immunization' AFTER record_type;

-- Update existing users to have a default service_type
UPDATE users 
SET service_type = 'immunization' 
WHERE service_type IS NULL;

-- Update existing patients to have a default service_type based on record_type
UPDATE patients 
SET service_type = CASE 
    WHEN record_type = 'Immunization' THEN 'immunization'
    ELSE 'maternal'
END
WHERE service_type IS NULL;

-- Show the updated schema
DESCRIBE users;
DESCRIBE patients;

-- Show current service types
SELECT 'Users service types:' as message;
SELECT service_type, COUNT(*) as count 
FROM users 
GROUP BY service_type 
ORDER BY service_type;

SELECT 'Patients service types:' as message;
SELECT service_type, COUNT(*) as count 
FROM patients 
GROUP BY service_type 
ORDER BY service_type;

SELECT 'Database updated successfully! Users and Patients tables now include service_type columns.' as message;