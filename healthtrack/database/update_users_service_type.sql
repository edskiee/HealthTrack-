-- HealthTrack Database Update Script
-- Add service_type column to users table
-- Run this script on your existing database to add the service_type column

USE healthtrack;

-- Add service_type column to users table
ALTER TABLE users 
ADD COLUMN service_type ENUM('immunization', 'maternal') DEFAULT 'immunization' AFTER allergies;

-- Update existing users to have a default service_type
UPDATE users 
SET service_type = 'immunization' 
WHERE service_type IS NULL;

-- Show the updated schema
DESCRIBE users;

-- Show current service types
SELECT service_type, COUNT(*) as count 
FROM users 
GROUP BY service_type 
ORDER BY service_type;

SELECT 'Database updated successfully! Users table now includes service_type column.' as message;