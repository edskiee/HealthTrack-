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
  // Reports endpoints
  getImmunizationMonthlyCounts,
  getPrenatalMonthlyCounts,
  getVaccineDistribution,
  getTrimesterDistribution,
  getImmunizationPatients,
  getPrenatalPatients,
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

// Reports
router.get("/reports/immunization-monthly",  getImmunizationMonthlyCounts);
router.get("/reports/prenatal-monthly",      getPrenatalMonthlyCounts);
router.get("/reports/vaccine-distribution",  getVaccineDistribution);
router.get("/reports/trimester-distribution",getTrimesterDistribution);
router.get("/reports/immunization-patients", getImmunizationPatients);
router.get("/reports/prenatal-patients",     getPrenatalPatients);

module.exports = router;
