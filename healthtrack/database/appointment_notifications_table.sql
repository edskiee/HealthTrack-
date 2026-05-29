-- HealthTrack Database Schema Update
-- Add appointment_notifications table for real-time appointment updates
-- Run this script on your existing database to enable appointment notifications

USE healthtrack;

-- Create appointment_notifications table
CREATE TABLE IF NOT EXISTS appointment_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    user_id INT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_user_id (user_id),
    INDEX idx_notification_type (notification_type),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Show the updated schema
DESCRIBE appointment_notifications;

SELECT 'Appointment notifications table created successfully!' as message;