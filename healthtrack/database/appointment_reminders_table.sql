-- Create appointment_reminders table for enhanced reminder scheduling
-- This table stores scheduled reminder notifications for appointments

CREATE TABLE IF NOT EXISTS appointment_reminders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    user_id INT NOT NULL,
    reminder_date DATE NOT NULL,
    reminder_time TIME NOT NULL,
    scheduled_datetime DATETIME NOT NULL,
    days_before INT NOT NULL,
    reminder_type VARCHAR(50) NOT NULL,
    status ENUM('scheduled', 'sent', 'failed', 'cancelled') DEFAULT 'scheduled',
    sent_at TIMESTAMP NULL,
    error_message TEXT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_user_id (user_id),
    INDEX idx_scheduled_datetime (scheduled_datetime),
    INDEX idx_status (status),
    INDEX idx_reminder_date (reminder_date),
    UNIQUE KEY unique_reminder (appointment_id, reminder_date, reminder_time, reminder_type)
);

-- Create notification_history table for tracking all sent notifications
CREATE TABLE IF NOT EXISTS notification_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    payload JSON,
    status ENUM('sent', 'failed') NOT NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_notification_type (notification_type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Add foreign key constraints
ALTER TABLE appointment_reminders 
ADD CONSTRAINT fk_appointment_reminders_appointment_id 
FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE;

ALTER TABLE appointment_reminders 
ADD CONSTRAINT fk_appointment_reminders_user_id 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE notification_history 
ADD CONSTRAINT fk_notification_history_user_id 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
