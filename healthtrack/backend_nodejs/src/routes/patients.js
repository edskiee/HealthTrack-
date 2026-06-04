const express = require("express");
const {
  getPatients,
  addPatient,
  updatePatient,
  deletePatient,
  searchPatients,
  getUserPatient,
} = require("../controllers/patientsController");
const { authenticateAdmin } = require("../middleware/auth");

const router = express.Router();

// All patient routes require admin authentication
router.use(authenticateAdmin);

router.get("/",           getPatients);
router.get("/search",     searchPatients);
router.get("/user/:userId", getUserPatient);
router.post("/",          addPatient);
router.put("/:id",        updatePatient);
router.delete("/:id",     deletePatient);

module.exports = router;
