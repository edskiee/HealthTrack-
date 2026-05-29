#!/usr/bin/env node

/**
 * Script to check and send scheduled notifications
 * This script should be run periodically (e.g., every minute) to check for due notifications
 */

const { sendDueNotifications, createScheduledNotificationsTable } = require('./src/services/scheduledNotificationService');
const db = require('./src/config/db');

async function run() {
    try {
        console.log('🚀 Starting scheduled notifications check...');
        
        // Ensure the scheduled_notifications table exists
        await createScheduledNotificationsTable();
        
        // Send any due notifications
        await sendDueNotifications();
        
        console.log('✅ Scheduled notifications check completed');
    } catch (error) {
        console.error('❌ Error in scheduled notifications check:', error);
    } finally {
        // Close the database connection
        if (db && typeof db.end === 'function') {
            await db.end();
        }
        process.exit(0);
    }
}

// Run the script
run();