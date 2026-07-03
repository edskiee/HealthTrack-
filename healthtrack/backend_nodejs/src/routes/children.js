"use strict";

/**
 * children.js — Multi-Child API Routes
 * ─────────────────────────────────────────────────────────────────────────────
 * All routes use the `patients` table — patients.id IS the child id.
 * The `child_sort_order` column (0 = primary child, 1+ = additional) controls
 * display order in the switcher.
 *
 * Mounted in server.js as:
 *   app.use("/children", childrenRoutes);
 *
 * Endpoints:
 *   GET    /children/user/:userId          — list all children for a parent
 *   GET    /children/:childId              — get single child record
 *   POST   /children                       — add a new child to a parent account
 *   PATCH  /children/:childId              — update child info
 *   GET    /children/user/:userId/count    — child count badge helper
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const { authenticateUser, authenticateAdmin } = require("../middleware/auth");

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Compute child age label from a DOB string.
 * Returns e.g. "6 months" or "2 years".
 */
function ageLabel(dob) {
  if (!dob) return "Unknown age";
  const birth = new Date(dob);
  if (isNaN(birth.getTime())) return "Unknown age";
  const now       = new Date();
  const totalDays = Math.floor((now - birth) / 86_400_000);
  const months    = Math.floor(totalDays / 30.4375);
  const years     = Math.floor(months / 12);
  if (years >= 1) return years === 1 ? "1 year old" : `${years} years old`;
  return months <= 1 ? "< 1 month old" : `${months} months old`;
}

/**
 * Validate child DOB:
 *   – must be a valid date
 *   – must not be more than 5 years ago (immunization patients only)
 * Returns null if valid, or an error string.
 */
function validateChildDob(dob, serviceType) {
  const d = new Date(dob);
  if (isNaN(d.getTime())) return "Invalid date format. Use YYYY-MM-DD.";
  const isImmunization = !serviceType || serviceType.toLowerCase().includes("immun");
  if (isImmunization) {
    const cutoff = new Date();
    cutoff.setFullYear(cutoff.getFullYear() - 5);
    if (d < cutoff) {
      return (
        "Child's date of birth indicates an age older than 5 years. " +
        "Please verify — immunization records are for children under 5 years old."
      );
    }
  }
  return null;
}

/**
 * Seed empty vaccine records for a newly added child.
 * Mirrors the logic in patientsController.addPatient.
 */
async function seedVaccineRecords(conn, patientId, serviceType) {
  const svc = (serviceType || "immunization").toLowerCase();
  if (!svc.includes("immun")) return;
  try {
    const [schedRows] = await conn.execute(
      `SELECT id FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );
    for (const sched of schedRows) {
      await conn.execute(
        `INSERT IGNORE INTO child_vaccine_records
           (patient_id, vaccine_schedule_id)
         VALUES (?, ?)`,
        [patientId, sched.id]
      );
    }
    console.log(`✅ Auto-seeded ${schedRows.length} vaccine records for child patient_id=${patientId}`);
  } catch (err) {
    console.error(`⚠️ Failed to seed vaccine records for patient ${patientId}:`, err.message);
  }
}

// ─── GET /children/user/:userId ───────────────────────────────────────────────
/**
 * Returns all children registered under a parent user account,
 * ordered by child_sort_order ASC then created_at ASC.
 * Authenticated: the requesting user must own the records OR be an admin.
 */
router.get("/user/:userId", authenticateUser, async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (!userId || userId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid user ID" });
  }

  // Users can only fetch their own children
  if (req.user.id !== userId) {
    return res.status(403).json({ success: false, message: "Access denied." });
  }

  try {
    const [rows] = await db.execute(
      `SELECT
         id,
         user_id,
         child_sort_order,
         child_fullname,
         mother_fullname,
         father_fullname,
         dob,
         dob_needs_verification,
         place_of_birth,
         birth_weight,
         birth_height,
         sex,
         address,
         service_type,
         status,
         health_center,
         barangay,
         family_number,
         created_at,
         updated_at
       FROM patients
       WHERE user_id = ?
       ORDER BY child_sort_order ASC, created_at ASC`,
      [userId]
    );

    const children = rows.map((r) => ({
      id:                    r.id,
      user_id:               r.user_id,
      child_sort_order:      r.child_sort_order ?? 0,
      child_fullname:        r.child_fullname,
      mother_fullname:       r.mother_fullname,
      father_fullname:       r.father_fullname || "",
      dob:                   r.dob ? new Date(r.dob).toISOString().split("T")[0] : null,
      dob_needs_verification: r.dob_needs_verification === 1 || r.dob_needs_verification === true,
      place_of_birth:        r.place_of_birth || "",
      birth_weight:          r.birth_weight   || "",
      birth_height:          r.birth_height   || "",
      sex:                   r.sex,
      address:               r.address        || "",
      service_type:          r.service_type   || "immunization",
      status:                r.status         || "active",
      health_center:         r.health_center  || "",
      barangay:              r.barangay        || "",
      family_number:         r.family_number  || "",
      age_label:             ageLabel(r.dob),
      created_at:            r.created_at,
      updated_at:            r.updated_at,
    }));

    return res.json({
      success: true,
      data:    children,
      count:   children.length,
    });
  } catch (err) {
    console.error("[GET /children/user/:userId]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── GET /children/user/:userId/count ────────────────────────────────────────
/**
 * Lightweight count endpoint — used by admin card badge.
 * Admin-authenticated only.
 */
router.get("/user/:userId/count", authenticateAdmin, async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (!userId || userId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid user ID" });
  }
  try {
    const [[{ cnt }]] = await db.execute(
      `SELECT COUNT(*) AS cnt FROM patients WHERE user_id = ?`,
      [userId]
    );
    return res.json({ success: true, count: Number(cnt) });
  } catch (err) {
    console.error("[GET /children/user/:userId/count]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── GET /children/:childId ───────────────────────────────────────────────────
/**
 * Returns a single child record.
 * Requires the requesting user to own the child OR admin token.
 */
router.get("/:childId", authenticateUser, async (req, res) => {
  const childId = parseInt(req.params.childId, 10);
  if (!childId || childId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid child ID" });
  }
  try {
    const [rows] = await db.execute(
      `SELECT id, user_id, child_sort_order, child_fullname, mother_fullname,
              father_fullname, dob, dob_needs_verification, place_of_birth,
              birth_weight, birth_height, sex, address, service_type,
              status, health_center, barangay, family_number, created_at
       FROM patients WHERE id = ? LIMIT 1`,
      [childId]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "Child not found" });
    }
    const r = rows[0];
    if (r.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: "Access denied." });
    }
    return res.json({
      success: true,
      data: {
        ...r,
        dob:                   r.dob ? new Date(r.dob).toISOString().split("T")[0] : null,
        dob_needs_verification: r.dob_needs_verification === 1,
        age_label:             ageLabel(r.dob),
      },
    });
  } catch (err) {
    console.error("[GET /children/:childId]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── POST /children ───────────────────────────────────────────────────────────
/**
 * Add a new child to an existing parent account.
 *
 * Body (JSON):
 *   user_id          INT     (required)
 *   child_fullname   string  (required)
 *   dob              string  YYYY-MM-DD (required)
 *   sex              "Male"|"Female" (required)
 *   place_of_birth   string  (required)
 *   address          string  (optional — defaults to parent's address)
 *   birth_weight     string  (optional)
 *   birth_height     string  (optional)
 *   health_center    string  (optional)
 *   barangay         string  (optional)
 *   family_number    string  (optional)
 *
 * Auto-seeds empty vaccine records for immunization service type.
 */
router.post("/", authenticateUser, async (req, res) => {
  const {
    user_id,
    child_fullname,
    dob,
    sex,
    place_of_birth,
    address,
    birth_weight,
    birth_height,
    health_center,
    barangay,
    family_number,
  } = req.body;

  // ── Auth: user can only add children to their own account ─────────────────
  const numericUserId = parseInt(user_id, 10);
  if (req.user.id !== numericUserId) {
    return res.status(403).json({ success: false, message: "Access denied." });
  }

  // ── Validate required fields ──────────────────────────────────────────────
  if (!child_fullname?.trim()) {
    return res.status(400).json({ success: false, message: "Child's full name is required." });
  }
  if (!dob?.trim()) {
    return res.status(400).json({ success: false, message: "Child's date of birth is required." });
  }
  if (!sex || !["Male", "Female"].includes(sex)) {
    return res.status(400).json({ success: false, message: "Sex must be 'Male' or 'Female'." });
  }
  if (!place_of_birth?.trim()) {
    return res.status(400).json({ success: false, message: "Place of birth is required." });
  }

  // ── DOB validation ────────────────────────────────────────────────────────
  const dobError = validateChildDob(dob, "immunization");
  if (dobError) {
    return res.status(400).json({ success: false, message: dobError });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Fetch parent user to get their service_type, mother_fullname, and address
    const [[parentUser]] = await conn.execute(
      `SELECT id, full_name, service_type, address FROM users WHERE id = ? LIMIT 1`,
      [numericUserId]
    );
    if (!parentUser) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: "Parent account not found." });
    }

    // Determine next sort order
    const [[{ maxOrder }]] = await conn.execute(
      `SELECT COALESCE(MAX(child_sort_order), -1) AS maxOrder FROM patients WHERE user_id = ?`,
      [numericUserId]
    );
    const nextSortOrder = Number(maxOrder) + 1;

    // Resolve address: use provided value, fall back to parent's address
    const resolvedAddress = address?.trim() || parentUser.address || "";

    // Insert new child record
    const [insertResult] = await conn.execute(
      `INSERT INTO patients
         (user_id, child_sort_order, child_fullname, mother_fullname,
          dob, dob_needs_verification, place_of_birth, birth_weight, birth_height,
          sex, address, service_type, status,
          health_center, barangay, family_number,
          record_type, record_description)
       VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?)`,
      [
        numericUserId,
        nextSortOrder,
        child_fullname.trim(),
        parentUser.full_name,                        // mother_fullname from users table
        dob.trim(),
        place_of_birth.trim(),
        birth_weight?.trim()  || "",
        birth_height?.trim()  || "",
        sex,
        resolvedAddress,
        parentUser.service_type || "immunization",
        health_center?.trim()  || "",
        barangay?.trim()       || "",
        family_number?.trim()  || "",
        parentUser.service_type === "maternal" ? "Maternal Care" : "Immunization",
        "Child record added via multi-child feature",
      ]
    );

    const newPatientId = insertResult.insertId;

    // Auto-seed vaccine records
    await seedVaccineRecords(conn, newPatientId, parentUser.service_type);

    // Create initial health record
    await conn.execute(
      `INSERT INTO health_records
         (user_id, patient_id, record_type, title, description, date_recorded)
       VALUES (?, ?, ?, 'Initial Health Record', 'Child record added by parent', CURDATE())`,
      [numericUserId, newPatientId, parentUser.service_type === "maternal" ? "Maternal Care" : "Immunization"]
    );

    await conn.commit();

    // Fetch the full new record to return
    const [[newChild]] = await db.execute(
      `SELECT id, user_id, child_sort_order, child_fullname, mother_fullname,
              father_fullname, dob, dob_needs_verification, place_of_birth,
              birth_weight, birth_height, sex, address, service_type,
              status, health_center, barangay, family_number, created_at
       FROM patients WHERE id = ? LIMIT 1`,
      [newPatientId]
    );

    // Emit real-time event to admin room
    const io = req.app.locals.io;
    if (io) {
      io.to("admins").emit("newPatientRegistration", {
        patient_id:   newPatientId,
        user_id:      numericUserId,
        service_type: parentUser.service_type,
        child_name:   child_fullname.trim(),
        timestamp:    new Date().toISOString(),
      });
    }

    console.log(`✅ New child added: patient_id=${newPatientId} user_id=${numericUserId} name="${child_fullname.trim()}"`);

    return res.status(201).json({
      success: true,
      message: "Child added successfully. Vaccine tracking has been set up.",
      data: {
        ...newChild,
        dob:       newChild.dob ? new Date(newChild.dob).toISOString().split("T")[0] : null,
        age_label: ageLabel(newChild.dob),
      },
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /children]", err);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    conn.release();
  }
});

// ─── PATCH /children/:childId ─────────────────────────────────────────────────
/**
 * Update child info (name, DOB, sex, place_of_birth, address).
 * DOB changes follow the same ≤5 year validation rule.
 */
router.patch("/:childId", authenticateUser, async (req, res) => {
  const childId = parseInt(req.params.childId, 10);
  if (!childId || childId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid child ID" });
  }

  try {
    // Ownership check
    const [[existing]] = await db.execute(
      `SELECT id, user_id, service_type FROM patients WHERE id = ? LIMIT 1`,
      [childId]
    );
    if (!existing) {
      return res.status(404).json({ success: false, message: "Child not found" });
    }
    if (existing.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: "Access denied." });
    }

    const { child_fullname, dob, sex, place_of_birth, address, birth_weight, birth_height } = req.body;

    // Only validate DOB if it is being changed
    if (dob) {
      const dobError = validateChildDob(dob, existing.service_type);
      if (dobError) {
        return res.status(400).json({ success: false, message: dobError });
      }
    }

    // Build partial update
    const sets   = [];
    const values = [];

    if (child_fullname?.trim()) { sets.push("child_fullname = ?");  values.push(child_fullname.trim()); }
    if (dob?.trim())            { sets.push("dob = ?, dob_needs_verification = 0"); values.push(dob.trim()); }
    if (sex)                    { sets.push("sex = ?");              values.push(sex); }
    if (place_of_birth?.trim()) { sets.push("place_of_birth = ?");   values.push(place_of_birth.trim()); }
    if (address?.trim())        { sets.push("address = ?");          values.push(address.trim()); }
    if (birth_weight?.trim())   { sets.push("birth_weight = ?");     values.push(birth_weight.trim()); }
    if (birth_height?.trim())   { sets.push("birth_height = ?");     values.push(birth_height.trim()); }

    if (sets.length === 0) {
      return res.status(400).json({ success: false, message: "No fields to update." });
    }

    sets.push("updated_at = NOW()");
    values.push(childId);

    await db.execute(
      `UPDATE patients SET ${sets.join(", ")} WHERE id = ?`,
      values
    );

    // If DOB changed, emit vaccineRecordUpdated so the card refreshes
    if (dob) {
      const io = req.app.locals.io;
      if (io) {
        io.to(`user_${childId}`).emit("vaccineRecordUpdated", {
          type:       "dob_corrected",
          patient_id: childId,
          new_dob:    dob.trim(),
          message:    "Child's date of birth updated. Vaccine schedule recalculated.",
        });
      }
    }

    const [[updated]] = await db.execute(
      `SELECT id, user_id, child_sort_order, child_fullname, mother_fullname,
              dob, dob_needs_verification, place_of_birth, birth_weight, birth_height,
              sex, address, service_type, status, created_at, updated_at
       FROM patients WHERE id = ? LIMIT 1`,
      [childId]
    );

    return res.json({
      success: true,
      message: "Child updated successfully.",
      data: {
        ...updated,
        dob:       updated.dob ? new Date(updated.dob).toISOString().split("T")[0] : null,
        age_label: ageLabel(updated.dob),
      },
    });
  } catch (err) {
    console.error("[PATCH /children/:childId]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
