const express = require("express");
const { 
  userRegister, 
  checkUsername, 
  checkEmail, 
  userLogin,
  saveFcmToken,
  checkUserFcmToken,
  removeInvalidFcmToken,
  getPushNotificationPreference,
  updatePushNotificationPreference
} = require("../controllers/authController");

const router = express.Router();

router.post("/register", userRegister);
router.get("/check-username", checkUsername);
router.get("/check-email", checkEmail);
router.post("/login", userLogin);
router.post("/save-fcm-token", saveFcmToken);
router.get("/check-fcm-token/:userId", checkUserFcmToken);
router.post("/remove-invalid-fcm-token", removeInvalidFcmToken);
router.get("/push-notification-preference/:userId", getPushNotificationPreference);
router.put("/push-notification-preference", updatePushNotificationPreference);

module.exports = router;