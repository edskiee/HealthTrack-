const express = require("express");
const {
  getPatients,
  addPatient,
  updatePatient,
  deletePatient,
  searchPatients,
  getUserPatient,
  getUserChildren,
} = require("../controllers/patientsController");
const { authenticateAdmin } = require("../middleware/auth");
const db = require("../config/db");

const router = express.Router();

// All patient routes require admin authentication
router.use(authenticateAdmin);

router.get("/",              getPatients);
router.get("/search",        searchPatients);
router.get("/user/:userId",  getUserPatient);
router.get("/user/:userId/children", getUserChildren);
router.post("/",             addPatient);
router.put("/:id",           updatePatient);
router.delete("/:id",        deletePatient);

// ── PATCH /patients/:id/dob ───────────────────────────────────────────────────
// Admin corrects a child's DOB, clears the dob_needs_verification flag, and
// emits a vaccineRecordUpdated socket event so the patient's vaccine card
// recalculates immediately without a manual refresh.
router.patch("/:id/dob", async (req, res) => {
  const patientId = parseInt(req.params.id, 10);
  const { dob } = req.body;

  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }
  if (!dob || !dob.trim()) {
    return res.status(400).json({ success: false, message: "dob is required" });
  }

  // Validate: must be a real date and child must be ≤ 5 years old
  const newDob = new Date(dob.trim());
  if (isNaN(newDob.getTime())) {
    return res.status(400).json({ success: false, message: "Invalid date format. Use YYYY-MM-DD." });
  }
  const fiveYearsAgo = new Date();
  fiveYearsAgo.setFullYear(fiveYearsAgo.getFullYear() - 5);
  if (newDob < fiveYearsAgo) {
    return res.status(400).json({
      success: false,
      message:
        "Updated DOB still indicates an age > 5 years. Please verify — immunization records are for children under 5.",
    });
  }

  try {
    const [result] = await db.execute(
      `UPDATE patients
       SET dob = ?, dob_needs_verification = 0, updated_at = NOW()
       WHERE id = ? AND service_type = 'immunization'`,
      [dob.trim(), patientId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: "Patient not found or not an immunization patient" });
    }

    // Fetch the patient's user_id so we can emit to their socket room
    const [rows] = await db.execute(
      `SELECT user_id, child_fullname FROM patients WHERE id = ? LIMIT 1`,
      [patientId]
    );
    const patient = rows[0];

    // Emit vaccineRecordUpdated so the Flutter app refetches the vaccine card
    const io = req.app.locals.io;
    if (io && patient) {
      io.to(`user_${patientId}`).emit("vaccineRecordUpdated", {
        type:       "dob_corrected",
        patient_id: patientId,
        new_dob:    dob.trim(),
        message:    `Child's date of birth has been updated. Vaccine schedule has been recalculated.`,
      });
    }

    console.log(`✅ Corrected DOB for patient ${patientId} → ${dob.trim()}, verification flag cleared`);

    return res.json({
      success: true,
      message: "Child's date of birth updated and verification flag cleared.",
      data: { patient_id: patientId, dob: dob.trim() },
    });
  } catch (err) {
    console.error("[PATCH /patients/:id/dob]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
