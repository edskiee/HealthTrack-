-- HealthTrack Database Schema Update
-- Add repeat_days column to reminders table
-- Run this script on your existing database to enable reminder repeat days functionality

USE healthtrack;

-- Add repeat_days column to reminders table
ALTER TABLE reminders 
ADD COLUMN repeat_days VARCHAR(255) NULL AFTER repeat_interval;

-- Show the updated schema
DESCRIBE reminders;

SELECT 'Reminders table updated with repeat_days column successfully!' as message;