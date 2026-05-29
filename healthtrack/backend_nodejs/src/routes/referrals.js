const express = require('express');
const router = express.Router();
const referralsController = require('../controllers/referralsController');

// POST /referrals - Create a new referral
router.post('/', referralsController.createReferral);

// GET /referrals/patient/:patient_id - Get referrals for a specific patient
router.get('/patient/:patient_id', referralsController.getPatientReferrals);

// GET /referrals - Get all referrals (admin only)
router.get('/', referralsController.getAllReferrals);

// PUT /referrals/:id/status - Update referral status
router.put('/:id/status', referralsController.updateReferralStatus);

// DELETE /referrals/:id - Delete a referral
router.delete('/:id', referralsController.deleteReferral);

module.exports = router;
