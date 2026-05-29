-- HealthTrack Database Schema Update
-- Add health_workers table for health worker schedule management
-- Run this script on your existing database to enable health worker schedule functionality

USE healthtrack;

-- Create health_workers table
CREATE TABLE IF NOT EXISTS health_workers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    worker_name VARCHAR(100) NOT NULL,
    role VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    assigned_services JSON,
    work_schedule JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_worker_name (worker_name),
    INDEX idx_role (role),
    INDEX idx_specialization (specialization),
    INDEX idx_is_active (is_active),
    INDEX idx_created_at (created_at)
);

-- Create health_worker_schedule table for detailed scheduling
CREATE TABLE IF NOT EXISTS health_worker_schedule (
    id INT PRIMARY KEY AUTO_INCREMENT,
    worker_id INT NOT NULL,
    service_id INT,
    day_of_week ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday') NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    max_appointments INT DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_worker_id (worker_id),
    INDEX idx_service_id (service_id),
    INDEX idx_day_of_week (day_of_week),
    INDEX idx_is_available (is_available),
    
    FOREIGN KEY (worker_id) REFERENCES health_workers(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services_config(id) ON DELETE SET NULL
);

-- Insert sample health workers
INSERT IGNORE INTO health_workers (worker_name, role, specialization, email, phone, is_active, assigned_services) VALUES
('Dr. Maria Santos', 'Pediatrician', 'Child Development', 'maria.santos@healthtrack.com', '+639123456789', TRUE, '[1, 5]'),
('Dr. Juan Dela Cruz', 'OB-GYN', 'Maternal Care', 'juan.delacruz@healthtrack.com', '+639123456790', TRUE, '[2]'),
('Dr. Ana Reyes', 'Dentist', 'Pediatric Dentistry', 'ana.reyes@healthtrack.com', '+639123456791', TRUE, '[3]'),
('Dr. Carlos Garcia', 'Nurse', 'Immunization', 'carlos.garcia@healthtrack.com', '+639123456792', TRUE, '[1, 4]');

-- Insert sample schedules
INSERT IGNORE INTO health_worker_schedule (worker_id, service_id, day_of_week, start_time, end_time, is_available, max_appointments) VALUES
(1, 1, 'Monday', '08:00:00', '12:00:00', TRUE, 8),
(1, 1, 'Tuesday', '08:00:00', '12:00:00', TRUE, 8),
(1, 5, 'Wednesday', '13:00:00', '17:00:00', TRUE, 10),
(1, 5, 'Thursday', '13:00:00', '17:00:00', TRUE, 10),
(2, 2, 'Monday', '09:00:00', '16:00:00', TRUE, 6),
(2, 2, 'Tuesday', '09:00:00', '16:00:00', TRUE, 6),
(3, 3, 'Wednesday', '08:00:00', '15:00:00', TRUE, 5),
(3, 3, 'Friday', '08:00:00', '15:00:00', TRUE, 5),
(4, 1, 'Monday', '13:00:00', '17:00:00', TRUE, 10),
(4, 4, 'Tuesday', '08:00:00', '12:00:00', TRUE, 8),
(4, 4, 'Thursday', '08:00:00', '12:00:00', TRUE, 8);

-- Show the updated schema
DESCRIBE health_workers;
DESCRIBE health_worker_schedule;

SELECT 'Health workers tables created successfully!' as message;