USE healthtrack;

-- Test the logic step by step
SELECT 'Testing loop logic' as test;

-- Clear any existing slots
DELETE FROM appointment_slots WHERE service_id = 16 AND appointment_date = '2026-03-13';

-- Test the time comparison logic
SELECT '09:00:00' < '10:00:00' as time_comparison;

-- Test ADDTIME function
SELECT ADDTIME('09:00:00', '30 MINUTE') as slot_end;

-- Test if slot_end_time > end_time
SELECT ADDTIME('09:00:00', '30 MINUTE') > '10:00:00' as exceeds_end_time;

-- Test the loop manually
SET @current_time = '09:00:00';
SET @slot_count = 0;

WHILE @current_time < '10:00:00' DO
    SET @slot_end_time = ADDTIME(@current_time, '30 MINUTE');
    
    IF @slot_end_time > '10:00:00' THEN
        LEAVE; -- This doesn't work in MySQL script, but let's see
    END IF;
    
    SELECT @current_time as current_time, @slot_end_time as slot_end_time;
    
    INSERT INTO appointment_slots 
    (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, is_available, booked_patients, created_at, updated_at)
    VALUES (16, '2026-03-13', @current_time, @slot_end_time, 30, 10, TRUE, 0, NOW(), NOW());
    
    SET @slot_count = @slot_count + 1;
    SET @current_time = ADDTIME(@current_time, '30 MINUTE');
END WHILE;

SELECT @slot_count as manual_slots_created;

-- Check results
SELECT * FROM appointment_slots WHERE service_id = 16 AND appointment_date = '2026-03-13';
