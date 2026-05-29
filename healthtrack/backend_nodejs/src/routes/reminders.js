const express = require('express');
const router = express.Router();
const remindersController = require('../controllers/remindersController');

// Get all reminders for a user
router.get('/user/:userId', remindersController.getUserReminders);

// Get reminders for a specific date
router.get('/user/:userId/date/:date', remindersController.getDateReminders);

// Create a new reminder
router.post('/user/:userId', remindersController.createReminder);

// Update a reminder
router.put('/:reminderId', remindersController.updateReminder);

// Delete a reminder
router.delete('/:reminderId', remindersController.deleteReminder);

module.exports = router;