const express = require('express');
const router = express.Router();
const appointmentSlotsController = require('../controllers/appointmentSlotsController');

// Get all appointment slots (admin)
router.get('/', appointmentSlotsController.getAllSlots);

// Get available appointment slots for users
router.get('/available', appointmentSlotsController.getAvailableSlots);

// Get user-viewable slots (shows all slots including booked ones for calendar display)
router.get('/user-view', appointmentSlotsController.getUserViewableSlots);

// Get slots availability for a month (for user calendar)
router.get('/availability', appointmentSlotsController.getSlotsAvailabilityForMonth);

// Create new appointment slot (admin)
router.post('/', appointmentSlotsController.createSlot);

// Update appointment slot (admin)
router.put('/:id', appointmentSlotsController.updateSlot);

// Delete appointment slot (admin)
router.delete('/:id', appointmentSlotsController.deleteSlot);

// Delete all appointment slots (admin)
router.delete('/', appointmentSlotsController.deleteAllSlots);

// Book an appointment slot (user)
router.post('/book', appointmentSlotsController.bookSlot);

module.exports = router;