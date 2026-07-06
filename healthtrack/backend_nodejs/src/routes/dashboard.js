const express    = require("express");
const router     = express.Router();
const rateLimit  = require("express-rate-limit");
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
  // New reports endpoints (Steps 1–6, 8–9)
  getDohForm1Data,
  getImmunizationPatientsV2,
  getImmunizationCoverage,
  getOverdueByBarangay,
  getMonthlyAppointmentsBreakdown,
  getBarangayBreakdown,
  // Cache helper — wraps handlers with 5-min in-memory cache + volume tracking
  withCache,
} = require("../controllers/dashboardController");
const { authenticateAdmin } = require("../middleware/auth");

// ── Reports-specific rate limiter ─────────────────────────────────────────────
// Each report page load fires up to 13 parallel requests.  Allow max 10 req/min
// per IP so a single admin with multiple tabs cannot overload the server.
// The general limiter (300/15 min) still applies on top of this.
const reportsLimiter = rateLimit({
  windowMs:        60 * 1000, // 1 minute window
  max:             10,        // max 10 requests per minute per IP
  standardHeaders: true,
  legacyHeaders:   false,
  keyGenerator:    (req) => req.ip,  // per-IP, not per-token
  handler: (req, res) => {
    console.warn(
      `⚠️  Reports rate-limit triggered — IP: ${req.ip}  endpoint: ${req.path}`
    );
    res.status(429).json({
      success: false,
      message: "Too many requests to reports. Please wait a moment before refreshing.",
    });
  },
});

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

// Reports — rate-limited (10 req/min) + 5-minute server-side cache
router.get("/reports/immunization-monthly",  reportsLimiter, withCache(getImmunizationMonthlyCounts));
router.get("/reports/prenatal-monthly",      reportsLimiter, withCache(getPrenatalMonthlyCounts));
router.get("/reports/vaccine-distribution",  reportsLimiter, withCache(getVaccineDistribution));
router.get("/reports/trimester-distribution",reportsLimiter, withCache(getTrimesterDistribution));
router.get("/reports/immunization-patients", reportsLimiter, withCache(getImmunizationPatients));
router.get("/reports/prenatal-patients",     reportsLimiter, withCache(getPrenatalPatients));

// New reports endpoints (Steps 1–6, 8–9)
router.get("/reports/doh-form1",                   reportsLimiter, withCache(getDohForm1Data));
router.get("/reports/immunization-patients-v2",    reportsLimiter, withCache(getImmunizationPatientsV2));
router.get("/reports/immunization-coverage",       reportsLimiter, withCache(getImmunizationCoverage));
router.get("/reports/overdue-by-barangay",         reportsLimiter, withCache(getOverdueByBarangay));
router.get("/reports/monthly-appointments",        reportsLimiter, withCache(getMonthlyAppointmentsBreakdown));
router.get("/reports/barangay-breakdown",          reportsLimiter, withCache(getBarangayBreakdown));

module.exports = router;
