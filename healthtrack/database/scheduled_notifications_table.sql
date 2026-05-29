-- HealthTrack Database Schema Update
-- Add scheduled_notifications table for FCM reminder notifications
-- Run this script on your existing database to enable scheduled notification functionality

USE healthtrack;

-- Create scheduled_notifications table
CREATE TABLE IF NOT EXISTS scheduled_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    fcm_token VARCHAR(500) NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    scheduled_time DATETIME NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE,
    sent_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_scheduled_time (scheduled_time),
    INDEX idx_is_sent (is_sent),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Show the updated schema
DESCRIBE scheduled_notifications;

SELECT 'Scheduled notifications table created successfully!' as message;