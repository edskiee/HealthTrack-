-- =============================================================================
-- HealthTrack MySQL Schema — Railway Deployment
-- =============================================================================
-- HOW TO RUN:
--   In Railway dashboard → your MySQL service → Query tab, paste and run.
--   OR use a client: mysql -h <host> -P <port> -u root -p railway < railway_schema.sql
--
-- NOTES:
--   • Railway's default database name is "railway" — keep USE railway below.
--   • Set DB_NAME=railway in Render environment variables.
--   • The 'admins' table is used by the Node.js backend (NOT admin_users).
--   • The default admin password below is a bcrypt hash of: HealthTrack@2025
--     Change it immediately after first login.
-- =============================================================================

USE railway;

-- ─── Users (patients / app users) ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id                        INT          PRIMARY KEY AUTO_INCREMENT,
    username                  VARCHAR(50)  UNIQUE NOT NULL,
    email                     VARCHAR(100) UNIQUE NOT NULL,
    password                  VARCHAR(255) NOT NULL,        -- bcrypt hash
    full_name                 VARCHAR(100) NOT NULL,
    phone                     VARCHAR(20),
    date_of_birth             DATE,
    gender                    ENUM('Male','Female','Other'),
    address                   TEXT,
    emergency_contact         VARCHAR(200),
    blood_type                VARCHAR(10),
    allergies                 TEXT,
    service_type              ENUM('immunization','maternal') DEFAULT 'immunization',
    fcm_token                 VARCHAR(500)  NULL,
    push_notifications_enabled TINYINT(1)   NOT NULL DEFAULT 1,
    last_login                TIMESTAMP    NULL,
    created_at                TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email    (email),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Admins (backend admin accounts) ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admins (
    id                   INT          PRIMARY KEY AUTO_INCREMENT,
    username             VARCHAR(50)  UNIQUE NOT NULL,
    password             VARCHAR(255) NOT NULL,             -- bcrypt hash
    full_name            VARCHAR(100),
    email                VARCHAR(100),
    role                 VARCHAR(64)  NOT NULL DEFAULT 'admin',
    last_login           TIMESTAMP    NULL,
    password_changed_at  TIMESTAMP    NULL,
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Default admin — bcrypt hash of 'HealthTrack@2025' (cost 12)
-- CHANGE THIS PASSWORD IMMEDIATELY after first login.
INSERT IGNORE INTO admins (username, password, full_name, role)
VALUES (
    'admin',
    '$2b$12$rQsrVdN1u6F3k2lHJ4bvYOeKsN5X2pM7hD8wZ6yB1cA4mF9tG0E3e',
    'Administrator',
    'admin'
);

-- ─── Admin Sessions ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_sessions (
    id             VARCHAR(36)  NOT NULL PRIMARY KEY,
    admin_id       INT          NOT NULL,
    token_hash     VARCHAR(64)  NOT NULL,
    user_agent     TEXT         NULL,
    ip_address     VARCHAR(45)  NULL,
    device_label   VARCHAR(128) NULL,
    browser_label  VARCHAR(160) NULL,
    last_active_at TIMESTAMP    NULL,
    expires_at     TIMESTAMP    NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_token_hash (token_hash),
    INDEX idx_admin_id   (admin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Admin Preferences ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_preferences (
    id                          INT         PRIMARY KEY AUTO_INCREMENT,
    admin_id                    INT         NOT NULL UNIQUE,
    theme_mode                  VARCHAR(16) NOT NULL DEFAULT 'system',
    phone                       VARCHAR(64) NULL,
    avatar_url                  VARCHAR(512) NULL,
    auto_logout_enabled         TINYINT(1)  NOT NULL DEFAULT 0,
    analytics_enabled           TINYINT(1)  NOT NULL DEFAULT 0,
    data_sharing_enabled        TINYINT(1)  NOT NULL DEFAULT 0,
    appointment_reminders_enabled TINYINT(1) NOT NULL DEFAULT 0,
    appointment_notify_email    TINYINT(1)  NOT NULL DEFAULT 0,
    appointment_notify_push     TINYINT(1)  NOT NULL DEFAULT 0,
    appointment_notify_sms      TINYINT(1)  NOT NULL DEFAULT 0,
    system_alerts_enabled       TINYINT(1)  NOT NULL DEFAULT 0,
    system_alert_email          TINYINT(1)  NOT NULL DEFAULT 0,
    system_alert_push           TINYINT(1)  NOT NULL DEFAULT 0,
    system_alert_sms            TINYINT(1)  NOT NULL DEFAULT 0,
    totp_enabled                TINYINT(1)  NOT NULL DEFAULT 0,
    totp_secret                 VARBINARY(512) NULL,
    totp_pending_secret         VARBINARY(512) NULL,
    created_at                  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Audit Logs ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS audit_logs (
    id         INT          PRIMARY KEY AUTO_INCREMENT,
    admin_id   INT          NULL,
    action     VARCHAR(255) NOT NULL,
    description TEXT        NULL,
    ip_address VARCHAR(45)  NULL,
    user_agent TEXT         NULL,
    metadata   JSON         NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin_id   (admin_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Patients ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS patients (
    id                    INT          PRIMARY KEY AUTO_INCREMENT,
    user_id               INT          NULL,
    patient_id            VARCHAR(50),
    medical_record_number VARCHAR(100),
    child_fullname        VARCHAR(100) NOT NULL,
    mother_fullname       VARCHAR(100) NOT NULL,
    father_fullname       VARCHAR(100),
    dob                   DATE         NOT NULL,
    place_of_birth        VARCHAR(200) NOT NULL,
    birth_weight          VARCHAR(20),
    birth_height          VARCHAR(20),
    sex                   ENUM('Male','Female') NOT NULL,
    address               TEXT         NOT NULL,
    lmp_date              DATE         NULL,
    edd_date              DATE         NULL,
    gestational_age_weeks INT          NULL,
    gravida               INT          DEFAULT 1,
    para                  INT          DEFAULT 0,
    abortus               INT          DEFAULT 0,
    stillbirth            INT          DEFAULT 0,
    blood_pressure        VARCHAR(20)  NULL,
    weight                DECIMAL(5,2) NULL,
    height                DECIMAL(5,2) NULL,
    bmi                   DECIMAL(5,2) NULL,
    fundal_height         DECIMAL(5,2) NULL,
    fetal_heart_rate      INT          NULL,
    status                ENUM('active','inactive','archived') DEFAULT 'active',
    record_type           VARCHAR(50),
    service_type          ENUM('immunization','maternal') DEFAULT 'immunization',
    record_description    TEXT,
    health_center         VARCHAR(200),
    barangay              VARCHAR(100),
    family_number         VARCHAR(50),
    family_serial_number  VARCHAR(50),
    contact_number        VARCHAR(20),
    spouse_name           VARCHAR(100),
    living_children_count INT          DEFAULT 0,
    monthly_income        DECIMAL(10,2),
    religion              VARCHAR(50),
    city                  VARCHAR(100),
    province              VARCHAR(100),
    age                   INT,
    education             VARCHAR(100),
    occupation            VARCHAR(100),
    birth_attendant       ENUM('SBA','Non-SBA'),
    facility_type         VARCHAR(100),
    notes                 TEXT,
    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id          (user_id),
    INDEX idx_dob              (dob),
    INDEX idx_status           (status),
    INDEX idx_patient_id       (patient_id),
    INDEX idx_service_type     (service_type),
    INDEX idx_lmp_date         (lmp_date),
    INDEX idx_edd_date         (edd_date),
    INDEX idx_gestational_age  (gestational_age_weeks)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Appointments ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS appointments (
    id               INT          PRIMARY KEY AUTO_INCREMENT,
    user_id          INT,
    patient_id       INT,
    doctor_name      VARCHAR(100) NOT NULL,
    clinic_hospital  VARCHAR(200) NOT NULL,
    appointment_date DATE         NOT NULL,
    appointment_time TIME         NOT NULL,
    appointment_type VARCHAR(100) NOT NULL,
    status           ENUM('pending','scheduled','approved','completed','cancelled','rescheduled','no_show') NOT NULL DEFAULT 'pending',
    notes            TEXT,
    reminder_set     BOOLEAN      DEFAULT FALSE,
    completed_at     TIMESTAMP    NULL,
    missed_at        TIMESTAMP    NULL,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id          (user_id),
    INDEX idx_patient_id       (patient_id),
    INDEX idx_appointment_date (appointment_date),
    INDEX idx_status           (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Appointment Slots ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS appointment_slots (
    id             INT          PRIMARY KEY AUTO_INCREMENT,
    service_id     INT,
    slot_date      DATE         NOT NULL,
    slot_time      TIME         NOT NULL,
    capacity       INT          NOT NULL DEFAULT 1,
    booked_count   INT          NOT NULL DEFAULT 0,
    is_available   TINYINT(1)   NOT NULL DEFAULT 1,
    created_by     INT          NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_slot_date    (slot_date),
    INDEX idx_service_id   (service_id),
    INDEX idx_is_available (is_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Health Records ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS health_records (
    id               INT          PRIMARY KEY AUTO_INCREMENT,
    user_id          INT          NOT NULL,
    patient_id       INT,
    record_type      VARCHAR(50)  NOT NULL,
    title            VARCHAR(200) NOT NULL,
    description      TEXT,
    diagnosis        VARCHAR(255),
    record_values    VARCHAR(100),
    unit             VARCHAR(20),
    date_recorded    DATE         NOT NULL,
    doctor_name      VARCHAR(100),
    clinic_hospital  VARCHAR(200),
    attachments      TEXT,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id       (user_id),
    INDEX idx_patient_id    (patient_id),
    INDEX idx_record_type   (record_type),
    INDEX idx_date_recorded (date_recorded),
    INDEX idx_updated_at    (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Appointment Notifications ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS appointment_notifications (
    id                INT     PRIMARY KEY AUTO_INCREMENT,
    appointment_id    INT,
    user_id           INT     NOT NULL,
    notification_type ENUM('new_appointment','appointment_update','appointment_reminder','appointment_cancellation','appointment_approved','appointment_rescheduled','appointment_cancelled') NOT NULL,
    message           TEXT    NOT NULL,
    is_read           BOOLEAN DEFAULT FALSE,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_user_id        (user_id),
    INDEX idx_is_read        (is_read),
    INDEX idx_created_at     (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Notifications (general) ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
    id                INT          PRIMARY KEY AUTO_INCREMENT,
    user_id           INT          NOT NULL,
    title             VARCHAR(255) NOT NULL,
    message           TEXT         NOT NULL,
    notification_type VARCHAR(50)  NOT NULL DEFAULT 'general',
    is_read           TINYINT(1)   NOT NULL DEFAULT 0,
    data              JSON         NULL,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id    (user_id),
    INDEX idx_is_read    (is_read),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── User Device Tokens (multi-device FCM) ────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_device_tokens (
    id         INT          PRIMARY KEY AUTO_INCREMENT,
    user_id    INT          NOT NULL,
    device_id  VARCHAR(255) NOT NULL,
    fcm_token  VARCHAR(500) NOT NULL,
    platform   VARCHAR(20)  NULL,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_device (user_id, device_id),
    INDEX idx_user_id  (user_id),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Scheduled Notifications ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS scheduled_notifications (
    id                 INT          PRIMARY KEY AUTO_INCREMENT,
    user_id            INT          NOT NULL,
    appointment_id     INT          NULL,
    title              VARCHAR(255) NOT NULL,
    message            TEXT         NOT NULL,
    notification_type  VARCHAR(50)  NOT NULL,
    scheduled_datetime DATETIME     NOT NULL,
    status             ENUM('scheduled','sent','failed','cancelled') DEFAULT 'scheduled',
    sent_at            DATETIME     NULL,
    error_message      TEXT         NULL,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id            (user_id),
    INDEX idx_scheduled_datetime (scheduled_datetime),
    INDEX idx_status             (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Appointment Reminders ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS appointment_reminders (
    id                 INT          PRIMARY KEY AUTO_INCREMENT,
    appointment_id     INT          NOT NULL,
    user_id            INT          NOT NULL,
    reminder_date      DATE         NOT NULL,
    reminder_time      TIME         NOT NULL,
    scheduled_datetime DATETIME     NOT NULL,
    days_before        INT          NOT NULL,
    reminder_type      VARCHAR(50)  NOT NULL,
    status             ENUM('scheduled','sent','failed','cancelled') DEFAULT 'scheduled',
    sent_at            DATETIME     NULL,
    error_message      TEXT         NULL,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_appointment_id     (appointment_id),
    INDEX idx_user_id            (user_id),
    INDEX idx_scheduled_datetime (scheduled_datetime),
    INDEX idx_status             (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Notification History ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notification_history (
    id                INT          PRIMARY KEY AUTO_INCREMENT,
    user_id           INT          NOT NULL,
    title             VARCHAR(255) NOT NULL,
    message           TEXT         NOT NULL,
    notification_type VARCHAR(50)  NOT NULL,
    payload           JSON         NULL,
    status            ENUM('sent','failed','pending') NOT NULL,
    error_message     TEXT         NULL,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id           (user_id),
    INDEX idx_notification_type (notification_type),
    INDEX idx_status            (status),
    INDEX idx_created_at        (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Reminders (user-created) ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reminders (
    id          INT          PRIMARY KEY AUTO_INCREMENT,
    user_id     INT          NOT NULL,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    category    VARCHAR(50)  NOT NULL DEFAULT 'custom_reminder',
    reminder_date DATE,
    reminder_time TIME,
    is_active   TINYINT(1)   NOT NULL DEFAULT 1,
    repeat_days VARCHAR(100),
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id  (user_id),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Health Tips ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS health_tips (
    id           INT     PRIMARY KEY AUTO_INCREMENT,
    tip_category ENUM('maternal','pediatric','general') DEFAULT 'general',
    tip_text     TEXT    NOT NULL,
    is_active    BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tip_category (tip_category),
    INDEX idx_is_active    (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Services Config ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS services_config (
    id           INT          PRIMARY KEY AUTO_INCREMENT,
    service_name VARCHAR(100) NOT NULL,
    service_type ENUM('immunization','maternal','general') NOT NULL DEFAULT 'general',
    description  TEXT,
    is_active    TINYINT(1)   NOT NULL DEFAULT 1,
    duration_minutes INT      NOT NULL DEFAULT 30,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_service_type (service_type),
    INDEX idx_is_active    (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Referrals ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS referrals (
    id                  INT          PRIMARY KEY AUTO_INCREMENT,
    patient_id          INT          NOT NULL,
    referred_to         VARCHAR(200) NOT NULL,
    referral_date       DATE         NOT NULL,
    referral_notes      TEXT         NOT NULL,
    referring_admin_id  INT          NULL,
    status              ENUM('pending','accepted','completed','cancelled') DEFAULT 'pending',
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_patient_id (patient_id),
    INDEX idx_status     (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── System Settings ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS system_settings (
    id            INT          PRIMARY KEY AUTO_INCREMENT,
    setting_key   VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type  ENUM('string','number','boolean','json') DEFAULT 'string',
    description   TEXT,
    is_active     BOOLEAN      DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_setting_key (setting_key),
    INDEX idx_is_active   (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Default System Settings ──────────────────────────────────────────────────

INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('app_name',                    'HealthTrack System', 'string',  'Application name'),
('maintenance_mode',            'false',              'boolean', 'Enable/disable maintenance mode'),
('max_appointments_per_day',    '50',                 'number',  'Maximum appointments per day'),
('appointment_reminders_enabled','true',              'boolean', 'Enable appointment reminder notifications'),
('reminder_interval_hours',     '24',                 'number',  'Hours before appointment to send reminder'),
('reminder_days_before',        '[2, 1]',             'json',    'Days before appointment to send reminders'),
('reminders_per_day',           '2',                  'number',  'Number of reminders to send per day'),
('reminder_times',              '["09:00","18:00"]',  'json',    'Times of day to send reminders'),
('data_retention_days',         '365',                'number',  'Days to retain patient data'),
('default_service_type',        'immunization',       'string',  'Default service type for new patients'),
('notifications_enabled',       'true',               'boolean', 'Enable/disable all system notifications');

-- ─── Default Health Tips ──────────────────────────────────────────────────────

INSERT IGNORE INTO health_tips (tip_category, tip_text, is_active) VALUES
('maternal', 'Drink plenty of water to stay hydrated during pregnancy', TRUE),
('maternal', 'Take prenatal vitamins as prescribed by your doctor', TRUE),
('maternal', 'Attend all scheduled prenatal checkups with your healthcare provider', TRUE),
('maternal', 'Avoid alcohol, tobacco, and illicit drugs during pregnancy', TRUE),
('maternal', 'Get adequate rest and sleep for at least 7-9 hours per night', TRUE),
('pediatric', 'Ensure your child receives all scheduled immunizations on time', TRUE),
('pediatric', 'Monitor your child''s growth and development regularly', TRUE),
('general', 'Wash hands frequently to prevent the spread of infections', TRUE),
('general', 'Maintain a balanced diet rich in fruits, vegetables, and whole grains', TRUE),
('general', 'Get regular exercise appropriate for your age and health condition', TRUE);

-- ─── Verify ───────────────────────────────────────────────────────────────────

SELECT 'Schema imported successfully' AS status;
SHOW TABLES;
