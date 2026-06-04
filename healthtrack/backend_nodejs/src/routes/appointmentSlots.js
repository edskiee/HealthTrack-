const express = require("express");
const router  = express.Router();
const appointmentSlotsController = require("../controllers/appointmentSlotsController");
const { authenticateAdmin, authenticateUser } = require("../middleware/auth");

// ─── Public / user-facing reads (Flutter app uses these for booking UI) ───────
router.get("/available",   appointmentSlotsController.getAvailableSlots);
router.get("/user-view",   appointmentSlotsController.getUserViewableSlots);
router.get("/availability", appointmentSlotsController.getSlotsAvailabilityForMonth);

// ─── User-authenticated ────────────────────────────────────────────────────────
router.post("/book", authenticateUser, appointmentSlotsController.bookSlot);

// ─── Admin-authenticated ───────────────────────────────────────────────────────
router.get("/",        authenticateAdmin, appointmentSlotsController.getAllSlots);
router.post("/",       authenticateAdmin, appointmentSlotsController.createSlot);
router.put("/:id",     authenticateAdmin, appointmentSlotsController.updateSlot);
router.delete("/",     authenticateAdmin, appointmentSlotsController.deleteAllSlots);
router.delete("/:id",  authenticateAdmin, appointmentSlotsController.deleteSlot);

module.exports = router;
