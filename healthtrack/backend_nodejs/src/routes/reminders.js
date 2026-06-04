const express = require("express");
const router = express.Router();
const remindersController = require("../controllers/remindersController");
const { authenticateUser } = require("../middleware/auth");

// All reminder routes require user authentication
router.use(authenticateUser);

router.get("/user/:userId",            remindersController.getUserReminders);
router.get("/user/:userId/date/:date", remindersController.getDateReminders);
router.post("/user/:userId",           remindersController.createReminder);
router.put("/:reminderId",             remindersController.updateReminder);
router.delete("/:reminderId",          remindersController.deleteReminder);

module.exports = router;
