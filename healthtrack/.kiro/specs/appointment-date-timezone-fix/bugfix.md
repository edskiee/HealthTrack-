# Bugfix Requirements Document

## Introduction

The appointment slot generation system currently suffers from a timezone inconsistency bug that causes appointment dates to be displayed on the wrong day in the calendar widget. When the frontend sends an appointment_date in YYYY-MM-DD format (e.g., "2026-03-02"), the backend's use of JavaScript's `new Date()` constructor automatically converts it to UTC, resulting in storage as an ISO datetime string (e.g., "2026-03-01T16:00:00.000Z"). For users in Asia/Manila timezone (UTC+8), this causes an 8-hour backward shift, displaying slots on the previous day.

This bug affects the core functionality of the appointment booking system, causing confusion for both administrators creating slots and users viewing available appointments. The system must treat appointment_date strictly as a local date-only value without any timezone conversion.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the backend receives appointment_date "2026-03-02" from the frontend THEN the system converts it to UTC using `new Date()` resulting in "2026-03-01T16:00:00.000Z" being stored

1.2 WHEN the backend parses appointment_date strings using `new Date(year, month - 1, day)` in validation logic THEN the system creates Date objects with local timezone information that may cause comparison issues

1.3 WHEN the calendar widget retrieves slot data from the database THEN the system returns dates that have been shifted by the timezone offset, displaying slots on the wrong date

1.4 WHEN comparing dates for slot generation overlap detection THEN the system may incorrectly identify or miss overlapping slots due to timezone conversion artifacts

### Expected Behavior (Correct)

2.1 WHEN the backend receives appointment_date "2026-03-02" from the frontend THEN the system SHALL store it exactly as "2026-03-02" without any timezone conversion or ISO datetime transformation

2.2 WHEN the backend validates appointment_date values THEN the system SHALL treat them as pure date strings in YYYY-MM-DD format without creating Date objects that trigger timezone conversion

2.3 WHEN the calendar widget retrieves slot data from the database THEN the system SHALL return appointment_date in YYYY-MM-DD format exactly as stored, ensuring the calendar displays the correct date

2.4 WHEN comparing dates for validation or overlap detection THEN the system SHALL perform string-based or date-only comparisons that preserve the original date value without timezone shifts

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the backend validates that appointment_date is not in the past THEN the system SHALL CONTINUE TO reject past dates correctly using local date comparison

3.2 WHEN the backend generates multiple slots within a time range THEN the system SHALL CONTINUE TO create the correct number of slots with proper start and end times

3.3 WHEN the backend checks for overlapping slots THEN the system SHALL CONTINUE TO prevent duplicate slot creation for the same service, date, and time range

3.4 WHEN the backend validates date format THEN the system SHALL CONTINUE TO enforce YYYY-MM-DD format using regex validation

3.5 WHEN the backend validates time formats for start_time and end_time THEN the system SHALL CONTINUE TO enforce HH:MM:SS format and validate time ranges correctly

3.6 WHEN the system stores and retrieves time values (start_time, end_time) THEN the system SHALL CONTINUE TO handle them correctly as TIME type without timezone conversion

3.7 WHEN real-time slot updates are emitted via Socket.IO THEN the system SHALL CONTINUE TO notify connected clients with the correct date information
