const express = require("express");
const router = express.Router();
const appointmentsController = require("../controllers/appointmentsController");
const { authenticateUser, authenticateAdmin, optionalAuthUser } = require("../middleware/auth");

// ─── Public / optional-auth ──────────────────────────────────────────────────
router.get("/consultation-types", appointmentsController.getConsultationTypes);

// ─── User-authenticated routes ───────────────────────────────────────────────
router.get("/user",                    authenticateUser, appointmentsController.getCurrentUserAppointments);
router.get("/user/:userId",            authenticateUser, appointmentsController.getUserAppointments);
router.get("/user/:userId/upcoming",   authenticateUser, appointmentsController.getUserUpcomingAppointments);
router.get("/next/:patientId",         authenticateUser, appointmentsController.getNextAppointment);
router.post("/",                       authenticateUser, appointmentsController.addAppointment);
router.get("/notifications/:userId",   authenticateUser, appointmentsController.getUserNotifications);
router.get("/notifications/:userId/unread-count", authenticateUser, appointmentsController.getUnreadNotificationsCount);
router.put("/notifications/:id/read",  authenticateUser, appointmentsController.markNotificationAsRead);

// ─── Admin-authenticated routes ──────────────────────────────────────────────
router.get("/",                        authenticateAdmin, appointmentsController.getAllAppointments);
router.get("/pending-count",           authenticateAdmin, appointmentsController.getPendingAppointmentsCount);
router.get("/upcoming",                authenticateAdmin, appointmentsController.getUpcomingAppointments);
router.put("/status/:id",              authenticateAdmin, appointmentsController.updateAppointmentStatus);
router.put("/complete-with-dose/:id",  authenticateAdmin, appointmentsController.completeAppointmentWithDose);
router.delete("/:id",                  authenticateAdmin, appointmentsController.deleteAppointment);

module.exports = router;
