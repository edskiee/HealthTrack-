USE healthtrack;

-- Test the procedure step by step
SELECT 'Testing procedure step by step' as debug_step;

-- Check if service exists
SELECT * FROM services_config WHERE id = 16;

-- Check existing slots
SELECT COUNT(*) as existing_slots FROM appointment_slots WHERE service_id = 16 AND appointment_date = '2026-03-13';

-- Test time calculation
SELECT 
    TIME_TO_SEC('10:00:00') - TIME_TO_SEC('09:00:00') as diff_seconds,
    (TIME_TO_SEC('10:00:00') - TIME_TO_SEC('09:00:00')) / 60 as diff_minutes,
    FLOOR((TIME_TO_SEC('10:00:00') - TIME_TO_SEC('09:00:00')) / 60 / 30) as total_slots;

-- Test manual slot creation
INSERT INTO appointment_slots 
(service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, is_available, booked_patients, created_at, updated_at)
VALUES (16, '2026-03-13', '09:00:00', '09:30:00', 30, 10, TRUE, 0, NOW(), NOW());

-- Check if slot was created
SELECT * FROM appointment_slots WHERE service_id = 16 AND appointment_date = '2026-03-13';

-- Clean up test
DELETE FROM appointment_slots WHERE service_id = 16 AND appointment_date = '2026-03-13';
