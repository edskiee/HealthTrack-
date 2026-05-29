const express = require('express');
const router = express.Router();
const notificationsController = require('../controllers/notificationsController');

// Get notifications for a user
router.get('/user/:userId', notificationsController.getUserNotifications);

// Get unread notifications count for a user
router.get('/user/:userId/unread-count', notificationsController.getUnreadNotificationsCount);

// Mark notification as read
router.put('/:id/read', notificationsController.markNotificationAsRead);

// Mark all notifications as read for a user
router.put('/user/:userId/mark-all-read', notificationsController.markAllNotificationsAsRead);

// Delete notification
router.delete('/:id', notificationsController.deleteNotification);

module.exports = router;