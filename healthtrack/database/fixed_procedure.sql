USE healthtrack;

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
    DECLARE v_overlap_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 p_error_message = MESSAGE_TEXT;
        SET p_generated_count = 0;
    END;
    
    SET p_generated_count = 0;
    SET p_error_message = NULL;
    
    START TRANSACTION;
    
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
        SELECT COUNT(*) INTO v_existing_count 
        FROM appointment_slots 
        WHERE service_id = p_service_id AND appointment_date = p_appointment_date;
        
        SET v_total_slots = TIMESTAMPDIFF(MINUTE, p_start_time, p_end_time) DIV p_slot_duration_minutes;
        
        IF v_existing_count + v_total_slots > v_max_daily_slots THEN
            SET p_error_message = CONCAT('Cannot generate slots: would exceed daily limit of ', v_max_daily_slots, ' slots');
            SET p_generated_count = 0;
            ROLLBACK;
        ELSE
            SET p_generated_count = 0;
            SET v_current_time = p_start_time;
            
            slot_loop: WHILE v_current_time < p_end_time DO
                SET v_slot_end_time = ADDTIME(v_current_time, CONCAT(p_slot_duration_minutes, ' MINUTE'));
                
                IF v_slot_end_time > p_end_time THEN
                    LEAVE slot_loop;
                END IF;
                
                SELECT COUNT(*) INTO v_overlap_count
                FROM appointment_slots 
                WHERE service_id = p_service_id 
                  AND appointment_date = p_appointment_date
                  AND (
                    (start_time < v_slot_end_time AND end_time > v_current_time)
                  );
                
                IF v_overlap_count = 0 THEN
                    INSERT INTO appointment_slots 
                    (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, is_available, booked_patients, created_at, updated_at)
                    VALUES (p_service_id, p_appointment_date, v_current_time, v_slot_end_time, p_slot_duration_minutes, p_max_patients, TRUE, 0, NOW(), NOW());
                    
                    SET p_generated_count = p_generated_count + 1;
                END IF;
                
                SET v_current_time = ADDTIME(v_current_time, CONCAT(p_slot_duration_minutes, ' MINUTE'));
            END WHILE slot_loop;
            
            COMMIT;
        END IF;
    END IF;
END //
DELIMITER ;
