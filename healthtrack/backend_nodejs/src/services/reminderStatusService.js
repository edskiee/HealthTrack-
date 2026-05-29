/**
 * Service to determine reminder status for users
 */

/**
 * Determine the status of a user's reminders
 * @param {Object} user - User object with reminder information
 * @returns {string} - Status: 'Pending', 'Reminded', or 'Overdue'
 */
function getUserReminderStatus(user) {
  const now = new Date();
  
  // If no reminders exist, return Pending
  if (!user.nextReminder && !user.lastReminder) {
    return 'Pending';
  }
  
  // If there's a next reminder and it's in the future, return Pending
  if (user.nextReminder) {
    const nextReminderDate = new Date(`${user.nextReminder.date} ${user.nextReminder.time}`);
    if (nextReminderDate > now) {
      return 'Pending';
    }
  }
  
  // If there's a last reminder and it's in the past, check if it was reminded
  if (user.lastReminder) {
    const lastReminderDate = new Date(`${user.lastReminder.date} ${user.lastReminder.time}`);
    
    // If last reminder was in the past, check if it was reminded recently
    if (lastReminderDate < now) {
      // Check if there was a notification sent for this reminder
      // For now, we'll assume if there's a last reminder, it was reminded
      return 'Reminded';
    }
  }
  
  // If next reminder is in the past (overdue), return Overdue
  if (user.nextReminder) {
    const nextReminderDate = new Date(`${user.nextReminder.date} ${user.nextReminder.time}`);
    if (nextReminderDate < now) {
      return 'Overdue';
    }
  }
  
  return 'Pending';
}

/**
 * Calculate days until next reminder
 * @param {Object} nextReminder - Next reminder object
 * @returns {number} - Days until next reminder (negative if overdue)
 */
function getDaysUntilNextReminder(nextReminder) {
  if (!nextReminder) return null;
  
  const now = new Date();
  const nextReminderDate = new Date(`${nextReminder.date} ${nextReminder.time}`);
  const diffTime = nextReminderDate - now;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  return diffDays;
}

module.exports = {
  getUserReminderStatus,
  getDaysUntilNextReminder
};