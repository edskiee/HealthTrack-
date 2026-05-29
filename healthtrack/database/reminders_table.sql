-- HealthTrack Database Schema Update
-- Add reminders table for user calendar reminders
-- Run this script on your existing database to enable reminder functionality

USE healthtrack;

-- Create reminders table
CREATE TABLE IF NOT EXISTS reminders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    reminder_date DATE NOT NULL,
    reminder_time TIME NULL,
    is_repeating BOOLEAN DEFAULT FALSE,
    repeat_interval ENUM('daily', 'weekly', 'monthly', 'yearly') NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_reminder_date (reminder_date),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Show the updated schema
DESCRIBE reminders;

SELECT 'Reminders table created successfully!' as message;