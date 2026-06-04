const express = require("express");
const router  = express.Router();
const healthTipsController = require("../controllers/healthTipsController");
const { authenticateAdmin } = require("../middleware/auth");

// Read — public (Flutter app fetches tips without login)
router.get("/:category", healthTipsController.getHealthTipsByCategory);
router.get("/",          healthTipsController.getAllHealthTips);

// Write — admin only
router.post("/",    authenticateAdmin, healthTipsController.addHealthTip);
router.put("/:id",  authenticateAdmin, healthTipsController.updateHealthTip);
router.delete("/:id", authenticateAdmin, healthTipsController.deleteHealthTip);

module.exports = router;
