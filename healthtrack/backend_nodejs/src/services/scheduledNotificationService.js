const db = require('../config/db');
const { sendPushNotification, normalizeFcmToken, validateFcmTokenWithFirebase } = require('./firebaseService');
const { isUserPushEnabled } = require('./pushNotificationPolicy');

/**
 * Schedule FCM notifications for 3 days leading up to a reminder date
 * @param {number} userId - User ID
 * @param {string} reminderTitle - Reminder title
 * @param {string} reminderDate - Reminder date in YYYY-MM-DD format
 * @returns {Promise<void>}
 */
async function scheduleFcmNotifications(userId, reminderTitle, reminderDate) {
    try {
        console.log(`📅 Scheduling FCM notifications for user ${userId}, reminder: ${reminderTitle}, date: ${reminderDate}`);
        
        // Get user's FCM token
        const [userResult] = await db.execute('SELECT fcm_token FROM users WHERE id = ?', [userId]);
        
        if (userResult.length === 0 || !userResult[0].fcm_token) {
            console.warn(`⚠️ No FCM token found for user ${userId}`);
            return;
        }
        
        const fcmToken = userResult[0].fcm_token;
        const normalizedToken = normalizeFcmToken(fcmToken);
        console.log(`✅ Found FCM token for user ${userId}: ${normalizedToken.substring(0, 20)}...`);

        // If token was corrupted (e.g., wrapped in quotes), normalize it in DB
        if (normalizedToken !== fcmToken) {
            try {
                await db.execute('UPDATE users SET fcm_token = ? WHERE id = ?', [normalizedToken, userId]);
                console.log(`🔧 Normalized stored FCM token for user ${userId}`);
            } catch (e) {
                console.warn(`⚠️ Failed to normalize stored token for user ${userId}:`, e?.message || e);
            }
        }

        // Validate token with Firebase (dry-run) before scheduling; scrub if rejected
        const validation = await validateFcmTokenWithFirebase(normalizedToken);
        if (!validation.success) {
            console.warn(`🗑️ Stored FCM token rejected by Firebase for user ${userId} (${validation.code}). Clearing token.`);
            await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [userId]);
            return;
        }
        
        // Parse reminder date with timezone handling
        const reminderDateObj = new Date(reminderDate + 'T00:00:00.000Z'); // Ensure UTC parsing
        const now = new Date();
        
        // Validate that reminder date is in the future
        if (reminderDateObj <= now) {
            console.warn(`⚠️ Reminder date ${reminderDate} is not in the future, skipping scheduling`);
            return;
        }
        
        // Schedule notifications for 3, 2, and 1 day before
        const threeDaysBefore = new Date(reminderDateObj);
        threeDaysBefore.setDate(reminderDateObj.getDate() - 3);
        
        const twoDaysBefore = new Date(reminderDateObj);
        twoDaysBefore.setDate(reminderDateObj.getDate() - 2);
        
        const oneDayBefore = new Date(reminderDateObj);
        oneDayBefore.setDate(reminderDateObj.getDate() - 1);
        
        // Store scheduled notifications in database
        const insertQuery = `
            INSERT INTO scheduled_notifications 
            (user_id, fcm_token, notification_type, title, message, scheduled_time, is_sent, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        `;
        
        let scheduledCount = 0;
        
        // Schedule 3 days before notification
        if (threeDaysBefore > now) {
            const title = "Appointment Reminder";
            const message = `3 days to go: ${reminderTitle}`;
            try {
                await db.execute(insertQuery, [
                    userId, 
                    fcmToken, 
                    'reminder_3_days', 
                    title, 
                    message, 
                    threeDaysBefore.toISOString().slice(0, 19).replace('T', ' '), 
                    false
                ]);
                console.log(`✅ Scheduled 3-day reminder notification for ${threeDaysBefore.toISOString().slice(0, 10)}`);
                scheduledCount++;
            } catch (err) {
                console.error(`❌ Failed to schedule 3-day reminder:`, err);
            }
        }
        
        // Schedule 2 days before notification
        if (twoDaysBefore > now) {
            const title = "Appointment Reminder";
            const message = `2 days to go: ${reminderTitle}`;
            try {
                await db.execute(insertQuery, [
                    userId, 
                    fcmToken, 
                    'reminder_2_days', 
                    title, 
                    message, 
                    twoDaysBefore.toISOString().slice(0, 19).replace('T', ' '), 
                    false
                ]);
                console.log(`✅ Scheduled 2-day reminder notification for ${twoDaysBefore.toISOString().slice(0, 10)}`);
                scheduledCount++;
            } catch (err) {
                console.error(`❌ Failed to schedule 2-day reminder:`, err);
            }
        }
        
        // Schedule 1 day before notification
        if (oneDayBefore > now) {
            const title = "Appointment Reminder";
            const message = `1 day to go: ${reminderTitle}`;
            try {
                await db.execute(insertQuery, [
                    userId, 
                    fcmToken, 
                    'reminder_1_day', 
                    title, 
                    message, 
                    oneDayBefore.toISOString().slice(0, 19).replace('T', ' '), 
                    false
                ]);
                console.log(`✅ Scheduled 1-day reminder notification for ${oneDayBefore.toISOString().slice(0, 10)}`);
                scheduledCount++;
            } catch (err) {
                console.error(`❌ Failed to schedule 1-day reminder:`, err);
            }
        }
        
        console.log(`✅ Successfully scheduled ${scheduledCount} FCM notifications for reminder: ${reminderTitle}`);
    } catch (error) {
        console.error('❌ Error scheduling FCM notifications:', error);
    }
}

/**
 * Send scheduled notifications that are due
 * @returns {Promise<void>}
 */
async function sendDueNotifications() {
    try {
        console.log('🔍 Checking for due scheduled notifications...');
        
        const now = new Date();
        const nowFormatted = now.toISOString().slice(0, 19).replace('T', ' ');
        
        // Get notifications that are due and not yet sent
        const selectQuery = `
            SELECT * FROM scheduled_notifications 
            WHERE scheduled_time <= ? AND is_sent = 0
            ORDER BY scheduled_time ASC
        `;
        
        const [notifications] = await db.execute(selectQuery, [nowFormatted]);
        
        console.log(`📬 Found ${notifications.length} due notifications to send`);
        
        // Send each notification
        for (const notification of notifications) {
            try {
                if (!(await isUserPushEnabled(notification.user_id))) {
                    console.log(`// DEBUG scheduled notification skipped: user ${notification.user_id} push disabled id=${notification.id}`);
                    await db.execute(
                        'UPDATE scheduled_notifications SET is_sent = 1, sent_at = ? WHERE id = ?',
                        [nowFormatted, notification.id]
                    );
                    continue;
                }

                const payload = {
                    title: notification.title,
                    body: notification.message,
                    data: {
                        notificationId: notification.id.toString(),
                        userId: notification.user_id.toString(),
                        type: notification.notification_type,
                        timestamp: new Date().toISOString()
                    }
                };

                console.log(`// DEBUG scheduled notification send id=${notification.id} userId=${notification.user_id}`);
                const result = await sendPushNotification(notification.fcm_token, payload, notification.user_id);
                
                if (result.success) {
                    // Mark notification as sent
                    await db.execute(
                        'UPDATE scheduled_notifications SET is_sent = 1, sent_at = ? WHERE id = ?', 
                        [nowFormatted, notification.id]
                    );
                    console.log(`✅ Sent scheduled notification ${notification.id}`);
                } else {
                    console.warn(`⚠️ Failed to send scheduled notification ${notification.id}: ${result.error}`);
                    
                    // If it's an invalid token error, we should clear it from the user record
                    if (result.code === 'messaging/invalid-registration-token' || 
                        result.code === 'messaging/registration-token-not-registered' ||
                        result.code === 'invalid-argument') {
                        console.log(`🗑️ Clearing invalid FCM token for user ${notification.user_id}`);
                        await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [notification.user_id]);
                        await db.execute(
                            'UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?',
                            [notification.fcm_token]
                        );
                    }
                }
            } catch (sendError) {
                console.error(`❌ Error sending scheduled notification ${notification.id}:`, sendError);
            }
        }
    } catch (error) {
        console.error('❌ Error sending due notifications:', error);
    }
}

/**
 * Create the scheduled_notifications table if it doesn't exist
 * @returns {Promise<void>}
 */
async function createScheduledNotificationsTable() {
    try {
        const createTableQuery = `
            CREATE TABLE IF NOT EXISTS scheduled_notifications (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                fcm_token VARCHAR(500) NOT NULL,
                notification_type VARCHAR(50) NOT NULL,
                title VARCHAR(255) NOT NULL,
                message TEXT NOT NULL,
                scheduled_time DATETIME NOT NULL,
                is_sent BOOLEAN DEFAULT FALSE,
                sent_at DATETIME NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                INDEX idx_user_id (user_id),
                INDEX idx_scheduled_time (scheduled_time),
                INDEX idx_is_sent (is_sent),
                INDEX idx_created_at (created_at),
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `;
        
        await db.execute(createTableQuery);
        console.log('✅ Scheduled notifications table created or already exists');
    } catch (error) {
        console.error('❌ Error creating scheduled notifications table:', error);
    }
}

module.exports = {
    scheduleFcmNotifications,
    sendDueNotifications,
    createScheduledNotificationsTable
};
