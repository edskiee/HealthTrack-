const express = require("express");
const {
  getHealthRecords,
  getAllPatientsWithRecords,
  addHealthRecord,
  updateHealthRecord,
  deleteHealthRecord,
  getPatientHealthRecords,
  getHealthRecordById
} = require("../controllers/healthRecordsController");

const router = express.Router();

// Get all health records with patient information
router.get("/", getHealthRecords);

// Get all patients with their health records (including patients with no records)
router.get("/all-patients", getAllPatientsWithRecords);

// Get health records by patient ID
router.get("/patient/:patientId", getPatientHealthRecords);

// Get a specific health record by ID
router.get("/:id", getHealthRecordById);

// Add new health record
router.post("/", addHealthRecord);

// Update health record
router.put("/:id", updateHealthRecord);

// Delete health record
router.delete("/:id", deleteHealthRecord);

module.exports = router;