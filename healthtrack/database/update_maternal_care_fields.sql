-- Update script to add maternal care specific fields to the patients table

-- Add maternal care specific fields to patients table
ALTER TABLE patients 
ADD COLUMN lmp_date DATE NULL COMMENT 'Last Menstrual Period Date' AFTER dob,
ADD COLUMN edd_date DATE NULL COMMENT 'Expected Delivery Date' AFTER lmp_date,
ADD COLUMN gestational_age_weeks INT NULL COMMENT 'Current Gestational Age in Weeks' AFTER edd_date,
ADD COLUMN gravida INT DEFAULT 1 COMMENT 'Number of pregnancies' AFTER gestational_age_weeks,
ADD COLUMN para INT DEFAULT 0 COMMENT 'Number of births' AFTER gravida,
ADD COLUMN abortus INT DEFAULT 0 COMMENT 'Number of abortions' AFTER para,
ADD COLUMN stillbirth INT DEFAULT 0 COMMENT 'Number of stillbirths' AFTER abortus,
ADD COLUMN blood_pressure VARCHAR(20) NULL COMMENT 'Blood pressure reading' AFTER stillbirth,
ADD COLUMN weight DECIMAL(5,2) NULL COMMENT 'Current weight in kg' AFTER blood_pressure,
ADD COLUMN height DECIMAL(5,2) NULL COMMENT 'Height in cm' AFTER weight,
ADD COLUMN bmi DECIMAL(5,2) NULL COMMENT 'Body Mass Index' AFTER height,
ADD COLUMN fundal_height DECIMAL(5,2) NULL COMMENT 'Fundal height in cm' AFTER bmi,
ADD COLUMN fetal_heart_rate INT NULL COMMENT 'Fetal heart rate' AFTER fundal_height;

-- Add indexes for the new maternal care fields
ALTER TABLE patients ADD INDEX idx_lmp_date (lmp_date);
ALTER TABLE patients ADD INDEX idx_edd_date (edd_date);
ALTER TABLE patients ADD INDEX idx_gestational_age (gestational_age_weeks);

-- Update existing maternal care patients with sample data
UPDATE patients 
SET 
    lmp_date = DATE_SUB(CURDATE(), INTERVAL 12 WEEK),
    edd_date = DATE_ADD(lmp_date, INTERVAL 280 DAY),
    gestational_age_weeks = 12,
    gravida = 1,
    para = 0,
    abortus = 0,
    stillbirth = 0,
    blood_pressure = '120/80',
    weight = 65.5,
    height = 165.0,
    bmi = 24.1,
    fundal_height = 15.0,
    fetal_heart_rate = 140
WHERE service_type = 'maternal' AND lmp_date IS NULL;

-- Create a table for health tips
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

-- Add service_type field to users table if it doesn't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS service_type ENUM('immunization', 'maternal') DEFAULT 'immunization' AFTER allergies;

-- Update existing users with service_type based on their patients
UPDATE users u
JOIN patients p ON u.id = p.user_id
SET u.service_type = 'maternal'
WHERE p.service_type = 'maternal' AND u.service_type = 'immunization';