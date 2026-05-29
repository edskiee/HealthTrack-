-- Add timezone column to users table
-- This script fixes the "Unknown column 'u.timezone' in 'field list'" error

-- Add timezone column with default value 'Asia/Manila'
ALTER TABLE users 
ADD COLUMN timezone VARCHAR(50) DEFAULT 'Asia/Manila' 
AFTER fcm_token;

-- Add index for better performance on timezone queries
ALTER TABLE users 
ADD INDEX idx_timezone (timezone);

-- Update existing users to have the default timezone if they somehow have NULL values
UPDATE users 
SET timezone = 'Asia/Manila' 
WHERE timezone IS NULL;

-- Verify the column was added successfully
DESCRIBE users;

-- Show sample data to confirm
SELECT id, username, timezone FROM users LIMIT 5;
