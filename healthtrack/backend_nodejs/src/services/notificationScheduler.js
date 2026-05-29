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

let schedulerTasks = [];
let isSchedulerRunning = false;
const SCHEDULER_TIMEZONE = process.env.NOTIFICATION_TIMEZONE || 'Asia/Manila';

/**
 * Start the notification scheduler
 */
async function startNotificationScheduler() {
  try {
    console.log('🚀 Starting notification scheduler...');
    
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
    cleanupTask.start();
    
    schedulerTasks = [reminderCheckTask, cleanupTask];
    isSchedulerRunning = true;
    
    console.log('✅ Notification scheduler started successfully');
    console.log('📅 Reminder checks: Every minute');
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

module.exports = {
  startNotificationScheduler,
  stopNotificationScheduler,
  getSchedulerStatus,
  restartNotificationScheduler,
  manualReminderCheck,
  manualCleanup
};
