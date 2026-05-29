/**
 * Debug reminder scheduling date logic
 */

const { createAppointmentReminderSchedule } = require('./backend_nodejs/src/services/appointmentReminderService');

async function debugReminderScheduling() {
  try {
    console.log('=== Debugging Reminder Scheduling ===');
    
    // Test with different dates
    const testCases = [
      { appointmentId: 69, date: '2026-04-18', time: '10:00', userId: 1 },
      { appointmentId: 69, date: '2026-04-25', time: '10:00', userId: 1 }, // Further in future
      { appointmentId: 69, date: '2026-04-20', time: '10:00', userId: 1 }, // 3 days from now
    ];
    
    for (const testCase of testCases) {
      console.log(`\n--- Testing: ${testCase.date} ${testCase.time} ---`);
      
      const now = new Date();
      const appointmentDate = new Date(`${testCase.date} ${testCase.time}`);
      const daysUntil = Math.ceil((appointmentDate - now) / (1000 * 60 * 60 * 24));
      
      console.log(`Current time: ${now.toISOString()}`);
      console.log(`Appointment time: ${appointmentDate.toISOString()}`);
      console.log(`Days until appointment: ${daysUntil}`);
      
      const result = await createAppointmentReminderSchedule(
        testCase.appointmentId, 
        testCase.date, 
        testCase.time, 
        testCase.userId
      );
      
      console.log(`Result:`, result);
    }
    
  } catch (error) {
    console.error('Debug error:', error);
  }
  
  process.exit(0);
}

debugReminderScheduling();
