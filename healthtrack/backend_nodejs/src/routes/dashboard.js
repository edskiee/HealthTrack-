const express = require("express");
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
  emitUpdate
} = require("../controllers/dashboardController");

const router = express.Router();

router.get("/stats", getDashboardStats);
router.get("/activities", getRecentActivities);
router.get("/appointments", getTodayAppointments);
router.get("/weekly-appointments", getWeeklyAppointments);
router.get("/baby-conditions", getBabyConditions);
router.get("/age-distribution", getAgeDistribution);
router.get("/gender-distribution", getGenderDistribution);
router.get("/location-distribution", getLocationDistribution);
router.get("/service-type-distribution", getServiceTypeDistribution);
router.post("/emit-update", emitUpdate);

module.exports = router;