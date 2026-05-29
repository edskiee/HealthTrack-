const express = require('express');
const router = express.Router();
const serviceConfigController = require('../controllers/serviceConfigController');

// Get all active services
router.get('/', serviceConfigController.getAllServices);

// Get service by ID
router.get('/:id', serviceConfigController.getServiceById);

// Create new service (admin only)
router.post('/', serviceConfigController.createService);

// Update service (admin only)
router.put('/:id', serviceConfigController.updateService);

// Delete service (admin only)
router.delete('/:id', serviceConfigController.deleteService);

module.exports = router;