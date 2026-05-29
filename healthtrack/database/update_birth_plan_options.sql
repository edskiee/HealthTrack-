-- Update script to document the change in birth plan options
-- This script is for documentation purposes as the facility_type field already exists
-- and accepts VARCHAR values, so no schema changes are needed

-- The facility_type field in the patients table already exists and accepts:
-- 'Hospital', 'Birthing Center', 'RHU', 'Home' and other values as VARCHAR(100)

-- No schema changes are required as the field is already VARCHAR(100)
-- This update is just to document that the valid options are now:
-- Hospital, Birthing Center, RHU (Rural Health Unit), and Home

-- Sample update for existing records if needed:
-- UPDATE patients 
-- SET facility_type = 'Birthing Center' 
-- WHERE facility_type = 'LIC';

-- Show the current structure of the facility_type column
DESCRIBE patients facility_type;