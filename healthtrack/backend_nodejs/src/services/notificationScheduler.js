/**
 * Notification Scheduler Service
 * Handles automated scheduling and sending of appointment reminders
 * Uses cron-like functionality to check and send due reminders
 */

const cron = require('node-cron');
const { 
  checkAndSendDueReminders, 
  cleanupOldReminders,
  getSystemSettings 
} = require('./appointmentReminderService');
const { markMissedAppointments } = require('./missedAppointmentService');

let schedulerTasks = [];
let isSchedulerRunning = false;
const SCHEDULER_TIMEZONE = process.env.NOTIFICATION_TIMEZONE || 'Asia/Manila';

// Socket.IO instance — set once by startNotificationScheduler caller
let _io = null;

/**
 * Start the notification scheduler
 * @param {object|null} io  - Socket.IO server instance for real-time missed notifications
 */
async function startNotificationScheduler(io = null) {
  try {
    console.log('🚀 Starting notification scheduler...');
    
    // Store io reference for use in cron callbacks
    _io = io;

    // Stop any existing tasks
    stopNotificationScheduler();
    
    const settings = await getSystemSettings();
    
    if (!settings.appointment_reminders_enabled) {
      console.log('🔔 Appointment reminders disabled, scheduler not started');
      return { success: false, message: "Reminders disabled" };
    }
    
    // Schedule reminder checking every minute
    const reminderCheckTask = cron.schedule('* * * * *', async () => {
      try {
        await checkAndSendDueReminders();
      } catch (error) {
        console.error('❌ Error in scheduled reminder check:', error);
      }
    }, {
      scheduled: false,
      timezone: SCHEDULER_TIMEZONE
    });

    // Schedule missed-appointment sweep every 5 minutes
    // Runs independently of reminders — flips approved/pending/scheduled
    // appointments that are 30+ minutes past their scheduled time to no_show
    // and fires in-app + FCM notifications to the patient automatically.
    const missedCheckTask = cron.schedule('*/5 * * * *', async () => {
      try {
        await markMissedAppointments(_io);
      } catch (error) {
        console.error('❌ Error in missed appointment sweep:', error);
      }
    }, {
      scheduled: false,
      timezone: SCHEDULER_TIMEZONE
    });
    
    // Schedule cleanup every day at 2 AM
    const cleanupTask = cron.schedule('0 2 * * *', async () => {
      try {
        await cleanupOldReminders();
      } catch (error) {
        console.error('❌ Error in scheduled cleanup:', error);
      }
    }, {
      scheduled: false,
      timezone: SCHEDULER_TIMEZONE
    });
    
    // Start the tasks
    reminderCheckTask.start();
    missedCheckTask.start();
    cleanupTask.start();
    
    schedulerTasks = [reminderCheckTask, missedCheckTask, cleanupTask];
    isSchedulerRunning = true;
    
    console.log('✅ Notification scheduler started successfully');
    console.log('📅 Reminder checks: Every minute');
    console.log('🚫 Missed appointment sweep: Every 5 minutes');
    console.log(`🧹 Cleanup: Daily at 2:00 AM (${SCHEDULER_TIMEZONE})`);
    
    return { success: true, message: "Scheduler started successfully" };
    
  } catch (error) {
    console.error('❌ Error starting notification scheduler:', error);
    return { success: false, message: error.message };
  }
}

/**
 * Stop the notification scheduler
 */
function stopNotificationScheduler() {
  try {
    console.log('🛑 Stopping notification scheduler...');
    
    schedulerTasks.forEach(task => {
      if (task) {
        task.stop();
      }
    });
    
    schedulerTasks = [];
    isSchedulerRunning = false;
    
    console.log('✅ Notification scheduler stopped');
    return { success: true, message: "Scheduler stopped" };
    
  } catch (error) {
    console.error('❌ Error stopping notification scheduler:', error);
    return { success: false, message: error.message };
  }
}

/**
 * Get scheduler status
 */
function getSchedulerStatus() {
  return {
    isRunning: isSchedulerRunning,
    activeTasks: schedulerTasks.length,
    tasks: schedulerTasks.map((task, index) => ({
      id: index,
      running: task.running || false
    }))
  };
}

/**
 * Restart the scheduler
 */
async function restartNotificationScheduler() {
  console.log('🔄 Restarting notification scheduler...');
  stopNotificationScheduler();
  await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
  return await startNotificationScheduler();
}

/**
 * Manual trigger for reminder check (for testing)
 */
async function manualReminderCheck() {
  console.log('🔧 Manual reminder check triggered');
  return await checkAndSendDueReminders();
}

/**
 * Manual trigger for cleanup (for testing)
 */
async function manualCleanup() {
  console.log('🔧 Manual cleanup triggered');
  return await cleanupOldReminders();
}

/**
 * Manual trigger for missed appointment sweep (for testing)
 */
async function manualMissedCheck(io = null) {
  console.log('🔧 Manual missed appointment sweep triggered');
  return await markMissedAppointments(io || _io);
}

module.exports = {
  startNotificationScheduler,
  stopNotificationScheduler,
  getSchedulerStatus,
  restartNotificationScheduler,
  manualReminderCheck,
  manualCleanup,
  manualMissedCheck,
};
