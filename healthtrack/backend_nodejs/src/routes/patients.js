const express = require("express");
const {
  getPatients,
  addPatient,
  updatePatient,
  deletePatient,
  searchPatients,
  getUserPatient,
} = require("../controllers/patientsController");

const router = express.Router();

router.get("/", getPatients);
router.get("/search", searchPatients);
router.get("/user/:userId", getUserPatient); // New endpoint for user-specific patient data
router.post("/", addPatient);
router.put("/:id", updatePatient);
router.delete("/:id", deletePatient);

module.exports = router;