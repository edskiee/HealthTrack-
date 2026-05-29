const express = require('express');
const router = express.Router();
const healthTipsController = require('../controllers/healthTipsController');

// Get health tips by category
router.get('/:category', healthTipsController.getHealthTipsByCategory);

// Get all health tips
router.get('/', healthTipsController.getAllHealthTips);

// Add new health tip (admin function)
router.post('/', healthTipsController.addHealthTip);

// Update health tip (admin function)
router.put('/:id', healthTipsController.updateHealthTip);

// Delete health tip (admin function)
router.delete('/:id', healthTipsController.deleteHealthTip);

module.exports = router;