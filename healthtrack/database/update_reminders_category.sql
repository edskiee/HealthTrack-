-- HealthTrack Database Schema Update
-- Add category column to reminders table
-- Run this script on your existing database to enable reminder category functionality

USE healthtrack;

-- Add category column to reminders table
ALTER TABLE reminders 
ADD COLUMN category VARCHAR(50) DEFAULT 'custom_reminder' AFTER title;

-- Add index for category column
ALTER TABLE reminders 
ADD INDEX idx_category (category);

-- Show the updated schema
DESCRIBE reminders;

SELECT 'Reminders table updated with category column successfully!' as message;