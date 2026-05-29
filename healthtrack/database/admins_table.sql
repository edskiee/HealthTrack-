-- HealthTrack Database Schema Update
-- Add admins table for admin authentication
-- Run this script on your existing database to enable admin profile functionality

USE healthtrack;

-- Create admins table (simplified version for backward compatibility)
CREATE TABLE IF NOT EXISTS admins (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    email VARCHAR(100),
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_username (username)
);

-- Insert default admin user if not exists
INSERT IGNORE INTO admins (username, password, full_name) 
VALUES (
    'admin', 
    'test',  -- Plain text password as used in your Flutter code
    'Administrator'
);

-- Show the updated schema
DESCRIBE admins;

SELECT 'Admins table created successfully!' as message;