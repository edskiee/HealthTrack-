const express = require("express");
const router  = express.Router();
const {
  getDashboardStats,
  getRecentActivities,
  getTodayAppointments,
  getWeeklyAppointments,
  getBabyConditions,
  getAgeDistribution,
  getGenderDistribution,
  getLocationDistribution,
  getServiceTypeDistribution,
  emitUpdate,
} = require("../controllers/dashboardController");
const { authenticateAdmin } = require("../middleware/auth");

// All dashboard endpoints are admin-only — they expose aggregate patient data
router.use(authenticateAdmin);

router.get("/stats",                  getDashboardStats);
router.get("/activities",             getRecentActivities);
router.get("/appointments",           getTodayAppointments);
router.get("/weekly-appointments",    getWeeklyAppointments);
router.get("/baby-conditions",        getBabyConditions);
router.get("/age-distribution",       getAgeDistribution);
router.get("/gender-distribution",    getGenderDistribution);
router.get("/location-distribution",  getLocationDistribution);
router.get("/service-type-distribution", getServiceTypeDistribution);
router.post("/emit-update",           emitUpdate);

module.exports = router;
