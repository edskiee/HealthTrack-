const express = require("express");
const router  = express.Router();
const referralsController = require("../controllers/referralsController");
const { authenticateAdmin, authenticateUser } = require("../middleware/auth");

// Read referrals — user can see their own patient's referrals
router.get("/patient/:patient_id", authenticateUser,  referralsController.getPatientReferrals);

// Admin-only operations
router.get("/",             authenticateAdmin, referralsController.getAllReferrals);
router.post("/",            authenticateAdmin, referralsController.createReferral);
router.put("/:id/status",  authenticateAdmin, referralsController.updateReferralStatus);
router.delete("/:id",      authenticateAdmin, referralsController.deleteReferral);

module.exports = router;
