const db = require('../config/db');
const { scheduleFcmNotifications } = require('../services/scheduledNotificationService');

// Get all reminders for a user
const getUserReminders = async (req, res) => {
    try {
        const { userId } = req.params;
        
        const query = `
            SELECT * FROM reminders 
            WHERE user_id = ? 
            ORDER BY reminder_date ASC, reminder_time ASC
        `;
        
        const [reminders] = await db.query(query, [userId]);
        res.json({ success: true, data: reminders });
    } catch (error) {
        console.error('Error fetching reminders:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch reminders' });
    }
};

// Get reminders for a specific date
const getDateReminders = async (req, res) => {
    try {
        const { userId, date } = req.params;
        
        const query = `
            SELECT * FROM reminders 
            WHERE user_id = ? AND reminder_date = ?
            ORDER BY reminder_time ASC
        `;
        
        const [reminders] = await db.query(query, [userId, date]);
        res.json({ success: true, data: reminders });
    } catch (error) {
        console.error('Error fetching date reminders:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch reminders for date' });
    }
};

// Create a new reminder
const createReminder = async (req, res) => {
    try {
        const { userId } = req.params;
        const { title, category, reminderDate, reminderTime, isRepeating, repeatInterval, repeatDays, notes } = req.body;
        
        const query = `
            INSERT INTO reminders 
            (user_id, title, category, reminder_date, reminder_time, is_repeating, repeat_interval, repeat_days, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        
        const [result] = await db.query(query, [
            userId, 
            title, 
            category || 'custom_reminder',
            reminderDate, 
            reminderTime || null, 
            isRepeating || false, 
            repeatInterval || null, 
            repeatDays ? JSON.stringify(repeatDays) : null,
            notes || null
        ]);
        
        // Schedule FCM notifications for this reminder
        await scheduleFcmNotifications(userId, title, reminderDate);
        
        res.json({ 
            success: true, 
            message: 'Reminder created successfully',
            data: { id: result.insertId }
        });
    } catch (error) {
        console.error('Error creating reminder:', error);
        res.status(500).json({ success: false, message: 'Failed to create reminder' });
    }
};

// Update a reminder
const updateReminder = async (req, res) => {
    try {
        const { reminderId } = req.params;
        const { title, category, reminderDate, reminderTime, isRepeating, repeatInterval, repeatDays, notes } = req.body;
        
        const query = `
            UPDATE reminders 
            SET title = ?, category = ?, reminder_date = ?, reminder_time = ?, 
                is_repeating = ?, repeat_interval = ?, repeat_days = ?, notes = ?
            WHERE id = ?
        `;
        
        await db.query(query, [
            title, 
            category || 'custom_reminder',
            reminderDate, 
            reminderTime || null, 
            isRepeating || false, 
            repeatInterval || null, 
            repeatDays ? JSON.stringify(repeatDays) : null,
            notes || null,
            reminderId
        ]);
        
        res.json({ success: true, message: 'Reminder updated successfully' });
    } catch (error) {
        console.error('Error updating reminder:', error);
        res.status(500).json({ success: false, message: 'Failed to update reminder' });
    }
};

// Delete a reminder
const deleteReminder = async (req, res) => {
    try {
        const { reminderId } = req.params;
        
        const query = 'DELETE FROM reminders WHERE id = ?';
        await db.query(query, [reminderId]);
        
        res.json({ success: true, message: 'Reminder deleted successfully' });
    } catch (error) {
        console.error('Error deleting reminder:', error);
        res.status(500).json({ success: false, message: 'Failed to delete reminder' });
    }
};

module.exports = {
    getUserReminders,
    getDateReminders,
    createReminder,
    updateReminder,
    deleteReminder
};