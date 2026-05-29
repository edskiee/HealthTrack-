-- Referrals Table Schema
-- This table stores patient referrals with clinical notes and details

CREATE TABLE IF NOT EXISTS referrals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    referred_to VARCHAR(255) NOT NULL COMMENT 'Hospital/clinic/doctor name',
    referral_date DATE NOT NULL COMMENT 'Date of referral',
    referral_notes TEXT NOT NULL COMMENT 'Clinical notes and referral details',
    referring_admin_id INT COMMENT 'Admin who created the referral',
    status ENUM('pending', 'accepted', 'completed', 'cancelled') DEFAULT 'pending' COMMENT 'Referral status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
    FOREIGN KEY (referring_admin_id) REFERENCES admins(id) ON DELETE SET NULL,
    
    -- Indexes for performance
    INDEX idx_patient_id (patient_id),
    INDEX idx_referral_date (referral_date),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    
    -- Ensure data integrity
    CONSTRAINT chk_referral_notes_length CHECK (CHAR_LENGTH(referral_notes) >= 10),
    CONSTRAINT chk_referral_date_not_future CHECK (referral_date <= CURDATE() OR referral_date >= CURDATE())
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Patient referrals with clinical notes';

-- Sample data for testing (optional)
INSERT INTO referrals (patient_id, referred_to, referral_date, referral_notes, referring_admin_id, status) VALUES 
(1, 'City General Hospital - Cardiology Department', CURDATE(), 'Patient presents with persistent chest pain and shortness of breath. ECG shows abnormal rhythms. Recommend immediate cardiology consultation for further evaluation and possible stress test.', 1, 'pending'),
(1, 'St. Mary Medical Center - Pediatrics', CURDATE() - INTERVAL 1 DAY, 'Child showing signs of developmental delay. Recommend pediatric specialist evaluation for comprehensive assessment and early intervention planning.', 1, 'pending'),
(2, 'Regional Medical Center - Orthopedics', CURDATE() - INTERVAL 2 DAYS, 'Patient with chronic knee pain and limited mobility. X-ray shows early osteoarthritis. Recommend orthopedic consultation for treatment options and physical therapy referral.', 1, 'accepted');
