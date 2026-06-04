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
const { authenticateAdmin } = require("../middleware/auth");

const router = express.Router();

// All health record routes require admin authentication
router.use(authenticateAdmin);

router.get("/",              getHealthRecords);
router.get("/all-patients",  getAllPatientsWithRecords);
router.get("/patient/:patientId", getPatientHealthRecords);
router.get("/:id",           getHealthRecordById);
router.post("/",             addHealthRecord);
router.put("/:id",           updateHealthRecord);
router.delete("/:id",        deleteHealthRecord);

module.exports = router;
