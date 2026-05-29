-- Enhanced Appointment Slots Constraints for Real-time Synchronization
-- This script adds improved validation, indexing, and overflow prevention

USE healthtrack;

-- Add unique constraint to prevent duplicate slots
ALTER TABLE appointment_slots 
ADD CONSTRAINT unique_slot_time_service 
UNIQUE (service_id, appointment_date, start_time, end_time);

-- Add check constraints for data integrity
ALTER TABLE appointment_slots 
ADD CONSTRAINT chk_time_range CHECK (start_time < end_time);

ALTER TABLE appointment_slots 
ADD CONSTRAINT chk_positive_duration CHECK (slot_duration_minutes > 0 AND slot_duration_minutes <= 480);

ALTER TABLE appointment_slots 
ADD CONSTRAINT chk_positive_patients CHECK (max_patients > 0 AND max_patients <= 100);

ALTER TABLE appointment_slots 
ADD CONSTRAINT chk_booked_patients CHECK (booked_patients >= 0 AND booked_patients <= max_patients);

-- Add composite indexes for optimal query performance in real-time scenarios
CREATE INDEX idx_slot_availability_query ON appointment_slots(service_id, appointment_date, is_available, booked_patients);
CREATE INDEX idx_slot_time_range ON appointment_slots(appointment_date, start_time, end_time);
CREATE INDEX idx_slot_service_availability ON appointment_slots(service_id, is_available, appointment_date);

-- Add trigger for automatic availability status updates
DELIMITER //
CREATE TRIGGER update_slot_availability 
AFTER UPDATE ON appointment_slots
FOR EACH ROW
BEGIN
    IF NEW.booked_patients >= NEW.max_patients THEN
        UPDATE appointment_slots SET is_available = FALSE WHERE id = NEW.id;
    ELSEIF NEW.booked_patients < NEW.max_patients THEN
        UPDATE appointment_slots SET is_available = TRUE WHERE id = NEW.id;
    END IF;
END//
DELIMITER ;

-- Add stored procedure for safe slot generation with overflow prevention
DELIMITER //
CREATE PROCEDURE GenerateSlotsSafely(
    IN p_service_id INT,
    IN p_appointment_date DATE,
    IN p_start_time TIME,
    IN p_end_time TIME,
    IN p_slot_duration_minutes INT,
    IN p_max_patients INT,
    OUT p_generated_count INT,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_current_time TIME DEFAULT p_start_time;
    DECLARE v_slot_end_time TIME;
    DECLARE v_existing_count INT DEFAULT 0;
    DECLARE v_total_slots INT DEFAULT 0;
    DECLARE v_max_daily_slots INT DEFAULT 100;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 p_error_message = MESSAGE_TEXT;
        SET p_generated_count = 0;
    END;

    -- Start transaction for atomic operation
    START TRANSACTION;
    
    -- Validate input parameters
    IF p_service_id IS NULL OR p_appointment_date IS NULL OR p_start_time IS NULL OR p_end_time IS NULL THEN
        SET p_error_message = 'Missing required parameters';
        SET p_generated_count = 0;
        ROLLBACK;
    ELSEIF p_start_time >= p_end_time THEN
        SET p_error_message = 'Start time must be before end time';
        SET p_generated_count = 0;
        ROLLBACK;
    ELSEIF p_slot_duration_minutes <= 0 OR p_slot_duration_minutes > 480 THEN
        SET p_error_message = 'Invalid slot duration';
        SET p_generated_count = 0;
        ROLLBACK;
    ELSE
        -- Check existing slots for the day to prevent overflow
        SELECT COUNT(*) INTO v_existing_count 
        FROM appointment_slots 
        WHERE service_id = p_service_id AND appointment_date = p_appointment_date;
        
        -- Calculate maximum possible slots
        SET v_total_slots = TIMESTAMPDIFF(MINUTE, p_start_time, p_end_time) / p_slot_duration_minutes;
        
        -- Prevent overflow beyond daily limits
        IF v_existing_count + v_total_slots > v_max_daily_slots THEN
            SET p_error_message = CONCAT('Cannot generate slots: would exceed daily limit of ', v_max_daily_slots, ' slots');
            SET p_generated_count = 0;
            ROLLBACK;
        ELSE
            -- Generate slots in a loop
            SET p_generated_count = 0;
            
            WHILE v_current_time < p_end_time DO
                SET v_slot_end_time = ADDTIME(v_current_time, CONCAT(p_slot_duration_minutes, ' MINUTE'));
                
                -- Skip if slot would exceed end time
                IF v_slot_end_time > p_end_time THEN
                    LEAVE WHILE;
                END IF;
                
                -- Check for overlapping existing slots
                SELECT COUNT(*) INTO @overlap_count
                FROM appointment_slots 
                WHERE service_id = p_service_id 
                  AND appointment_date = p_appointment_date
                  AND (
                      (start_time < v_slot_end_time AND end_time > v_current_time)
                  );
                
                -- Insert slot only if no overlap
                IF @overlap_count = 0 THEN
                    INSERT INTO appointment_slots 
                    (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients)
                    VALUES (p_service_id, p_appointment_date, v_current_time, v_slot_end_time, p_slot_duration_minutes, p_max_patients);
                    
                    SET p_generated_count = p_generated_count + 1;
                END IF;
                
                SET v_current_time = ADDTIME(v_current_time, CONCAT(p_slot_duration_minutes, ' MINUTE'));
            END WHILE;
            
            COMMIT;
        END IF;
    END IF;
END//
DELIMITER ;

-- Add function to check slot availability with locking
DELIMITER //
CREATE FUNCTION IsSlotAvailableForBooking(p_slot_id INT) 
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_is_available BOOLEAN;
    DECLARE v_booked_patients INT;
    DECLARE v_max_patients INT;
    
    SELECT is_available, booked_patients, max_patients 
    INTO v_is_available, v_booked_patients, v_max_patients
    FROM appointment_slots 
    WHERE id = p_slot_id 
    FOR UPDATE;
    
    RETURN v_is_available AND v_booked_patients < v_max_patients;
END//
DELIMITER ;

-- Show completion message
SELECT 'Enhanced appointment slots constraints and procedures implemented successfully!' as status;
