-- Clean up existing appointment slots data to satisfy constraints
USE healthtrack;

-- Remove slots with invalid time ranges
DELETE FROM appointment_slots WHERE start_time >= end_time;

-- Remove slots with invalid duration
DELETE FROM appointment_slots WHERE slot_duration_minutes <= 0 OR slot_duration_minutes > 480;

-- Remove slots with invalid patient counts
DELETE FROM appointment_slots WHERE max_patients <= 0 OR max_patients > 100;

-- Remove slots with invalid booked counts
UPDATE appointment_slots SET booked_patients = 0 WHERE booked_patients < 0;
UPDATE appointment_slots SET booked_patients = max_patients WHERE booked_patients > max_patients;

-- Remove duplicate slots, keeping the earliest created
DELETE s1 FROM appointment_slots s1
INNER JOIN appointment_slots s2 
WHERE s1.id > s2.id 
  AND s1.service_id = s2.service_id 
  AND s1.appointment_date = s2.appointment_date 
  AND s1.start_time = s2.start_time 
  AND s1.end_time = s2.end_time;

-- Show cleanup results
SELECT 'Data cleanup completed!' as status;
