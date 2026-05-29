USE healthtrack;

-- Add a unique constraint to the appointments table to prevent duplicate bookings
ALTER TABLE appointments
ADD CONSTRAINT unique_appointment UNIQUE (appointment_date, appointment_time, appointment_type);
