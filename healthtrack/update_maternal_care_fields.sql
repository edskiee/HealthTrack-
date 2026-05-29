-- Update script to add maternal care specific fields to the patients table

-- Add maternal care specific fields
ALTER TABLE patients 
ADD COLUMN family_serial_number VARCHAR(50) AFTER record_description,
ADD COLUMN contact_number VARCHAR(20) AFTER family_serial_number,
ADD COLUMN spouse_name VARCHAR(100) AFTER contact_number,
ADD COLUMN living_children_count INT DEFAULT 0 AFTER spouse_name,
ADD COLUMN monthly_income DECIMAL(10,2) AFTER living_children_count,
ADD COLUMN religion VARCHAR(50) AFTER monthly_income,
ADD COLUMN city VARCHAR(100) AFTER religion,
ADD COLUMN province VARCHAR(100) AFTER city,
ADD COLUMN age INT AFTER province,
ADD COLUMN education VARCHAR(100) AFTER age,
ADD COLUMN occupation VARCHAR(100) AFTER education,
ADD COLUMN birth_attendant ENUM('SBA', 'Non-SBA') AFTER occupation,
ADD COLUMN facility_type VARCHAR(100) AFTER birth_attendant;

-- Update the record_type enum to include 'Maternal Care'
ALTER TABLE patients 
MODIFY COLUMN record_type ENUM('Diagnosis', 'Immunization', 'Consultation', 'Others', 'Maternal Care') DEFAULT 'Diagnosis';

-- Show the updated table structure
DESCRIBE patients;