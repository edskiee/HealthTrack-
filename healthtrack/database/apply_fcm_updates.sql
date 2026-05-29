-- Apply FCM token column update to existing database
USE healthtrack;

-- Add FCM token column to users table for existing databases
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(500) NULL;

-- Add index for better performance when querying by FCM token
ALTER TABLE users ADD INDEX idx_fcm_token (fcm_token);

-- Verify the column was added
DESCRIBE users;