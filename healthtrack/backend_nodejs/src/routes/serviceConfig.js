const express = require("express");
const router  = express.Router();
const serviceConfigController = require("../controllers/serviceConfigController");
const { authenticateAdmin } = require("../middleware/auth");

// Read — public (app needs service list for booking without being logged in)
router.get("/",    serviceConfigController.getAllServices);
router.get("/:id", serviceConfigController.getServiceById);

// Write — admin only
router.post("/",    authenticateAdmin, serviceConfigController.createService);
router.put("/:id",  authenticateAdmin, serviceConfigController.updateService);
router.delete("/:id", authenticateAdmin, serviceConfigController.deleteService);

module.exports = router;
