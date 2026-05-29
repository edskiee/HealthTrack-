# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Fault Condition** - Timezone Conversion on YYYY-MM-DD Dates
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate timezone conversion is occurring
  - **Scoped PBT Approach**: Scope the property to concrete failing cases with YYYY-MM-DD date strings
  - Test that appointment date validation in appointmentsController.js does NOT apply timezone conversion
  - Test that reschedule date validation in appointmentsController.js does NOT apply timezone conversion
  - Test that admin calendar backup widget date parsing does NOT apply timezone conversion
  - For input dates in YYYY-MM-DD format (e.g., "2026-03-02"), verify the parsed date matches the input date components without shifting
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "2026-03-02 parsed as 2026-03-01 due to UTC conversion")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3_

- [-] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Existing Correct Date Parsing Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for components already using correct date parsing
  - Test that appointmentSlotsController.js continues to parse dates using split-and-construct method
  - Test that main admin calendar widget continues to parse dates by splitting components
  - Test that user appointments tab continues to parse dates by splitting components
  - Test that dates stored in database remain in DATE column type without time components
  - Test that dates sent from frontend to backend remain in YYYY-MM-DD format without timezone suffixes
  - Test that dates returned from backend to frontend remain in YYYY-MM-DD format without timezone suffixes
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [~] 3. Fix timezone conversion in appointment date validation

  - [~] 3.1 Fix appointment creation date validation in appointmentsController.js
    - Replace `new Date(normalizedAppointmentDate + 'T00:00:00')` with split-and-construct method
    - Parse YYYY-MM-DD string by splitting into year, month, day components
    - Construct date using `new Date(year, month - 1, day)` to avoid timezone conversion
    - _Bug_Condition: isBugCondition(input) where input is YYYY-MM-DD date string parsed with new Date() constructor causing UTC conversion_
    - _Expected_Behavior: Parse YYYY-MM-DD string as local date components without timezone conversion (2.1)_
    - _Preservation: Maintain correct behavior in appointment slots controller and other calendar widgets (3.1, 3.2, 3.3, 3.4, 3.5, 3.6)_
    - _Requirements: 1.1, 2.1_

  - [~] 3.2 Fix reschedule date validation in appointmentsController.js
    - Replace `new Date(rescheduleDate + 'T00:00:00')` with split-and-construct method
    - Parse YYYY-MM-DD string by splitting into year, month, day components
    - Construct date using `new Date(year, month - 1, day)` to avoid timezone conversion
    - _Bug_Condition: isBugCondition(input) where input is YYYY-MM-DD date string parsed with new Date() constructor causing UTC conversion_
    - _Expected_Behavior: Parse YYYY-MM-DD string as local date components without timezone conversion (2.2)_
    - _Preservation: Maintain correct behavior in appointment slots controller and other calendar widgets (3.1, 3.2, 3.3, 3.4, 3.5, 3.6)_
    - _Requirements: 1.2, 2.2_

  - [~] 3.3 Fix date parsing in admin calendar backup widget
    - Replace `DateTime.parse(dateStr)` with component-based parsing
    - Split YYYY-MM-DD string into year, month, day components
    - Construct DateTime using `DateTime(year, month, day)` to avoid timezone conversion
    - _Bug_Condition: isBugCondition(input) where input is YYYY-MM-DD date string parsed with DateTime.parse() potentially causing timezone conversion_
    - _Expected_Behavior: Parse YYYY-MM-DD string by splitting components to avoid timezone conversion (2.3)_
    - _Preservation: Maintain correct behavior in appointment slots controller and other calendar widgets (3.1, 3.2, 3.3, 3.4, 3.5, 3.6)_
    - _Requirements: 1.3, 2.3_

  - [~] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Timezone Conversion Fixed
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3_

  - [~] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - No Regressions in Existing Date Parsing
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [~] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
