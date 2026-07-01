"use strict";

/**
 * vaccines.js — Vaccine Tracking API Routes
 * ─────────────────────────────────────────────────────────────────────────────
 * Mounted in server.js as:
 *   app.use("/vaccines", vaccineRoutes);
 *
 * Auth per endpoint:
 *   GET  /vaccines/dashboard/:patientId  — authenticateUser  (patient sees own data)
 *   GET  /vaccines/card/:patientId       — authenticateUser
 *   POST /vaccines/record                — authenticateAdmin (admin marks dose given)
 *   DELETE /vaccines/record/:recordId    — authenticateAdmin
 *
 * Uses:
 *   db   → require("../config/db")  (mysql2/promise pool)
 *   io   → req.app.locals.io        (Socket.IO, same as referralsController)
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const { authenticateUser, authenticateAdmin } = require("../middleware/auth");

// ─── helpers ──────────────────────────────────────────────────────────────────

/**
 * Compute child age in whole days from DOB string.
 * Returns 0 for invalid/missing DOB.
 */
function ageInDays(dob) {
  if (!dob) return 0;
  const birth = new Date(dob);
  if (isNaN(birth.getTime())) return 0;
  return Math.max(0, Math.floor((Date.now() - birth.getTime()) / 86_400_000));
}

/**
 * Compute live dose status.
 * Status values mirror the Flutter VaccineDoseStatus enum exactly.
 * "locked" is set by the caller, never returned here.
 */
function computeStatus(ageDays, schedule, givenAt) {
  if (givenAt) return "completed";
  if (ageDays > schedule.due_days_max)         return "overdue";
  if (ageDays >= schedule.due_days_from_birth) return "due_soon";
  return "not_yet_due";
}

/**
 * Add days to a Date and return ISO date string "YYYY-MM-DD".
 */
function addDaysToDate(dob, days) {
  if (!dob) return null;
  try {
    const d = new Date(dob);
    d.setDate(d.getDate() + days);
    return d.toISOString().split("T")[0];
  } catch {
    return null;
  }
}

// ─── GET /vaccines/dashboard/:patientId ──────────────────────────────────────
/**
 * Returns today's completed/in-progress/missed counts, the last completed
 * dose, and the next due dose — all computed live from the DB.
 */
router.get("/dashboard/:patientId", authenticateUser, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }

  try {
    // 1. Patient row
    const [patients] = await db.execute(
      `SELECT id, dob,
              child_fullname, mother_fullname
       FROM patients WHERE id = ? LIMIT 1`,
      [patientId]
    );
    if (!patients.length) {
      return res.status(404).json({ success: false, message: "Patient not found" });
    }
    const patient = patients[0];
    const age     = ageInDays(patient.dob);

    // 2. All schedules + records in two fast queries
    const [schedules] = await db.execute(
      `SELECT id, vaccine_name, vaccine_key, dose_number, dose_label,
              schedule_label, due_days_from_birth, due_days_max, sort_order
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );

    const [records] = await db.execute(
      `SELECT vaccine_schedule_id, given_at, given_by
       FROM child_vaccine_records WHERE patient_id = ?`,
      [patientId]
    );

    // Index records by schedule_id
    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    // 3. Today boundaries (server local time, Asia/Manila = UTC+8)
    const now        = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd   = new Date(todayStart.getTime() + 86_400_000);

    // 4. Walk schedules
    const lockMap = {};  // vaccine_key → true when locked
    let todayCompleted  = 0;
    let todayInProgress = 0;
    let todayMissed     = 0;
    let lastCompleted   = null;
    let nextDue         = null;

    for (const sched of schedules) {
      const rec     = recMap[sched.id] || null;
      const givenAt = rec ? rec.given_at : null;

      let status;
      if (lockMap[sched.vaccine_key]) {
        status = "locked";
      } else {
        status = computeStatus(age, sched, givenAt);
        if (status !== "completed") lockMap[sched.vaccine_key] = true;
      }

      // Today counts
      if (status === "completed" && givenAt) {
        const gd = new Date(givenAt);
        if (gd >= todayStart && gd < todayEnd) todayCompleted++;
      }
      if (status === "due_soon" && patient.dob) {
        const dueDate = new Date(patient.dob);
        dueDate.setDate(dueDate.getDate() + sched.due_days_from_birth);
        if (dueDate >= todayStart && dueDate < todayEnd) todayInProgress++;
      }
      if (status === "overdue" && patient.dob) {
        const maxDate = new Date(patient.dob);
        maxDate.setDate(maxDate.getDate() + sched.due_days_max);
        if (maxDate >= todayStart && maxDate < todayEnd) todayMissed++;
      }

      // Last completed
      if (status === "completed" && givenAt) {
        if (!lastCompleted || new Date(givenAt) > new Date(lastCompleted.given_at)) {
          lastCompleted = {
            vaccine_name: sched.vaccine_name,
            dose_label:   sched.dose_label,
            given_at:     givenAt,
            given_by:     rec.given_by || null,
          };
        }
      }

      // Next due (first non-completed non-locked)
      if (!nextDue && (status === "due_soon" || status === "not_yet_due")) {
        nextDue = {
          vaccine_name:      sched.vaccine_name,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: addDaysToDate(patient.dob, sched.due_days_from_birth),
          status,
        };
      }
    }

    const hasActionable = schedules.some(s => {
      const r = recMap[s.id];
      if (r && r.given_at) return false;
      const st = computeStatus(age, s, null);
      return st === "overdue" || st === "due_soon";
    });
    const fullyUpToDate = !hasActionable && lastCompleted !== null;

    return res.json({
      success: true,
      data: {
        child_name:        patient.child_fullname || patient.mother_fullname || "Unknown",
        today_completed:   todayCompleted,
        today_in_progress: todayInProgress,
        today_missed:      todayMissed,
        last_completed:    lastCompleted,
        next_due:          nextDue,
        fully_up_to_date:  fullyUpToDate,
      },
    });
  } catch (err) {
    console.error("[GET /vaccines/dashboard]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── GET /vaccines/card/:patientId ───────────────────────────────────────────
/**
 * Full vaccine card — every vaccine group with per-dose live status.
 *
 * Enhanced response includes:
 *   total_doses_required   — total rows in vaccine_schedules
 *   total_doses_completed  — doses with given_at set for this patient
 *   fully_up_to_date       — true only when no due/overdue doses remain
 *   overall_status         — "up_to_date" | "action_needed" | "overdue"
 *   pending_doses          — flat list of non-completed doses sorted by urgency
 *                            (overdue first, then due_soon, then not_yet_due/locked)
 *   sex                    — child sex from patients table
 */
router.get("/card/:patientId", authenticateUser, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }

  try {
    const [patients] = await db.execute(
      `SELECT id, dob, sex,
              child_fullname, mother_fullname
       FROM patients WHERE id = ? LIMIT 1`,
      [patientId]
    );
    if (!patients.length) {
      return res.status(404).json({ success: false, message: "Patient not found" });
    }
    const patient = patients[0];
    const age     = ageInDays(patient.dob);

    const [schedules] = await db.execute(
      `SELECT id, vaccine_name, vaccine_key, dose_number, dose_label,
              schedule_label, due_days_from_birth, due_days_max, sort_order
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );

    const [records] = await db.execute(
      `SELECT id AS record_id, vaccine_schedule_id, given_at, given_by, notes
       FROM child_vaccine_records WHERE patient_id = ?`,
      [patientId]
    );

    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    // Build grouped output with live status + sequential lock
    const vaccineMap = new Map();
    const lockMap    = {};
    let nextDue      = null;
    let overdueAlert = null;

    // Progress counters
    let totalDosesRequired = schedules.length;
    let totalDosesCompleted = 0;

    // Pending list (non-completed doses in priority order)
    const pendingDoses = [];

    for (const sched of schedules) {
      if (!vaccineMap.has(sched.vaccine_key)) {
        vaccineMap.set(sched.vaccine_key, {
          vaccine_name: sched.vaccine_name,
          vaccine_key:  sched.vaccine_key,
          doses: [],
        });
      }

      const rec     = recMap[sched.id] || null;
      const givenAt = rec ? rec.given_at : null;

      let status;
      if (lockMap[sched.vaccine_key]) {
        status = "locked";
      } else {
        status = computeStatus(age, sched, givenAt);
        if (status !== "completed") lockMap[sched.vaccine_key] = true;
      }

      const dueDateEstimate = addDaysToDate(patient.dob, sched.due_days_from_birth);
      const maxDateEstimate  = addDaysToDate(patient.dob, sched.due_days_max);

      // Progress tracking
      if (status === "completed") {
        totalDosesCompleted++;
      }

      // Overdue/next alerts (first occurrence only)
      if (!overdueAlert && status === "overdue") {
        overdueAlert = { vaccine_name: sched.vaccine_name, dose_label: sched.dose_label };
      }
      if (!nextDue && (status === "due_soon" || status === "not_yet_due")) {
        nextDue = {
          vaccine_name:      sched.vaccine_name,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          status,
        };
      }

      // Build pending list entry for non-completed doses
      if (status !== "completed") {
        // Compute days overdue (positive = overdue, negative = still has time)
        let daysOverdue = null;
        if (status === "overdue" && patient.dob) {
          daysOverdue = age - sched.due_days_max;
        }

        // Locked item: find the blocking dose name
        let waitingFor = null;
        if (status === "locked" && sched.dose_number > 1) {
          // The dose immediately before this one in the same vaccine_key
          const prevSched = schedules.find(
            s => s.vaccine_key === sched.vaccine_key && s.dose_number === sched.dose_number - 1
          );
          if (prevSched) {
            waitingFor = `${prevSched.vaccine_name} (${prevSched.dose_label})`;
          }
        }

        pendingDoses.push({
          vaccine_name:      sched.vaccine_name,
          vaccine_key:       sched.vaccine_key,
          dose_number:       sched.dose_number,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          max_date_estimate: maxDateEstimate,
          days_overdue:      daysOverdue,
          status,
          waiting_for:       waitingFor,
        });
      }

      vaccineMap.get(sched.vaccine_key).doses.push({
        schedule_id:       sched.id,
        record_id:         rec ? rec.record_id : null,
        dose_number:       sched.dose_number,
        dose_label:        sched.dose_label,
        schedule_label:    sched.schedule_label,
        due_date_estimate: dueDateEstimate,
        given_at:          givenAt || null,
        given_by:          rec ? rec.given_by || null : null,
        notes:             rec ? rec.notes    || null : null,
        status,
      });
    }

    // Sort pending: overdue first (by days_overdue desc), then due_soon, then not_yet_due, then locked
    const statusPriority = { overdue: 0, due_soon: 1, not_yet_due: 2, locked: 3 };
    pendingDoses.sort((a, b) => {
      const pa = statusPriority[a.status] ?? 4;
      const pb = statusPriority[b.status] ?? 4;
      if (pa !== pb) return pa - pb;
      // Within overdue: most overdue first
      if (a.status === "overdue" && b.status === "overdue") {
        return (b.days_overdue || 0) - (a.days_overdue || 0);
      }
      return 0;
    });

    // Overall status label
    const hasOverdue  = pendingDoses.some(d => d.status === "overdue");
    const hasDueSoon  = pendingDoses.some(d => d.status === "due_soon");
    let overallStatus;
    if (hasOverdue) {
      overallStatus = "overdue";
    } else if (hasDueSoon) {
      overallStatus = "action_needed";
    } else {
      overallStatus = "up_to_date";
    }

    // Fully up to date: no overdue or due_soon doses exist
    const fullyUpToDate = !hasOverdue && !hasDueSoon;

    const dobStr = patient.dob
      ? new Date(patient.dob).toISOString().split("T")[0]
      : null;

    return res.json({
      success: true,
      data: {
        child_name:             patient.child_fullname || patient.mother_fullname || "Unknown",
        dob:                    dobStr,
        sex:                    patient.sex || null,
        age_in_days:            age,
        total_doses_required:   totalDosesRequired,
        total_doses_completed:  totalDosesCompleted,
        fully_up_to_date:       fullyUpToDate,
        overall_status:         overallStatus,
        vaccines:               Array.from(vaccineMap.values()),
        pending_doses:          pendingDoses,
        next_due:               nextDue,
        overdue_alert:          overdueAlert,
      },
    });
  } catch (err) {
    console.error("[GET /vaccines/card]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── POST /vaccines/record ────────────────────────────────────────────────────
/**
 * Admin marks a dose as given.
 * Enforces sequential lock server-side.
 * Emits vaccineRecordUpdated to the patient's Socket.IO room.
 */
router.post("/record", authenticateAdmin, async (req, res) => {
  const { patient_id, vaccine_schedule_id, given_by, notes } = req.body;

  if (!patient_id || !vaccine_schedule_id) {
    return res.status(400).json({
      success: false,
      message: "patient_id and vaccine_schedule_id are required",
    });
  }

  try {
    // 1. Fetch target schedule row
    const [scheds] = await db.execute(
      `SELECT id, vaccine_key, dose_number, vaccine_name, dose_label
       FROM vaccine_schedules WHERE id = ? LIMIT 1`,
      [vaccine_schedule_id]
    );
    if (!scheds.length) {
      return res.status(404).json({ success: false, message: "Vaccine schedule not found" });
    }
    const target = scheds[0];

    // 2. Sequential lock check: any prior dose (same key, lower number) not yet given?
    if (target.dose_number > 1) {
      const [unfinished] = await db.execute(
        `SELECT vs.dose_number
         FROM vaccine_schedules vs
         LEFT JOIN child_vaccine_records cvr
           ON  cvr.vaccine_schedule_id = vs.id
           AND cvr.patient_id          = ?
           AND cvr.given_at IS NOT NULL
         WHERE vs.vaccine_key  = ?
           AND vs.dose_number  < ?
           AND cvr.id IS NULL
         LIMIT 1`,
        [patient_id, target.vaccine_key, target.dose_number]
      );
      if (unfinished.length) {
        return res.status(422).json({
          success: false,
          message: `Cannot mark this dose — dose ${unfinished[0].dose_number} must be completed first.`,
        });
      }
    }

    // 3. Upsert — if record exists but given_at is NULL, set it now
    //            if it already has given_at, leave it unchanged
    await db.execute(
      `INSERT INTO child_vaccine_records
         (patient_id, vaccine_schedule_id, given_at, given_by, notes)
       VALUES (?, ?, NOW(), ?, ?)
       ON DUPLICATE KEY UPDATE
         given_at = COALESCE(given_at, NOW()),
         given_by = COALESCE(VALUES(given_by), given_by),
         notes    = COALESCE(VALUES(notes),    notes),
         updated_at = CURRENT_TIMESTAMP`,
      [patient_id, vaccine_schedule_id, given_by || null, notes || null]
    );

    // Fetch back the saved record for the response
    const [saved] = await db.execute(
      `SELECT id AS record_id, given_at, given_by
       FROM child_vaccine_records
       WHERE patient_id = ? AND vaccine_schedule_id = ? LIMIT 1`,
      [patient_id, vaccine_schedule_id]
    );
    const record = saved[0];

    // 4. Emit realtime event to patient's room
    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${patient_id}`).emit("vaccineRecordUpdated", {
        type:                "vaccine_record_updated",
        patient_id:          patient_id,
        vaccine_schedule_id: vaccine_schedule_id,
        vaccine_name:        target.vaccine_name,
        dose_label:          target.dose_label,
        given_at:            record.given_at,
        given_by:            record.given_by,
        message:             `${target.vaccine_name} (${target.dose_label}) has been marked as completed.`,
      });
    }

    return res.status(201).json({
      success: true,
      message: `${target.vaccine_name} (${target.dose_label}) marked as given.`,
      data: {
        record_id:           record.record_id,
        vaccine_schedule_id: vaccine_schedule_id,
        given_at:            record.given_at,
        given_by:            record.given_by,
      },
    });
  } catch (err) {
    console.error("[POST /vaccines/record]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── DELETE /vaccines/record/:recordId ───────────────────────────────────────
/**
 * Admin un-marks a dose (data correction).
 */
router.delete("/record/:recordId", authenticateAdmin, async (req, res) => {
  const recordId = parseInt(req.params.recordId, 10);
  if (!recordId) {
    return res.status(400).json({ success: false, message: "Invalid record ID" });
  }

  try {
    const [rows] = await db.execute(
      `SELECT cvr.id, cvr.patient_id, cvr.vaccine_schedule_id,
              vs.vaccine_name, vs.dose_label
       FROM child_vaccine_records cvr
       JOIN vaccine_schedules vs ON vs.id = cvr.vaccine_schedule_id
       WHERE cvr.id = ? LIMIT 1`,
      [recordId]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "Record not found" });
    }
    const rec = rows[0];

    await db.execute("DELETE FROM child_vaccine_records WHERE id = ?", [recordId]);

    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${rec.patient_id}`).emit("vaccineRecordUpdated", {
        type:                "vaccine_record_removed",
        patient_id:          rec.patient_id,
        vaccine_schedule_id: rec.vaccine_schedule_id,
        vaccine_name:        rec.vaccine_name,
        dose_label:          rec.dose_label,
        message:             `${rec.vaccine_name} (${rec.dose_label}) completion was removed.`,
      });
    }

    return res.json({ success: true, message: "Vaccine record removed." });
  } catch (err) {
    console.error("[DELETE /vaccines/record]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── GET /vaccines/admin/card/:patientId ─────────────────────────────────────
/**
 * Admin-authenticated version of GET /vaccines/card/:patientId.
 *
 * Identical logic to the user-facing endpoint but guarded by authenticateAdmin
 * so the admin panel (which carries an admin Bearer token, not a user JWT) can
 * call it without a 401.
 *
 * Also returns dob_needs_verification so the admin modal can gate display.
 */
router.get("/admin/card/:patientId", authenticateAdmin, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }

  try {
    const [patients] = await db.execute(
      `SELECT id, dob, sex, service_type,
              dob_needs_verification,
              child_fullname, mother_fullname
       FROM patients WHERE id = ? LIMIT 1`,
      [patientId]
    );
    if (!patients.length) {
      return res.status(404).json({ success: false, message: "Patient not found" });
    }
    const patient = patients[0];

    // ── Maternal Care guard — no schedule data for non-immunization patients ──
    const svcType = (patient.service_type || "").toLowerCase();
    if (!svcType.includes("immun")) {
      return res.json({
        success: true,
        data: {
          child_name:            patient.child_fullname || patient.mother_fullname || "Unknown",
          service_type:          patient.service_type,
          dob_needs_verification: false,
          not_immunization:      true,
          message:               "Vaccine tracking is for Immunization patients only.",
        },
      });
    }

    // ── DOB verification flag — return early if flagged ──────────────────────
    const dobFlagged = patient.dob_needs_verification === 1 || patient.dob_needs_verification === true;
    const dobStr = patient.dob ? new Date(patient.dob).toISOString().split("T")[0] : null;

    if (dobFlagged) {
      return res.json({
        success: true,
        data: {
          child_name:            patient.child_fullname || patient.mother_fullname || "Unknown",
          dob:                   dobStr,
          service_type:          patient.service_type,
          dob_needs_verification: true,
          vaccines:              [],
          pending_doses:         [],
          total_doses_required:  0,
          total_doses_completed: 0,
        },
      });
    }

    // ── Normal flow ───────────────────────────────────────────────────────────
    const age = ageInDays(patient.dob);

    const [schedules] = await db.execute(
      `SELECT id, vaccine_name, vaccine_key, dose_number, dose_label,
              schedule_label, due_days_from_birth, due_days_max, sort_order
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );

    const [records] = await db.execute(
      `SELECT id AS record_id, vaccine_schedule_id, given_at, given_by, notes
       FROM child_vaccine_records WHERE patient_id = ?`,
      [patientId]
    );

    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    const vaccineMap = new Map();
    const lockMap    = {};
    let nextDue      = null;
    let overdueAlert = null;
    let totalDosesRequired  = schedules.length;
    let totalDosesCompleted = 0;
    const pendingDoses = [];

    for (const sched of schedules) {
      if (!vaccineMap.has(sched.vaccine_key)) {
        vaccineMap.set(sched.vaccine_key, {
          vaccine_name: sched.vaccine_name,
          vaccine_key:  sched.vaccine_key,
          doses: [],
        });
      }

      const rec     = recMap[sched.id] || null;
      const givenAt = rec ? rec.given_at : null;

      let status;
      if (lockMap[sched.vaccine_key]) {
        status = "locked";
      } else {
        status = computeStatus(age, sched, givenAt);
        if (status !== "completed") lockMap[sched.vaccine_key] = true;
      }

      const dueDateEstimate = addDaysToDate(patient.dob, sched.due_days_from_birth);
      const maxDateEstimate  = addDaysToDate(patient.dob, sched.due_days_max);

      if (status === "completed") totalDosesCompleted++;

      if (!overdueAlert && status === "overdue") {
        overdueAlert = { vaccine_name: sched.vaccine_name, dose_label: sched.dose_label };
      }
      if (!nextDue && (status === "due_soon" || status === "not_yet_due")) {
        nextDue = {
          vaccine_name:      sched.vaccine_name,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          status,
        };
      }

      if (status !== "completed") {
        let daysOverdue = null;
        if (status === "overdue" && patient.dob) {
          daysOverdue = age - sched.due_days_max;
        }
        let waitingFor = null;
        if (status === "locked" && sched.dose_number > 1) {
          const prevSched = schedules.find(
            s => s.vaccine_key === sched.vaccine_key && s.dose_number === sched.dose_number - 1
          );
          if (prevSched) waitingFor = `${prevSched.vaccine_name} (${prevSched.dose_label})`;
        }
        pendingDoses.push({
          vaccine_name:      sched.vaccine_name,
          vaccine_key:       sched.vaccine_key,
          dose_number:       sched.dose_number,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          max_date_estimate: maxDateEstimate,
          days_overdue:      daysOverdue,
          status,
          waiting_for:       waitingFor,
        });
      }

      vaccineMap.get(sched.vaccine_key).doses.push({
        schedule_id:       sched.id,
        record_id:         rec ? rec.record_id : null,
        dose_number:       sched.dose_number,
        dose_label:        sched.dose_label,
        schedule_label:    sched.schedule_label,
        due_date_estimate: dueDateEstimate,
        given_at:          givenAt || null,
        given_by:          rec ? rec.given_by || null : null,
        notes:             rec ? rec.notes    || null : null,
        status,
      });
    }

    const statusPriority = { overdue: 0, due_soon: 1, not_yet_due: 2, locked: 3 };
    pendingDoses.sort((a, b) => {
      const pa = statusPriority[a.status] ?? 4;
      const pb = statusPriority[b.status] ?? 4;
      if (pa !== pb) return pa - pb;
      if (a.status === "overdue" && b.status === "overdue") {
        return (b.days_overdue || 0) - (a.days_overdue || 0);
      }
      return 0;
    });

    const hasOverdue = pendingDoses.some(d => d.status === "overdue");
    const hasDueSoon = pendingDoses.some(d => d.status === "due_soon");
    let overallStatus;
    if (hasOverdue)      overallStatus = "overdue";
    else if (hasDueSoon) overallStatus = "action_needed";
    else                 overallStatus = "up_to_date";

    return res.json({
      success: true,
      data: {
        child_name:             patient.child_fullname || patient.mother_fullname || "Unknown",
        dob:                    dobStr,
        sex:                    patient.sex || null,
        service_type:           patient.service_type,
        dob_needs_verification: false,
        not_immunization:       false,
        age_in_days:            age,
        total_doses_required:   totalDosesRequired,
        total_doses_completed:  totalDosesCompleted,
        fully_up_to_date:       !hasOverdue && !hasDueSoon,
        overall_status:         overallStatus,
        vaccines:               Array.from(vaccineMap.values()),
        pending_doses:          pendingDoses,
        next_due:               nextDue,
        overdue_alert:          overdueAlert,
      },
    });
  } catch (err) {
    console.error("[GET /vaccines/admin/card]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─── GET /vaccines/admin/badge/:patientId ─────────────────────────────────────
/**
 * Lightweight badge summary for a single patient card.
 * Returns only the fields needed to render the small status pill on the card —
 * no full vaccine list, keeping the payload tiny.
 *
 * Response:
 *   { overall_status, total_doses_required, total_doses_completed,
 *     next_due_date, dob_needs_verification, not_immunization }
 */
router.get("/admin/badge/:patientId", authenticateAdmin, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }

  try {
    const [patients] = await db.execute(
      `SELECT id, dob, service_type, dob_needs_verification
       FROM patients WHERE id = ? LIMIT 1`,
      [patientId]
    );
    if (!patients.length) {
      return res.status(404).json({ success: false, message: "Patient not found" });
    }
    const patient = patients[0];
    const svcType = (patient.service_type || "").toLowerCase();
    if (!svcType.includes("immun")) {
      return res.json({ success: true, data: { not_immunization: true } });
    }

    const dobFlagged = patient.dob_needs_verification === 1 || patient.dob_needs_verification === true;
    if (dobFlagged) {
      return res.json({ success: true, data: { dob_needs_verification: true, overall_status: "unverified" } });
    }

    const age = ageInDays(patient.dob);

    const [schedules] = await db.execute(
      `SELECT id, vaccine_key, dose_number, due_days_from_birth, due_days_max
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );
    const [records] = await db.execute(
      `SELECT vaccine_schedule_id FROM child_vaccine_records WHERE patient_id = ? AND given_at IS NOT NULL`,
      [patientId]
    );
    const givenSet = new Set(records.map(r => r.vaccine_schedule_id));
    const lockMap  = {};
    let totalRequired  = schedules.length;
    let totalCompleted = 0;
    let hasOverdue     = false;
    let hasDueSoon     = false;
    let nextDueDate    = null;

    for (const sched of schedules) {
      const given = givenSet.has(sched.id);
      let status;
      if (lockMap[sched.vaccine_key]) {
        status = "locked";
      } else {
        status = computeStatus(age, sched, given ? "given" : null);
        if (status !== "completed") lockMap[sched.vaccine_key] = true;
      }
      if (status === "completed") totalCompleted++;
      if (status === "overdue") hasOverdue = true;
      if (status === "due_soon" && !nextDueDate) {
        nextDueDate = addDaysToDate(patient.dob, sched.due_days_from_birth);
        hasDueSoon = true;
      }
    }

    let overallStatus;
    if (hasOverdue)      overallStatus = "overdue";
    else if (hasDueSoon) overallStatus = "action_needed";
    else                 overallStatus = "up_to_date";

    return res.json({
      success: true,
      data: {
        overall_status:         overallStatus,
        total_doses_required:   totalRequired,
        total_doses_completed:  totalCompleted,
        next_due_date:          nextDueDate,
        dob_needs_verification: false,
        not_immunization:       false,
      },
    });
  } catch (err) {
    console.error("[GET /vaccines/admin/badge]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
