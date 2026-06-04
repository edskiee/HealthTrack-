-- HealthTrack MySQL Database Schema - Edwin Malunoc
-- HealthTrack MySQL Database Schema - Edwin Malunoc
-- PEDIATRIC HEALTHCARE SYSTEM
-- Based on actual Flutter app structure with pediatric patient fields
-- Use this script in MySQL Workbench to create the database

-- Create database
CREATE DATABASE IF NOT EXISTS healthtrack;
USE healthtrack;

-- Admin users table - Simple admin authentication
CREATE TABLE IF NOT EXISTS admin_users (
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
CREATE TABLE IF NOT EXISTS users (
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
    service_type ENUM('immunization', 'maternal') DEFAULT 'immunization',
    fcm_token VARCHAR(500) NULL,  -- Firebase Cloud Messaging token for push notifications
    last_login TIMESTAMP NULL,     -- Last login timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_username (username)
);

-- Patients table - PEDIATRIC PATIENT RECORDS (matches your Flutter app)
CREATE TABLE IF NOT EXISTS patients (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NULL,  -- Link to parent/guardian (nullable for initial data)
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
    
    -- MATERNAL CARE SPECIFIC FIELDS (newly added)
    lmp_date DATE NULL COMMENT 'Last Menstrual Period Date',
    edd_date DATE NULL COMMENT 'Expected Delivery Date',
    gestational_age_weeks INT NULL COMMENT 'Current Gestational Age in Weeks',
    gravida INT DEFAULT 1 COMMENT 'Number of pregnancies',
    para INT DEFAULT 0 COMMENT 'Number of births',
    abortus INT DEFAULT 0 COMMENT 'Number of abortions',
    stillbirth INT DEFAULT 0 COMMENT 'Number of stillbirths',
    blood_pressure VARCHAR(20) NULL COMMENT 'Blood pressure reading',
    weight DECIMAL(5,2) NULL COMMENT 'Current weight in kg',
    height DECIMAL(5,2) NULL COMMENT 'Height in cm',
    bmi DECIMAL(5,2) NULL COMMENT 'Body Mass Index',
    fundal_height DECIMAL(5,2) NULL COMMENT 'Fundal height in cm',
    fetal_heart_rate INT NULL COMMENT 'Fetal heart rate',
    
    -- RECORD INFORMATION FIELDS
    record_type ENUM('Diagnosis', 'Immunization', 'Consultation', 'Others', 'Maternal Care') DEFAULT 'Diagnosis',
    service_type ENUM('immunization', 'maternal') DEFAULT 'immunization',
    record_description TEXT,
    
    -- Maternal Care specific fields
    family_serial_number VARCHAR(50),
    contact_number VARCHAR(20),
    spouse_name VARCHAR(100),
    living_children_count INT DEFAULT 0,
    monthly_income DECIMAL(10,2),
    religion VARCHAR(50),
    city VARCHAR(100),
    province VARCHAR(100),
    age INT,
    education VARCHAR(100),
    occupation VARCHAR(100),
    birth_attendant ENUM('SBA', 'Non-SBA'),
    facility_type VARCHAR(100),
    
    -- Immunization specific fields
    health_center VARCHAR(100),
    barangay VARCHAR(100),
    family_number VARCHAR(50),
    
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
    INDEX idx_patient_id (patient_id),
    INDEX idx_service_type (service_type),
    INDEX idx_lmp_date (lmp_date),
    INDEX idx_edd_date (edd_date),
    INDEX idx_gestational_age (gestational_age_weeks)
);

-- Appointments table - Medical appointments
CREATE TABLE IF NOT EXISTS appointments (
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
CREATE TABLE IF NOT EXISTS health_records (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,  -- Links to users table
    patient_id INT,  -- Links to patients table (new field)
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_patient_id (patient_id),
    INDEX idx_record_type (record_type),
    INDEX idx_date_recorded (date_recorded),
    INDEX idx_updated_at (updated_at)
);

-- Appointment notifications table - For appointment-related notifications
CREATE TABLE IF NOT EXISTS appointment_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    user_id INT NOT NULL,
    notification_type ENUM('new_appointment', 'appointment_update', 'appointment_reminder', 'appointment_cancellation') NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at)
);

-- Health tips table - For dynamic health information
CREATE TABLE IF NOT EXISTS health_tips (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tip_category ENUM('maternal', 'pediatric', 'general') DEFAULT 'general',
    tip_text TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tip_category (tip_category),
    INDEX idx_is_active (is_active)
);

-- System settings table - For managing system-wide configurations
CREATE TABLE IF NOT EXISTS system_settings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_setting_key (setting_key),
    INDEX idx_is_active (is_active)
);

-- Insert default admin user (matches your Flutter admin login)
INSERT IGNORE INTO admin_users (username, password, full_name, role) 
VALUES (
    'admin', 
    'test',  -- Plain text password as used in your Flutter code
    'Administrator', 
    'super_admin'
);

-- Insert default system settings
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('app_name', 'HealthTrack System', 'string', 'Application name displayed in the admin panel'),
('maintenance_mode', 'false', 'boolean', 'Enable/disable maintenance mode for the system'),
('max_appointments_per_day', '50', 'number', 'Maximum number of appointments allowed per day'),
('appointment_reminders_enabled', 'true', 'boolean', 'Enable/disable appointment reminder notifications'),
('reminder_interval_hours', '24', 'number', 'Hours before appointment to send reminder'),
('enabled_notification_types', 'appointment,reminder,cancellation,system', 'string', 'Comma-separated list of enabled notification types'),
('data_retention_days', '365', 'number', 'Number of days to retain patient data'),
('default_service_type', 'immunization', 'string', 'Default service type for new patients'),
('notifications_enabled', 'true', 'boolean', 'Enable/disable all system notifications');

-- Insert sample pediatric patients (matches your Flutter app structure)
INSERT INTO patients (user_id, child_fullname, mother_fullname, father_fullname, dob, place_of_birth, birth_weight, birth_height, sex, address, status, record_type, service_type, record_description, health_center, barangay, family_number) VALUES
(NULL, 'Ana Santos', 'Maria Santos', 'Juan Santos', '2020-03-15', 'Quezon City', '3.1 kg', '50 cm', 'Female', 'Brgy. Commonwealth, QC', 'active', 'Diagnosis', 'maternal', 'Regular checkup', '', '', ''),
(NULL, 'Pedro Dela Cruz', 'Liza Dela Cruz', '', '2021-06-21', 'Manila', '3.3 kg', '49 cm', 'Male', 'Tondo, Manila', 'active', 'Immunization', 'immunization', 'Measles vaccination', 'Tondo Health Center', 'Tondo', 'FAM-001'),
(NULL, 'Miko Garcia', 'Ana Garcia', 'Jose Garcia', '2022-01-10', 'Cebu City', '2.9 kg', '48 cm', 'Male', 'Mabolo, Cebu', 'active', 'Consultation', 'maternal', 'Growth monitoring', '', '', ''),
(NULL, 'Lara Martinez', 'Carla Martinez', 'Pedro Martinez', '2019-09-05', 'Davao City', '3.4 kg', '51 cm', 'Female', 'Toril, Davao', 'active', 'Diagnosis', 'maternal', 'Routine checkup', '', '', ''),
(NULL, 'Kai Chen', 'Lisa Chen', 'Wei Chen', '2023-02-14', 'Pasig City', '3.0 kg', '49 cm', 'Male', 'Ortigas, Pasig', 'active', 'Immunization', 'immunization', 'DPT vaccination', 'Ortigas Health Center', 'Ortigas', 'FAM-002'),
(NULL, 'Ella Villanueva', 'Grace Villanueva', 'Oscar Villanueva', '2022-11-11', 'Taguig', '3.0 kg', '49 cm', 'Female', 'Taguig City', 'active', 'Consultation', 'maternal', 'Nutrition assessment', '', '', ''),
(NULL, 'Baby Malunoc', 'Maria Dela Cruz', 'Edwin A. Malunoc', '2020-01-01', 'Pagadian City', '3.2 kg', '50 cm', 'Male', 'Barangay Balangasan, Pagadian City', 'active', 'Diagnosis', 'maternal', 'Wellness checkup', 'Balangasan Health Center', 'Balangasan', 'FAM-003');

-- Insert sample appointments
INSERT INTO appointments (user_id, patient_id, appointment_date, appointment_time, appointment_type, doctor_name, clinic_hospital, status) VALUES
(1, 1, CURDATE() + INTERVAL 1 DAY, '10:00:00', 'Regular Check-up', 'Dr. Maria Lopez', 'QC General Hospital', 'pending'),
(2, 2, CURDATE() + INTERVAL 2 DAY, '11:00:00', 'Vaccination', 'Dr. Juan Reyes', 'Manila Health Center', 'approved'),
(3, 3, CURDATE() + INTERVAL 3 DAY, '14:00:00', 'Growth Monitoring', 'Dr. Ana Cruz', 'Cebu Pediatric Clinic', 'scheduled'),
(4, 4, CURDATE() + INTERVAL 4 DAY, '09:00:00', 'Prenatal Checkup', 'Dr. Edwin Malunoc', 'Balangasan Health Center', 'pending');

-- Insert sample users (parents/guardians)
INSERT INTO users (username, email, password, full_name, phone, date_of_birth, gender, address, emergency_contact, blood_type, service_type) VALUES
('john.doe', 'john.doe@email.com', 'password123', 'John Doe', '+1234567890', '1985-06-15', 'Male', '123 Main St, City', 'Jane Doe - +1234567891', 'O+', 'immunization'),
('jane.smith', 'jane.smith@email.com', 'password123', 'Jane Smith', '+1234567892', '1990-08-22', 'Female', '456 Oak Ave, Town', 'John Smith - +1234567893', 'A+', 'maternal'),
('edwin.malunoc', 'edwin.malunoc@email.com', 'password123', 'Edwin A. Malunoc', '+639123456789', '1985-01-01', 'Male', 'Barangay Balangasan, Pagadian City', 'Maria Dela Cruz - +639987654321', 'AB+', 'maternal');

-- Insert sample health records with diagnosis
INSERT INTO health_records (user_id, patient_id, record_type, title, description, diagnosis, record_values, unit, date_recorded, doctor_name, clinic_hospital) VALUES
(1, 1, 'Growth', 'Weight Measurement', 'Regular weight check', 'Normal Growth', '15.2', 'kg', CURDATE() - INTERVAL 7 DAY, 'Dr. Maria Lopez', 'QC General Hospital'),
(2, 2, 'Vaccination', 'Measles Vaccine', 'First dose of measles vaccine', 'Vaccination Completed', 'Completed', '', CURDATE() - INTERVAL 30 DAY, 'Dr. Juan Reyes', 'Manila Health Center'),
(3, 3, 'Growth', 'Weight Measurement', 'Monthly weight tracking', 'Normal Growth', '12.8', 'kg', CURDATE() - INTERVAL 14 DAY, 'Dr. Edwin Malunoc', 'Balangasan Health Center'),
(1, 1, 'Diagnosis', 'Fever Checkup', 'Baby has high temperature', 'Fever', '', '', CURDATE() - INTERVAL 5 DAY, 'Dr. Maria Lopez', 'QC General Hospital'),
(2, 2, 'Diagnosis', 'Respiratory Issue', 'Baby has cough and cold', 'Cough & Cold', '', '', CURDATE() - INTERVAL 10 DAY, 'Dr. Juan Reyes', 'Manila Health Center'),
(3, 3, 'Diagnosis', 'Nutrition Check', 'Baby shows signs of malnutrition', 'Malnutrition', '', '', CURDATE() - INTERVAL 15 DAY, 'Dr. Edwin Malunoc', 'Balangasan Health Center');

-- Insert sample health tips for maternal care
INSERT INTO health_tips (tip_category, tip_text, is_active) VALUES
('maternal', 'Drink plenty of water to stay hydrated during pregnancy', TRUE),
('maternal', 'Take prenatal vitamins as prescribed by your doctor', TRUE),
('maternal', 'Get regular exercise like walking or prenatal yoga', TRUE),
('maternal', 'Eat a balanced diet rich in fruits, vegetables, and whole grains', TRUE),
('maternal', 'Get adequate rest and sleep for at least 7-9 hours per night', TRUE),
('maternal', 'Attend all scheduled prenatal checkups with your healthcare provider', TRUE),
('maternal', 'Avoid alcohol, tobacco, and illicit drugs during pregnancy', TRUE),
('maternal', 'Practice stress-reducing activities like meditation or deep breathing', TRUE),
('maternal', 'Monitor your baby''s movements and report any significant changes to your doctor', TRUE),
('maternal', 'Prepare for childbirth by attending prenatal classes and creating a birth plan', TRUE);

-- Insert sample appointment notifications
INSERT INTO appointment_notifications (appointment_id, user_id, notification_type, message, is_read) VALUES
(1, 1, 'new_appointment', 'New appointment scheduled with Dr. Maria Lopez on ' + CURDATE() + INTERVAL 1 DAY + ' at 10:00 AM', FALSE),
(2, 2, 'appointment_update', 'Your appointment with Dr. Juan Reyes has been approved', FALSE);

-- Add foreign key constraints after data insertion
ALTER TABLE patients DROP FOREIGN KEY IF EXISTS fk_patients_user_id;
ALTER TABLE patients ADD CONSTRAINT fk_patients_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE appointments DROP FOREIGN KEY IF EXISTS fk_appointments_user_id;
ALTER TABLE appointments ADD CONSTRAINT fk_appointments_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE appointments DROP FOREIGN KEY IF EXISTS fk_appointments_patient_id;
ALTER TABLE appointments ADD CONSTRAINT fk_appointments_patient_id FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;
ALTER TABLE health_records DROP FOREIGN KEY IF EXISTS fk_health_records_user_id;
ALTER TABLE health_records ADD CONSTRAINT fk_health_records_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE health_records DROP FOREIGN KEY IF EXISTS fk_health_records_patient_id;
ALTER TABLE health_records ADD CONSTRAINT fk_health_records_patient_id FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;
ALTER TABLE appointment_notifications DROP FOREIGN KEY IF EXISTS fk_appointment_notifications_appointment_id;
ALTER TABLE appointment_notifications ADD CONSTRAINT fk_appointment_notifications_appointment_id FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE;
ALTER TABLE appointment_notifications DROP FOREIGN KEY IF EXISTS fk_appointment_notifications_user_id;
ALTER TABLE appointment_notifications ADD CONSTRAINT fk_appointment_notifications_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Show database information
SELECT 'Database created successfully!' as status;
SHOW TABLES;
SELECT COUNT(*) as total_patients FROM patients;
SELECT COUNT(*) as total_appointments FROM appointments;
SELECT COUNT(*) as total_health_records FROM health_records;
SELECT COUNT(*) as total_admin_users FROM admin_users;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_notifications FROM appointment_notifications;
SELECT COUNT(*) as total_health_tips FROM health_tips;