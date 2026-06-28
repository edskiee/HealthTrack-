const express = require("express");
const router  = express.Router();
const appointmentSlotsController = require("../controllers/appointmentSlotsController");
const { authenticateAdmin, authenticateUser } = require("../middleware/auth");

// ─── Public / user-facing reads (Flutter app uses these for booking UI) ───────
router.get("/available",    appointmentSlotsController.getAvailableSlots);
router.get("/user-view",    appointmentSlotsController.getUserViewableSlots);
router.get("/availability", appointmentSlotsController.getSlotsAvailabilityForMonth);

// ─── User-authenticated ────────────────────────────────────────────────────────
router.post("/book", authenticateUser, appointmentSlotsController.bookSlot);

// ─── Admin-authenticated ───────────────────────────────────────────────────────
// Step 2: per-date detail with patient/appointment info (must be before /:id)
router.get("/date-detail",       authenticateAdmin, appointmentSlotsController.getDateDetail);

// Step 3: bulk-move all slots from one date to another
router.post("/reschedule-date",  authenticateAdmin, appointmentSlotsController.rescheduleDate);

// Step 4: regenerate slots for a date with new config (handles displaced bookings)
router.put("/edit-date",         authenticateAdmin, appointmentSlotsController.editDateSlots);

// General CRUD
router.get("/",        authenticateAdmin, appointmentSlotsController.getAllSlots);
router.post("/",       authenticateAdmin, appointmentSlotsController.createSlot);
router.put("/:id",     authenticateAdmin, appointmentSlotsController.updateSlot);
router.delete("/",     authenticateAdmin, appointmentSlotsController.deleteAllSlots);
router.delete("/:id",  authenticateAdmin, appointmentSlotsController.deleteSlot);

// Pre-delete bookings check
router.get("/:id/bookings", authenticateAdmin, appointmentSlotsController.getSlotBookings);

module.exports = router;
