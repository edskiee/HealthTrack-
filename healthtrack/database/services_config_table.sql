-- HealthTrack Database Schema Update
-- Add services_config table for service configuration
-- Run this script on your existing database to enable service configuration functionality

USE healthtrack;

-- Create services_config table
CREATE TABLE IF NOT EXISTS services_config (
    id INT PRIMARY KEY AUTO_INCREMENT,
    service_name VARCHAR(100) NOT NULL UNIQUE,
    service_description TEXT,
    service_type ENUM('immunization', 'maternal', 'dental', 'epi', 'checkup', 'other') NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    required_fields JSON,
    available_days JSON,
    max_appointments_per_day INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_service_name (service_name),
    INDEX idx_service_type (service_type),
    INDEX idx_is_enabled (is_enabled),
    INDEX idx_created_at (created_at)
);

-- Insert default services
INSERT IGNORE INTO services_config (service_name, service_description, service_type, is_enabled, required_fields, available_days, max_appointments_per_day) VALUES
('Immunization', 'Child immunization and vaccination services', 'immunization', TRUE, 
 '["child_name", "vaccine_type", "date_of_birth", "parent_guardian"]', 
 '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]', 30),
('Maternal Care', 'Prenatal and postnatal care services for mothers', 'maternal', TRUE,
 '["mother_name", "expected_delivery_date", "contact_number", "address"]',
 '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]', 20),
('Dental Checkup', 'Pediatric dental examination and cleaning', 'dental', TRUE,
 '["child_name", "date_of_birth", "parent_guardian", "emergency_contact"]',
 '["Monday", "Wednesday", "Friday"]', 15),
('EPI Program', 'Expanded Program on Immunization services', 'epi', TRUE,
 '["child_name", "vaccine_type", "date_of_birth", "parent_guardian"]',
 '["Tuesday", "Thursday", "Saturday"]', 25),
('General Checkup', 'Routine pediatric health checkup', 'checkup', TRUE,
 '["child_name", "date_of_birth", "parent_guardian", "reason_for_visit"]',
 '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]', 40);

-- Show the updated schema
DESCRIBE services_config;

SELECT 'Services configuration table created successfully!' as message;