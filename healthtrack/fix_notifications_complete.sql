-- Complete fix for notifications table - ensures all columns match the schema
-- This script adds all missing columns and ensures the table structure is correct

USE healthtrack;

-- Check and fix notifications table structure
SET @sql = '';

-- Check if title column exists
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists 
FROM information_schema.columns 
WHERE table_schema = 'healthtrack' 
  AND table_name = 'notifications' 
  AND column_name = 'title';

-- Add title column if missing
IF @col_exists = 0 THEN
  SET @sql = CONCAT(@sql, 'ALTER TABLE notifications ADD COLUMN title VARCHAR(255) AFTER notification_type; ');
END IF;

-- Check if updated_at column exists
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists 
FROM information_schema.columns 
WHERE table_schema = 'healthtrack' 
  AND table_name = 'notifications' 
  AND column_name = 'updated_at';

-- Add updated_at column if missing
IF @col_exists = 0 THEN
  SET @sql = CONCAT(@sql, 'ALTER TABLE notifications ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at; ');
END IF;

-- Check if read_at column exists
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists 
FROM information_schema.columns 
WHERE table_schema = 'healthtrack' 
  AND table_name = 'notifications' 
  AND column_name = 'read_at';

-- Add read_at column if missing
IF @col_exists = 0 THEN
  SET @sql = CONCAT(@sql, 'ALTER TABLE notifications ADD COLUMN read_at TIMESTAMP NULL AFTER is_read; ');
END IF;

-- Check if appointment_id column exists
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists 
FROM information_schema.columns 
WHERE table_schema = 'healthtrack' 
  AND table_name = 'notifications' 
  AND column_name = 'appointment_id';

-- Add appointment_id column if missing
IF @col_exists = 0 THEN
  SET @sql = CONCAT(@sql, 'ALTER TABLE notifications ADD COLUMN appointment_id INT AFTER user_id; ');
END IF;

-- Execute all ALTER statements if any columns are missing
IF @sql != '' THEN
  SET @sql = TRIM(TRAILING '; ' FROM @sql);
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  
  SELECT 'Missing columns have been added to notifications table' as message;
ELSE
  SELECT 'All required columns already exist in notifications table' as message;
END IF;

-- Update existing notifications with appropriate titles based on their type
UPDATE notifications 
SET title = CASE 
  WHEN notification_type = 'appointment_reminder' THEN 'Appointment Reminder'
  WHEN notification_type = 'medication_reminder' THEN 'Medication Reminder'
  WHEN notification_type = 'follow_up_reminder' THEN 'Follow-up Reminder'
  WHEN notification_type = 'custom_message' THEN 'Custom Message'
  WHEN notification_type = 'system' THEN 'System Notification'
  WHEN notification_type = 'admin_appointment_notification' THEN 'New Appointment Request'
  WHEN notification_type = 'status_update' THEN 'Status Update'
  ELSE 'Notification'
END
WHERE title IS NULL OR title = '';

-- Insert test notifications for the companador user if they don't exist
-- First, check if companador user exists
SET @user_id = 0;
SELECT id INTO @user_id FROM users WHERE username = 'companador' LIMIT 1;

IF @user_id > 0 THEN
  -- Check if companador already has notifications
  SET @notification_count = 0;
  SELECT COUNT(*) INTO @notification_count FROM notifications WHERE user_id = @user_id;
  
  -- Insert test notifications if none exist
  IF @notification_count = 0 THEN
    INSERT INTO notifications (user_id, notification_type, title, message, is_read, created_at) VALUES
    (@user_id, 'system', 'Welcome to HealthTrack', 'Welcome to HealthTrack! Your account has been set up successfully.', FALSE, NOW()),
    (@user_id, 'appointment_reminder', 'Appointment Reminder', 'You have an upcoming appointment scheduled. Please arrive 15 minutes early.', FALSE, NOW() - INTERVAL 1 HOUR),
    (@user_id, 'medication_reminder', 'Medication Reminder', 'Don''t forget to take your prescribed medication as scheduled.', FALSE, NOW() - INTERVAL 2 HOUR),
    (@user_id, 'custom_message', 'Custom Message', 'This is a test notification to verify the system is working correctly.', TRUE, NOW() - INTERVAL 3 HOUR);
    
    SELECT CONCAT('Inserted ', ROW_COUNT(), ' test notifications for companador user (ID: ', @user_id, ')') as message;
  ELSE
    SELECT CONCAT('companador user (ID: ', @user_id, ') already has ', @notification_count, ' notifications') as message;
  END IF;
ELSE
  SELECT 'companador user not found in database' as message;
END IF;

-- Show the updated notifications table structure
DESCRIBE notifications;

-- Show sample data to verify the fix
SELECT 'Sample notifications data:' as info;
SELECT id, user_id, notification_type, title, message, is_read, created_at, updated_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;
