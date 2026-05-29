-- HealthTrack Database Schema Update
-- Add appointment_slots table for managing appointment availability
-- Run this script on your existing database to enable appointment slot functionality

USE healthtrack;

-- Create appointment_slots table
CREATE TABLE IF NOT EXISTS appointment_slots (
    id INT PRIMARY KEY AUTO_INCREMENT,
    service_id INT NOT NULL,
    appointment_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_duration_minutes INT DEFAULT 30,
    max_patients INT DEFAULT 10,
    booked_patients INT DEFAULT 0,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_service_id (service_id),
    INDEX idx_appointment_date (appointment_date),
    INDEX idx_is_available (is_available),
    INDEX idx_service_date (service_id, appointment_date),
    
    FOREIGN KEY (service_id) REFERENCES services_config(id) ON DELETE CASCADE
);

-- Create index for efficient querying of available slots
CREATE INDEX idx_available_slots ON appointment_slots(service_id, appointment_date, is_available);

-- Sample data for testing
-- Note: This assumes you have services with IDs 1 and 2 for Immunization and Maternal Care
INSERT IGNORE INTO appointment_slots (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, booked_patients) VALUES
(1, CURDATE() + INTERVAL 1 DAY, '09:00:00', '12:00:00', 30, 10, 0),
(1, CURDATE() + INTERVAL 1 DAY, '13:00:00', '17:00:00', 30, 10, 0),
(2, CURDATE() + INTERVAL 1 DAY, '08:00:00', '12:00:00', 30, 5, 0),
(2, CURDATE() + INTERVAL 1 DAY, '13:00:00', '16:00:00', 30, 5, 0);

-- Show the updated schema
DESCRIBE appointment_slots;

SELECT 'Appointment slots table created successfully!' as message;