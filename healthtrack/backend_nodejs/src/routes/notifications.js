const express = require("express");
const router = express.Router();
const notificationsController = require("../controllers/notificationsController");
const { authenticateUser } = require("../middleware/auth");

// All notification routes require user authentication
router.use(authenticateUser);

router.get("/user/:userId",                  notificationsController.getUserNotifications);
router.get("/user/:userId/unread-count",     notificationsController.getUnreadNotificationsCount);
router.put("/:id/read",                      notificationsController.markNotificationAsRead);
router.put("/user/:userId/mark-all-read",    notificationsController.markAllNotificationsAsRead);
router.delete("/:id",                        notificationsController.deleteNotification);

module.exports = router;
