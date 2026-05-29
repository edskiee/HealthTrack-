/**
 * Setup script for appointment reminder system
 * Run this script to create the necessary database tables and settings
 */

const { createAppointmentRemindersTable } = require('./src/setup/appointmentReminderSetup');

async function setupAppointmentReminders() {
  console.log('🚀 Starting appointment reminder system setup...');
  
  try {
    const result = await createAppointmentRemindersTable();
    
    if (result.success) {
      console.log('✅ Appointment reminder system setup completed successfully!');
      console.log('');
      console.log('📋 What has been set up:');
      console.log('   • appointment_reminders table for storing scheduled reminders');
      console.log('   • notification_history table for tracking all sent notifications');
      console.log('   • System settings for reminder configuration');
      console.log('');
      console.log('⚙️ Default reminder settings:');
      console.log('   • Reminders enabled: true');
      console.log('   • Reminder days before: [2, 1] (2 days and 1 day before)');
      console.log('   • Reminders per day: 2');
      console.log('   • Reminder times: ["09:00", "18:00"] (9 AM and 6 PM)');
      console.log('');
      console.log('🔄 The system will automatically:');
      console.log('   • Create reminder schedules when appointments are approved');
      console.log('   • Send reminders at scheduled times');
      console.log('   • Check for due reminders every minute');
      console.log('   • Clean up old reminders periodically');
      console.log('');
      console.log('🌐 API endpoints available:');
      console.log('   • GET /appointment-reminders/check-due - Check and send due reminders');
      console.log('   • GET /appointment-reminders/user/:userId/upcoming - Get upcoming reminders');
      console.log('   • GET /appointment-reminders/user/:userId/check-upcoming - Check upcoming appointments');
      console.log('   • POST /appointment-reminders/cleanup - Clean up old reminders');
    } else {
      console.error('❌ Setup failed:', result.message);
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Setup error:', error);
    process.exit(1);
  }
}

// Run the setup
setupAppointmentReminders();
