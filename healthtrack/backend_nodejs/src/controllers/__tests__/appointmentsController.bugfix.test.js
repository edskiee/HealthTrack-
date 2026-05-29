/**
 * Bug Condition Exploration Test for Timezone Conversion Bug
 * 
 * **Validates: Requirements 1.1, 1.2, 1.3**
 * 
 * This test is designed to FAIL on unfixed code to prove the bug exists.
 * The test verifies that YYYY-MM-DD date strings are NOT converted via timezone logic.
 * 
 * CRITICAL: This test MUST FAIL on unfixed code - failure confirms the bug exists.
 * DO NOT attempt to fix the test or the code when it fails.
 * 
 * The test encodes the expected behavior and will validate the fix when it passes after implementation.
 * 
 * The bug manifests when:
 * 1. Date string "YYYY-MM-DD" is parsed with "T00:00:00" appended
 * 2. This is interpreted as LOCAL time (e.g., 2026-03-02 00:00:00 Manila)
 * 3. Internally stored as UTC (e.g., 2026-03-01 16:00:00 UTC for UTC+8)
 * 4. The UTC representation has the WRONG date (2026-03-01 instead of 2026-03-02)
 * 5. This causes issues when the date is serialized, stored, or compared in UTC context
 */

const fc = require('fast-check');

/**
 * Property 1: Fault Condition - Timezone Conversion on YYYY-MM-DD Dates
 * 
 * This property tests that date parsing does NOT apply timezone conversion
 * for YYYY-MM-DD formatted date strings.
 */
describe('Bug Condition Exploration: Timezone Conversion on YYYY-MM-DD Dates', () => {
  
  /**
   * Test 1.1: Appointment date validation should NOT apply timezone conversion
   * 
   * Tests the buggy code path in appointmentsController.js:
   * `new Date(normalizedAppointmentDate + 'T00:00:00')`
   * 
   * Expected behavior: UTC representation should have the same date as input
   * Current buggy behavior: UTC representation has wrong date due to timezone offset
   */
  test('Appointment date validation does NOT apply timezone conversion', () => {
    // Generate YYYY-MM-DD date strings that would fail with timezone conversion
    fc.assert(
      fc.property(
        // Generate dates from 2024 to 2030
        fc.integer({ min: 2024, max: 2030 }),
        fc.integer({ min: 1, max: 12 }),
        fc.integer({ min: 1, max: 28 }), // Use 28 to avoid month-end edge cases
        (year, month, day) => {
          // Format as YYYY-MM-DD
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          
          // Simulate the buggy code path from appointmentsController.js
          // This is what the controller does: new Date(normalizedAppointmentDate + 'T00:00:00')
          const buggyParsedDate = new Date(dateStr + 'T00:00:00');
          
          // The correct way to parse (from appointmentSlotsController.js)
          const [y, m, d] = dateStr.split('-').map(Number);
          const correctParsedDate = new Date(y, m - 1, d);
          correctParsedDate.setHours(0, 0, 0, 0);
          
          // Expected behavior: Both should have the same UTC date representation
          // Bug: buggyParsedDate has wrong UTC date due to timezone interpretation
          const buggyUTCDate = buggyParsedDate.toISOString().split('T')[0];
          const correctUTCDate = correctParsedDate.toISOString().split('T')[0];
          
          // This assertion will FAIL on unfixed code when timezone offset causes date shift
          return buggyUTCDate === correctUTCDate && correctUTCDate === dateStr;
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Test 1.2: Reschedule date validation should NOT apply timezone conversion
   * 
   * Tests the buggy code path in appointmentsController.js:
   * `new Date(rescheduleDate + 'T00:00:00')`
   * 
   * Expected behavior: UTC representation should have the same date as input
   * Current buggy behavior: UTC representation has wrong date due to timezone offset
   */
  test('Reschedule date validation does NOT apply timezone conversion', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 2024, max: 2030 }),
        fc.integer({ min: 1, max: 12 }),
        fc.integer({ min: 1, max: 28 }),
        (year, month, day) => {
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          
          // Simulate the buggy reschedule validation code path
          const buggyRescheduleDateObj = new Date(dateStr + 'T00:00:00');
          
          // The correct way to parse
          const [y, m, d] = dateStr.split('-').map(Number);
          const correctRescheduleDateObj = new Date(y, m - 1, d);
          correctRescheduleDateObj.setHours(0, 0, 0, 0);
          
          // Compare UTC representations
          const buggyUTCDate = buggyRescheduleDateObj.toISOString().split('T')[0];
          const correctUTCDate = correctRescheduleDateObj.toISOString().split('T')[0];
          
          // This assertion will FAIL on unfixed code
          return buggyUTCDate === correctUTCDate && correctUTCDate === dateStr;
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Test 1.3: Date parsing without time component should NOT apply timezone conversion
   * 
   * Tests potential timezone conversion when parsing YYYY-MM-DD without time
   * 
   * Expected behavior: UTC representation should have the same date as input
   * Current buggy behavior: May apply timezone conversion depending on format
   */
  test('Date parsing without time component does NOT apply timezone conversion', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 2024, max: 2030 }),
        fc.integer({ min: 1, max: 12 }),
        fc.integer({ min: 1, max: 28 }),
        (year, month, day) => {
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          
          // Parsing YYYY-MM-DD without time (ISO 8601 format)
          // This is interpreted as UTC midnight
          const parsedDate = new Date(dateStr);
          
          // The correct way to parse as local date
          const [y, m, d] = dateStr.split('-').map(Number);
          const correctDate = new Date(y, m - 1, d);
          correctDate.setHours(0, 0, 0, 0);
          
          // Compare UTC representations
          const parsedUTCDate = parsedDate.toISOString().split('T')[0];
          const correctUTCDate = correctDate.toISOString().split('T')[0];
          
          // This assertion will FAIL if timezone conversion occurs
          return parsedUTCDate === correctUTCDate && correctUTCDate === dateStr;
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Concrete failing case test: Specific date that demonstrates the bug
   * 
   * This test uses the concrete example from the bugfix document:
   * "2026-03-02 parsed as 2026-03-01 due to UTC conversion"
   * 
   * In Asia/Manila (UTC+8):
   * - Input: "2026-03-02T00:00:00"
   * - Interpreted as: 2026-03-02 00:00:00 Manila time
   * - UTC representation: 2026-03-01 16:00:00 UTC (WRONG DATE!)
   */
  test('Concrete failing case: 2026-03-02 UTC representation should be 2026-03-02', () => {
    const dateStr = '2026-03-02';
    
    // Simulate the buggy code path
    const buggyParsedDate = new Date(dateStr + 'T00:00:00');
    
    // The correct way to parse
    const [year, month, day] = dateStr.split('-').map(Number);
    const correctParsedDate = new Date(year, month - 1, day);
    correctParsedDate.setHours(0, 0, 0, 0);
    
    // Check UTC representation
    const buggyUTCDateStr = buggyParsedDate.toISOString().split('T')[0];
    const correctUTCDateStr = correctParsedDate.toISOString().split('T')[0];
    
    // Expected: Both should be "2026-03-02"
    // Buggy behavior: buggyUTCDateStr is "2026-03-01" (due to UTC+8 timezone conversion)
    expect(buggyUTCDateStr).toBe('2026-03-02');
    expect(correctUTCDateStr).toBe('2026-03-02');
    expect(buggyUTCDateStr).toBe(correctUTCDateStr);
  });
});
