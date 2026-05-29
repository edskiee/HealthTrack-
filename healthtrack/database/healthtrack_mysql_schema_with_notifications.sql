-- HealthTrack MySQL Database Schema - Edwin Malunoc
-- HealthTrack MySQL Database Schema - Edwin Malunoc
-- PEDIATRIC HEALTHCARE SYSTEM
-- Based on actual Flutter app structure with pediatric patient fields
-- Use this script in MySQL Workbench to create the database

-- Create database
CREATE DATABASE IF NOT EXISTS healthtrack;
USE healthtrack;

-- Admin users table - Simple admin authentication
CREATE TABLE admin_users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('admin', 'super_admin') DEFAULT 'admin',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username)
);

-- Users table - Regular app users (parents/guardians)
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    gender ENUM('Male', 'Female', 'Other'),
    address TEXT,
    emergency_contact VARCHAR(200),
    blood_type VARCHAR(10),
    allergies TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_username (username)
);

-- Patients table - PEDIATRIC PATIENT RECORDS (matches your Flutter app)
CREATE TABLE patients (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,  -- Link to parent/guardian (required)
    patient_id VARCHAR(50),  -- For admin management system
    medical_record_number VARCHAR(100),  -- For admin system
    
    -- PEDIATRIC SPECIFIC FIELDS (matches your Flutter forms)
    child_fullname VARCHAR(100) NOT NULL,
    mother_fullname VARCHAR(100) NOT NULL,
    father_fullname VARCHAR(100),
    dob DATE NOT NULL,
    place_of_birth VARCHAR(200) NOT NULL, -- Made required
    birth_weight VARCHAR(20),  -- "3.1 kg" format
    birth_height VARCHAR(20),  -- "50 cm" format
    sex ENUM('Male', 'Female') NOT NULL,
    address TEXT NOT NULL, -- Made required
    
    -- RECORD INFORMATION FIELDS
    record_type ENUM('Diagnosis', 'Immunization', 'Consultation', 'Others') DEFAULT 'Diagnosis',
    record_description TEXT,
    
    -- Admin fields
    insurance_info TEXT,
    doctor_assigned VARCHAR(100),
    status ENUM('active', 'inactive') DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_child_name (child_fullname),
    INDEX idx_mother_name (mother_fullname),
    INDEX idx_date_of_birth (dob),
    INDEX idx_status (status),
    INDEX idx_patient_id (patient_id)
);

-- Appointments table - Medical appointments
CREATE TABLE appointments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,  -- For regular users
    patient_id INT,  -- For pediatric patients
    doctor_name VARCHAR(100) NOT NULL,
    clinic_hospital VARCHAR(200) NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    appointment_type VARCHAR(100) NOT NULL,
    status ENUM('pending', 'scheduled', 'approved', 'completed', 'cancelled', 'rescheduled', 'no_show') DEFAULT 'pending' NOT NULL,
    notes TEXT,
    reminder_set BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_patient_id (patient_id),
    INDEX idx_appointment_date (appointment_date),
    INDEX idx_status (status)
);

-- Health records table - Medical records
CREATE TABLE health_records (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,  -- Links to users table
    record_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    diagnosis VARCHAR(255),  -- Added diagnosis field for medical conditions
    record_values VARCHAR(100),  -- measurement values (renamed from 'values')
    unit VARCHAR(20),     -- kg, cm, etc.
    date_recorded DATE NOT NULL,
    doctor_name VARCHAR(100),
    clinic_hospital VARCHAR(200),
    attachments TEXT,  -- JSON or file paths
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_record_type (record_type),
    INDEX idx_date_recorded (date_recorded)
);

-- Notifications table - For admin and user notifications
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    appointment_id INT,
    notification_type ENUM('admin_appointment_notification', 'appointment_reminder', 'medication_reminder', 'follow_up_reminder', 'custom_message', 'system', 'status_update') NOT NULL,
    title VARCHAR(255),
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_notification_type (notification_type),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL
);

-- Insert default admin user (matches your Flutter admin login)
INSERT INTO admin_users (username, password, full_name, role) 
VALUES (
    'admin', 
    'test',  -- Plain text password as used in your Flutter code
    'Administrator', 
    'super_admin'
);

-- Insert sample pediatric patients (matches your Flutter app structure)
INSERT INTO patients (child_fullname, mother_fullname, father_fullname, dob, place_of_birth, birth_weight, birth_height, sex, address, status, record_type, record_description) VALUES
('Ana Santos', 'Maria Santos', 'Juan Santos', '2020-03-15', 'Quezon City', '3.1 kg', '50 cm', 'Female', 'Brgy. Commonwealth, QC', 'active', 'Diagnosis', 'Regular checkup'),
('Pedro Dela Cruz', 'Liza Dela Cruz', '', '2021-06-21', 'Manila', '3.3 kg', '49 cm', 'Male', 'Tondo, Manila', 'active', 'Immunization', 'Measles vaccination'),
('Miko Garcia', 'Ana Garcia', 'Jose Garcia', '2022-01-10', 'Cebu City', '2.9 kg', '48 cm', 'Male', 'Mabolo, Cebu', 'active', 'Consultation', 'Growth monitoring'),
('Lara Martinez', 'Carla Martinez', 'Pedro Martinez', '2019-09-05', 'Davao City', '3.4 kg', '51 cm', 'Female', 'Toril, Davao', 'active', 'Diagnosis', 'Routine checkup'),
('Kai Chen', 'Lisa Chen', 'Wei Chen', '2023-02-14', 'Pasig City', '3.0 kg', '49 cm', 'Male', 'Ortigas, Pasig', 'active', 'Immunization', 'DPT vaccination'),
('Ella Villanueva', 'Grace Villanueva', 'Oscar Villanueva', '2022-11-11', 'Taguig', '3.0 kg', '49 cm', 'Female', 'Taguig City', 'active', 'Consultation', 'Nutrition assessment'),
('Baby Malunoc', 'Maria Dela Cruz', 'Edwin A. Malunoc', '2020-01-01', 'Pagadian City', '3.2 kg', '50 cm', 'Male', 'Barangay Balangasan, Pagadian City', 'active', 'Diagnosis', 'Wellness checkup');

-- Insert sample appointments
INSERT INTO appointments (patient_id, appointment_date, appointment_time, appointment_type, doctor_name, clinic_hospital, status) VALUES
(1, CURDATE() + INTERVAL 1 DAY, '10:00:00', 'Regular Check-up', 'Dr. Maria Lopez', 'QC General Hospital', 'pending'),
(2, CURDATE() + INTERVAL 2 DAY, '11:00:00', 'Vaccination', 'Dr. Juan Reyes', 'Manila Health Center', 'approved'),
(3, CURDATE() + INTERVAL 3 DAY, '14:00:00', 'Growth Monitoring', 'Dr. Ana Cruz', 'Cebu Pediatric Clinic', 'scheduled'),
(7, CURDATE() + INTERVAL 4 DAY, '09:00:00', 'Prenatal Checkup', 'Dr. Edwin Malunoc', 'Balangasan Health Center', 'pending');

-- Insert sample users (parents/guardians)
INSERT INTO users (username, email, password, full_name, phone, date_of_birth, gender, address, emergency_contact, blood_type) VALUES
('john.doe', 'john.doe@email.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'John Doe', '+1234567890', '1985-06-15', 'Male', '123 Main St, City', 'Jane Doe - +1234567891', 'O+'),
('jane.smith', 'jane.smith@email.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Jane Smith', '+1234567892', '1990-08-22', 'Female', '456 Oak Ave, Town', 'John Smith - +1234567893', 'A+'),
('edwin.malunoc', 'edwin.malunoc@email.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Edwin A. Malunoc', '+639123456789', '1985-01-01', 'Male', 'Barangay Balangasan, Pagadian City', 'Maria Dela Cruz - +639987654321', 'AB+');

-- Insert sample health records with diagnosis
INSERT INTO health_records (user_id, record_type, title, description, diagnosis, record_values, unit, date_recorded, doctor_name, clinic_hospital) VALUES
(1, 'Growth', 'Weight Measurement', 'Regular weight check', 'Normal Growth', '15.2', 'kg', CURDATE() - INTERVAL 7 DAY, 'Dr. Maria Lopez', 'QC General Hospital'),
(1, 'Growth', 'Height Measurement', 'Regular height check', 'Normal Growth', '98', 'cm', CURDATE() - INTERVAL 7 DAY, 'Dr. Maria Lopez', 'QC General Hospital'),
(2, 'Vaccination', 'Measles Vaccine', 'First dose of measles vaccine', 'Vaccination Completed', 'Completed', '', CURDATE() - INTERVAL 30 DAY, 'Dr. Juan Reyes', 'Manila Health Center'),
(3, 'Growth', 'Weight Measurement', 'Monthly weight tracking', 'Normal Growth', '12.8', 'kg', CURDATE() - INTERVAL 14 DAY, 'Dr. Edwin Malunoc', 'Balangasan Health Center'),
(1, 'Diagnosis', 'Fever Checkup', 'Baby has high temperature', 'Fever', '', '', CURDATE() - INTERVAL 5 DAY, 'Dr. Maria Lopez', 'QC General Hospital'),
(2, 'Diagnosis', 'Respiratory Issue', 'Baby has cough and cold', 'Cough & Cold', '', '', CURDATE() - INTERVAL 10 DAY, 'Dr. Juan Reyes', 'Manila Health Center'),
(3, 'Diagnosis', 'Nutrition Check', 'Baby shows signs of malnutrition', 'Malnutrition', '', '', CURDATE() - INTERVAL 15 DAY, 'Dr. Edwin Malunoc', 'Balangasan Health Center');

-- Insert sample notifications
INSERT INTO notifications (user_id, notification_type, title, message, is_read) VALUES
(1, 'appointment_reminder', 'Appointment Reminder', 'Your appointment with Dr. Maria Lopez is tomorrow at 10:00 AM.', FALSE),
(2, 'medication_reminder', 'Medication Reminder', 'Time to give your child the prescribed medication.', FALSE),
(3, 'follow_up_reminder', 'Follow-up Reminder', 'Your follow-up appointment is scheduled for next week.', FALSE);

-- Add foreign key constraints after data insertion
ALTER TABLE patients DROP FOREIGN KEY IF EXISTS fk_patients_user_id; -- Drop if exists to recreate
ALTER TABLE patients ADD CONSTRAINT fk_patients_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE; -- Changed from SET NULL to CASCADE
ALTER TABLE appointments ADD CONSTRAINT fk_appointments_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE appointments ADD CONSTRAINT fk_appointments_patient_id FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;
ALTER TABLE health_records ADD CONSTRAINT fk_health_records_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Show database information
SELECT 'Database created successfully!' as status;
SHOW TABLES;
SELECT COUNT(*) as total_patients FROM patients;
SELECT COUNT(*) as total_appointments FROM appointments;
SELECT COUNT(*) as total_health_records FROM health_records;
SELECT COUNT(*) as total_admin_users FROM admin_users;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_notifications FROM notifications;