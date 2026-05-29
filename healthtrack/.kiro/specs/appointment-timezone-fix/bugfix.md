# Bugfix Requirements Document

## Introduction

The appointment slot generation system currently suffers from a timezone inconsistency bug that causes appointment dates to shift by one day when stored and retrieved. When the frontend sends an appointment_date in YYYY-MM-DD format (e.g., "2026-03-02"), certain backend code paths use `new Date()` constructor which automatically interprets the date string as UTC and converts it to the local timezone (Asia/Manila, UTC+8). This causes the calendar widget to display slots on the wrong date, creating confusion for both administrators and users.

The bug affects:
- Appointment creation date validation in `appointmentsController.js`
- Appointment reschedule date validation in `appointmentsController.js`
- Date parsing in the admin calendar widget backup file

While the appointment slots controller (`appointmentSlotsController.js`) has already been fixed to parse dates correctly without timezone conversion, and the database schema correctly uses DATE type, the appointments controller still contains problematic date parsing logic that triggers UTC conversion.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the appointments controller validates an appointment date using `new Date(normalizedAppointmentDate + 'T00:00:00')` THEN the system interprets the date as UTC and converts it to local time, causing a date shift

1.2 WHEN the appointments controller validates a reschedule date using `new Date(rescheduleDate + 'T00:00:00')` THEN the system interprets the date as UTC and converts it to local time, causing a date shift

1.3 WHEN the admin calendar backup widget parses appointment_date using `DateTime.parse(dateStr)` in Flutter THEN the system may apply timezone conversion depending on the date string format

### Expected Behavior (Correct)

2.1 WHEN the appointments controller validates an appointment date THEN the system SHALL parse the YYYY-MM-DD string as local date components without timezone conversion

2.2 WHEN the appointments controller validates a reschedule date THEN the system SHALL parse the YYYY-MM-DD string as local date components without timezone conversion

2.3 WHEN the admin calendar backup widget parses appointment_date THEN the system SHALL parse the YYYY-MM-DD string by splitting components to avoid timezone conversion

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the appointment slots controller creates or validates slots THEN the system SHALL CONTINUE TO parse dates using the split-and-construct method without timezone conversion

3.2 WHEN the main admin calendar widget parses appointment_date THEN the system SHALL CONTINUE TO parse dates by splitting date components

3.3 WHEN the user appointments tab parses appointment_date THEN the system SHALL CONTINUE TO parse dates by splitting date components

3.4 WHEN dates are stored in the database THEN the system SHALL CONTINUE TO store them in the DATE column type without time components

3.5 WHEN dates are sent from frontend to backend THEN the system SHALL CONTINUE TO send them in YYYY-MM-DD format without timezone suffixes

3.6 WHEN dates are returned from backend to frontend THEN the system SHALL CONTINUE TO return them in YYYY-MM-DD format without timezone suffixes
