const express = require("express");
const {
  getHealthRecords,
  getAllPatientsWithRecords,
  addHealthRecord,
  updateHealthRecord,
  deleteHealthRecord,
  getPatientHealthRecords,
  getHealthRecordById,
} = require("../controllers/healthRecordsController");
const { authenticateAdmin, authenticateUser } = require("../middleware/auth");

const router = express.Router();

// ── Patient-facing route (uses user JWT) ──────────────────────────────────────
// Regular logged-in users fetch their own health records with their JWT token.
router.get("/patient/:patientId", authenticateUser, getPatientHealthRecords);

// ── Admin-only routes (uses admin session token) ──────────────────────────────
router.get("/",              authenticateAdmin, getHealthRecords);
router.get("/all-patients",  authenticateAdmin, getAllPatientsWithRecords);
router.get("/:id",           authenticateAdmin, getHealthRecordById);
router.post("/",             authenticateAdmin, addHealthRecord);
router.put("/:id",           authenticateAdmin, updateHealthRecord);
router.delete("/:id",        authenticateAdmin, deleteHealthRecord);

module.exports = router;
