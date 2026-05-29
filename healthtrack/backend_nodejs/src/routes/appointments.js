const express = require('express');
const router = express.Router();
const appointmentsController = require('../controllers/appointmentsController');

// Get all appointments (for admin)
router.get('/', appointmentsController.getAllAppointments);

// Get pending appointments count (for admin notifications)
router.get('/pending-count', appointmentsController.getPendingAppointmentsCount);

// Get appointments for a specific user
router.get('/user/:userId', appointmentsController.getUserAppointments);

// Get appointments for current user (simplified endpoint)
router.get('/user', appointmentsController.getCurrentUserAppointments);

// Get upcoming approved appointments for a specific user (for dashboard)
router.get('/user/:userId/upcoming', appointmentsController.getUserUpcomingAppointments);

// Get next appointment for a specific patient
router.get('/next/:patientId', appointmentsController.getNextAppointment);

// Get upcoming appointments (for admin dashboard)
router.get('/upcoming', appointmentsController.getUpcomingAppointments);

// Add new appointment
router.post('/', appointmentsController.addAppointment);

// Update appointment status (approve, cancel, reschedule)
router.put('/status/:id', appointmentsController.updateAppointmentStatus);

// Get appointment notifications for a user
router.get('/notifications/:userId', appointmentsController.getUserNotifications);

// Get unread notifications count for a user
router.get('/notifications/:userId/unread-count', appointmentsController.getUnreadNotificationsCount);

// Mark notification as read
router.put('/notifications/:id/read', appointmentsController.markNotificationAsRead);

// Delete an appointment
router.delete('/:id', appointmentsController.deleteAppointment);

// Get consultation types
router.get('/consultation-types', appointmentsController.getConsultationTypes);

module.exports = router;