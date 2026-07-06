"use strict";

/**
 * vaccines.js — Vaccine Tracking API Routes (Record-Based Schedule v2)
 * ─────────────────────────────────────────────────────────────────────────────
 * Panelist fix: vaccine due dates after the first dose are computed from the
 * ACTUAL date the previous dose was given (given_at), not from DOB.
 * Only first doses (schedule_from = 'dob') remain DOB-anchored.
 *
 * Mounted in server.js as:
 *   app.use("/vaccines", vaccineRoutes);
 *
 * Auth per endpoint:
 *   GET  /vaccines/dashboard/:patientId  — authenticateUser
 *   GET  /vaccines/card/:patientId       — authenticateUser
 *   POST /vaccines/record                — authenticateAdmin
 *   DELETE /vaccines/record/:recordId    — authenticateAdmin
 *   GET  /vaccines/admin/card/:patientId — authenticateAdmin
 *   GET  /vaccines/admin/badge/:patientId— authenticateAdmin
 *
 * DB schema required: migration 002_record_based_schedule.sql must be applied.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const { authenticateUser, authenticateAdmin } = require("../middleware/auth");
const {
  createVaccineDoseReminders,
  sendAllDosesCompletedNotification,
} = require("../services/vaccineDoseReminderService");

// ─── helpers ──────────────────────────────────────────────────────────────────

/** Days from DOB to today. Returns 0 for invalid/missing DOB. */
function ageInDays(dob) {
  if (!dob) return 0;
  const birth = new Date(dob);
  if (isNaN(birth.getTime())) return 0;
  return Math.max(0, Math.floor((Date.now() - birth.getTime()) / 86_400_000));
}

/** Add whole days to any date-string/Date; return "YYYY-MM-DD" or null. */
function addDaysToDate(base, days) {
  if (!base) return null;
  try {
    const d = new Date(base);
    if (isNaN(d.getTime())) return null;
    d.setDate(d.getDate() + days);
    return d.toISOString().split("T")[0];
  } catch { return null; }
}


/**
 * Core record-based due-date computation.
 *
 * @param {object} sched  — row from vaccine_schedules
 *                          (needs: schedule_from, interval_days, due_days_from_birth)
 * @param {string|null} dob            — child DOB ISO string
 * @param {string|null} prevGivenAt    — given_at of the previous dose (null if not yet given)
 * @returns {string|null}  "YYYY-MM-DD" or null when it cannot yet be computed
 */
function computeDueDate(sched, dob, prevGivenAt) {
  if (sched.schedule_from === "dob") {
    return addDaysToDate(dob, sched.interval_days);
  }
  // previous_dose anchor
  if (!prevGivenAt) return null; // previous dose not yet completed
  return addDaysToDate(prevGivenAt, sched.interval_days);
}

/**
 * Theoretical DOB-based date (kept for display as "was supposed to be given on").
 * Always uses due_days_from_birth regardless of schedule_from.
 */
function theoreticalDate(sched, dob) {
  return addDaysToDate(dob, sched.due_days_from_birth);
}


/**
 * Compute live dose status using the RECORD-BASED due date.
 *
 * @param {string|null} recordBasedDueDate — "YYYY-MM-DD" or null (locked)
 * @param {string|null} givenAt            — actual given timestamp or null
 * @param {number}      ageDays            — child's current age in days (for overdue check)
 * @param {object}      sched              — schedule row (for due_days_max overdue boundary)
 * @param {string|null} dob                — child DOB (for overdue boundary calc)
 * @returns {"completed"|"overdue"|"due_soon"|"not_yet_due"|"locked"}
 */
function computeStatus(recordBasedDueDate, givenAt, ageDays, sched, dob) {
  if (givenAt) return "completed";

  // Cannot compute date yet — previous dose not completed
  if (recordBasedDueDate === null) return "locked";

  const today      = new Date();
  today.setHours(0, 0, 0, 0);
  const dueDate    = new Date(recordBasedDueDate);

  // Overdue: record-based due date has passed AND not yet given
  // We also honour the existing due_days_max boundary as the hard overdue limit.
  // Whichever fires first wins.
  const maxDateStr = addDaysToDate(dob, sched.due_days_max);
  const maxDate    = maxDateStr ? new Date(maxDateStr) : null;

  if (dueDate < today) return "overdue";
  if (maxDate && maxDate < today) return "overdue";

  // Due within the next 14 days
  const fourteenDaysOut = new Date(today.getTime() + 14 * 86_400_000);
  if (dueDate <= fourteenDaysOut) return "due_soon";

  return "not_yet_due";
}


/**
 * Build the full per-child schedule: walks vaccine_schedules in sort_order,
 * threads the previous-dose given_at through each vaccine group, and returns
 * an array of enriched dose objects ready for any API response.
 *
 * Each returned object has:
 *   schedule_id, vaccine_key, vaccine_name, dose_number, dose_label,
 *   schedule_label, schedule_from, interval_days,
 *   theoretical_due_date   — DOB-based reference date
 *   due_date               — record-based computed date (null if locked)
 *   given_at               — actual date given (null if not yet)
 *   scheduled_date         — stored theoretical date on the record row (may be null for old rows)
 *   given_by, notes, remarks
 *   record_id              — child_vaccine_records.id (null if no record yet)
 *   status                 — completed | overdue | due_soon | not_yet_due | locked
 *
 * @param {Array}  schedules — rows from vaccine_schedules (sorted by sort_order, dose_number)
 * @param {object} recMap    — { [vaccine_schedule_id]: record_row }
 * @param {string} dob       — patient date of birth ISO string
 * @param {number} ageDays   — patient age in whole days
 */
function buildDoseList(schedules, recMap, dob, ageDays) {
  // Track the last given_at per vaccine_key for previous_dose anchoring
  const lastGivenAt = {};

  return schedules.map((sched) => {
    const rec     = recMap[sched.id] || null;
    const givenAt = rec ? rec.given_at : null;

    // Determine previous dose anchor
    const prevGiven = sched.schedule_from === "previous_dose"
      ? (lastGivenAt[sched.vaccine_key] ?? null)
      : null;

    const dueDate    = computeDueDate(sched, dob, prevGiven);
    const theoDate   = theoreticalDate(sched, dob);
    const status     = computeStatus(dueDate, givenAt, ageDays, sched, dob);

    // Advance the lastGivenAt cursor only when this dose is completed
    if (status === "completed" && givenAt) {
      lastGivenAt[sched.vaccine_key] = givenAt;
    }

    return {
      schedule_id:          sched.id,
      vaccine_key:          sched.vaccine_key,
      vaccine_name:         sched.vaccine_name,
      dose_number:          sched.dose_number,
      dose_label:           sched.dose_label,
      schedule_label:       sched.schedule_label,
      schedule_from:        sched.schedule_from,
      interval_days:        sched.interval_days,
      theoretical_due_date: theoDate,
      due_date:             dueDate,   // null when locked (previous dose not yet given)
      given_at:             givenAt || null,
      scheduled_date:       rec ? rec.scheduled_date || null : null,
      given_by:             rec ? rec.given_by  || null : null,
      notes:                rec ? rec.notes     || null : null,
      remarks:              rec ? rec.remarks   || null : null,
      record_id:            rec ? rec.record_id : null,
      status,
    };
  });
}


// ─── GET /vaccines/dashboard/:patientId ──────────────────────────────────────
/**
 * Lightweight dashboard summary: today counts, last completed, next due.
 * All dates are now record-based.
 */
router.get("/dashboard/:patientId", authenticateUser, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }

  try {
    const [patients] = await db.execute(
      `SELECT id, dob, child_fullname, mother_fullname
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
              schedule_label, schedule_from, interval_days,
              due_days_from_birth, due_days_max, sort_order
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );

    const [records] = await db.execute(
      `SELECT id AS record_id, vaccine_schedule_id, given_at, given_by,
              scheduled_date, notes, remarks
       FROM child_vaccine_records WHERE patient_id = ?`,
      [patientId]
    );

    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    const doses = buildDoseList(schedules, recMap, patient.dob, age);

    // Today boundaries
    const now        = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd   = new Date(todayStart.getTime() + 86_400_000);

    let todayCompleted  = 0;
    let todayInProgress = 0;
    let todayMissed     = 0;
    let lastCompleted   = null;
    let nextDue         = null;

    for (const d of doses) {
      if (d.status === "completed" && d.given_at) {
        const gd = new Date(d.given_at);
        if (gd >= todayStart && gd < todayEnd) todayCompleted++;
        // Track most recently completed overall
        if (!lastCompleted || new Date(d.given_at) > new Date(lastCompleted.given_at)) {
          lastCompleted = {
            vaccine_name: d.vaccine_name,
            dose_label:   d.dose_label,
            given_at:     d.given_at,
            given_by:     d.given_by || null,
          };
        }
      }
      if (d.status === "due_soon" && d.due_date) {
        const dd = new Date(d.due_date);
        if (dd >= todayStart && dd < todayEnd) todayInProgress++;
      }
      if (d.status === "overdue") {
        // Count overdue items whose max boundary was today
        const md = d.due_date ? new Date(d.due_date) : null;
        if (md && md >= todayStart && md < todayEnd) todayMissed++;
      }
      // First actionable non-completed dose
      if (!nextDue && (d.status === "due_soon" || d.status === "not_yet_due" || d.status === "overdue")) {
        nextDue = {
          vaccine_name:      d.vaccine_name,
          dose_label:        d.dose_label,
          schedule_label:    d.schedule_label,
          due_date_estimate: d.due_date,          // record-based
          theoretical_date:  d.theoretical_due_date,
          status:            d.status,
        };
      }
    }

    const hasActionable = doses.some(d => d.status === "overdue" || d.status === "due_soon");
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


// ─── shared card builder ──────────────────────────────────────────────────────
/**
 * Shared logic for both GET /vaccines/card/:id and GET /vaccines/admin/card/:id.
 * Returns a fully enriched card object or throws.
 */
async function buildVaccineCard(patientId, isAdmin) {
  // Always fetch the full demographic block — needed for the PDF vaccine card
  const selectCols = isAdmin
    ? `id, dob, sex, service_type, dob_needs_verification,
       child_fullname, mother_fullname, father_fullname,
       place_of_birth, address, health_center, barangay`
    : `id, dob, sex, child_fullname, mother_fullname, father_fullname,
       place_of_birth, address, dob_needs_verification, health_center`;

  const [patients] = await db.execute(
    `SELECT ${selectCols} FROM patients WHERE id = ? LIMIT 1`,
    [patientId]
  );
  if (!patients.length) throw Object.assign(new Error("Patient not found"), { statusCode: 404 });

  const patient = patients[0];
  const age     = ageInDays(patient.dob);

  // Admin-only guards
  if (isAdmin) {
    const svcType = (patient.service_type || "").toLowerCase();
    if (!svcType.includes("immun")) {
      return {
        child_name:       patient.child_fullname || patient.mother_fullname || "Unknown",
        service_type:     patient.service_type,
        not_immunization: true,
        message:          "Vaccine tracking is for Immunization patients only.",
      };
    }
    const dobFlagged = patient.dob_needs_verification === 1 || patient.dob_needs_verification === true;
    const dobStr     = patient.dob ? new Date(patient.dob).toISOString().split("T")[0] : null;
    if (dobFlagged) {
      return {
        child_name:            patient.child_fullname || patient.mother_fullname || "Unknown",
        dob:                   dobStr,
        service_type:          patient.service_type,
        dob_needs_verification: true,
        vaccines:              [],
        pending_doses:         [],
        total_doses_required:  0,
        total_doses_completed: 0,
      };
    }
  }

  const [schedules] = await db.execute(
    `SELECT id, vaccine_name, vaccine_key, dose_number, dose_label,
            schedule_label, schedule_from, interval_days,
            due_days_from_birth, due_days_max, sort_order
     FROM vaccine_schedules ORDER BY sort_order, dose_number`
  );

  const [records] = await db.execute(
    `SELECT id AS record_id, vaccine_schedule_id, given_at, given_by,
            scheduled_date, notes, remarks
     FROM child_vaccine_records WHERE patient_id = ?`,
    [patientId]
  );

  const recMap = {};
  for (const r of records) recMap[r.vaccine_schedule_id] = r;

  const doses = buildDoseList(schedules, recMap, patient.dob, age);

  // ── Group by vaccine_key ──────────────────────────────────────────────────
  const vaccineMap = new Map();
  for (const d of doses) {
    if (!vaccineMap.has(d.vaccine_key)) {
      vaccineMap.set(d.vaccine_key, { vaccine_name: d.vaccine_name, vaccine_key: d.vaccine_key, doses: [] });
    }
    vaccineMap.get(d.vaccine_key).doses.push({
      schedule_id:          d.schedule_id,
      record_id:            d.record_id,
      dose_number:          d.dose_number,
      dose_label:           d.dose_label,
      schedule_label:       d.schedule_label,
      schedule_from:        d.schedule_from,
      interval_days:        d.interval_days,
      theoretical_due_date: d.theoretical_due_date,  // DOB-based reference
      due_date_estimate:    d.due_date,               // record-based (may be null)
      given_at:             d.given_at,
      scheduled_date:       d.scheduled_date,
      given_by:             d.given_by,
      notes:                d.notes,
      remarks:              d.remarks,
      status:               d.status,
    });
  }

  // ── Pending + counters ────────────────────────────────────────────────────
  let totalDosesCompleted = 0;
  let nextDue             = null;
  let overdueAlert        = null;
  const pendingDoses      = [];

  for (const d of doses) {
    if (d.status === "completed") { totalDosesCompleted++; continue; }

    if (!overdueAlert && d.status === "overdue") {
      overdueAlert = { vaccine_name: d.vaccine_name, dose_label: d.dose_label };
    }
    if (!nextDue && (d.status === "due_soon" || d.status === "not_yet_due")) {
      nextDue = {
        vaccine_name:      d.vaccine_name,
        dose_label:        d.dose_label,
        schedule_label:    d.schedule_label,
        due_date_estimate: d.due_date,
        theoretical_date:  d.theoretical_due_date,
        status:            d.status,
      };
    }

    let waitingFor = null;
    if (d.status === "locked" && d.dose_number > 1) {
      const prev = schedules.find(
        s => s.vaccine_key === d.vaccine_key && s.dose_number === d.dose_number - 1
      );
      if (prev) waitingFor = `${prev.vaccine_name} (${prev.dose_label})`;
    }

    pendingDoses.push({
      vaccine_name:         d.vaccine_name,
      vaccine_key:          d.vaccine_key,
      schedule_id:          d.schedule_id,   // ← needed by Flutter for appointment linkage
      dose_number:          d.dose_number,
      dose_label:           d.dose_label,
      schedule_label:       d.schedule_label,
      due_date_estimate:    d.due_date,          // null when locked
      theoretical_due_date: d.theoretical_due_date,
      days_overdue:         d.status === "overdue" && d.due_date
        ? Math.max(0, Math.floor((Date.now() - new Date(d.due_date).getTime()) / 86_400_000))
        : null,
      status:     d.status,
      waiting_for: waitingFor,
    });
  }

  // Sort: overdue (most overdue first) > due_soon > not_yet_due > locked
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

  const hasOverdue  = pendingDoses.some(d => d.status === "overdue");
  const hasDueSoon  = pendingDoses.some(d => d.status === "due_soon");
  const dobStr      = patient.dob ? new Date(patient.dob).toISOString().split("T")[0] : null;
  const dobFlagged  = patient.dob_needs_verification === 1 || patient.dob_needs_verification === true;

  return {
    child_name:             patient.child_fullname || patient.mother_fullname || "Unknown",
    dob:                    dobStr,
    sex:                    patient.sex || null,
    mother_name:            patient.mother_fullname || null,
    father_name:            patient.father_fullname || null,
    place_of_birth:         patient.place_of_birth || null,
    address:                patient.address || null,
    health_center:          patient.health_center || null,
    dob_needs_verification: dobFlagged,
    ...(isAdmin ? { service_type: patient.service_type, not_immunization: false } : {}),
    age_in_days:            age,
    total_doses_required:   schedules.length,
    total_doses_completed:  totalDosesCompleted,
    fully_up_to_date:       !hasOverdue && !hasDueSoon,
    overall_status:         hasOverdue ? "overdue" : hasDueSoon ? "action_needed" : "up_to_date",
    vaccines:               Array.from(vaccineMap.values()),
    pending_doses:          pendingDoses,
    next_due:               nextDue,
    overdue_alert:          overdueAlert,
  };
}


// ─── GET /vaccines/card/:patientId ───────────────────────────────────────────
router.get("/card/:patientId", authenticateUser, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }
  try {
    const data = await buildVaccineCard(patientId, false);
    return res.json({ success: true, data });
  } catch (err) {
    console.error("[GET /vaccines/card]", err);
    return res.status(err.statusCode || 500).json({ success: false, message: err.message });
  }
});

// ─── GET /vaccines/admin/card/:patientId ─────────────────────────────────────
router.get("/admin/card/:patientId", authenticateAdmin, async (req, res) => {
  const patientId = parseInt(req.params.patientId, 10);
  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: "Invalid patient ID" });
  }
  try {
    const data = await buildVaccineCard(patientId, true);
    return res.json({ success: true, data });
  } catch (err) {
    console.error("[GET /vaccines/admin/card]", err);
    return res.status(err.statusCode || 500).json({ success: false, message: err.message });
  }
});


// ─── POST /vaccines/record ────────────────────────────────────────────────────
/**
 * Admin marks a dose as given.
 *
 * Body: { patient_id, vaccine_schedule_id, given_by?, notes?, remarks?,
 *          completed_by_user_id?, given_at_override? }
 *
 * given_at_override: optional ISO date string the admin can pass if the actual
 *   administration date differs from today (e.g. retroactive entry).
 *   Defaults to NOW() when absent.
 *
 * After saving, recomputes scheduled_date on this record and
 * updates the NEXT dose's scheduled_date immediately.
 * Emits vaccineRecordUpdated to the patient's Socket.IO room.
 */
router.post("/record", authenticateAdmin, async (req, res) => {
  const {
    patient_id,
    vaccine_schedule_id,
    given_by,
    notes,
    remarks,
    completed_by_user_id,
    given_at_override,    // optional ISO date "YYYY-MM-DD" or datetime
  } = req.body;

  if (!patient_id || !vaccine_schedule_id) {
    return res.status(400).json({
      success: false,
      message: "patient_id and vaccine_schedule_id are required",
    });
  }

  try {
    // 1. Fetch target schedule row
    const [scheds] = await db.execute(
      `SELECT id, vaccine_key, dose_number, vaccine_name, dose_label,
              schedule_from, interval_days, due_days_from_birth
       FROM vaccine_schedules WHERE id = ? LIMIT 1`,
      [vaccine_schedule_id]
    );
    if (!scheds.length) {
      return res.status(404).json({ success: false, message: "Vaccine schedule not found" });
    }
    const target = scheds[0];

    // 2. Sequential lock check: prior dose(s) in same vaccine_key must be given
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

    // 3. Resolve the actual given timestamp
    let givenAtValue;
    if (given_at_override) {
      const parsed = new Date(given_at_override);
      givenAtValue = isNaN(parsed.getTime()) ? new Date() : parsed;
    } else {
      givenAtValue = new Date();
    }
    const givenAtISO = givenAtValue.toISOString();
    const givenAtDate = givenAtISO.split("T")[0]; // "YYYY-MM-DD"

    // 4. Fetch patient DOB for theoretical date calculation
    const [pts] = await db.execute(
      `SELECT dob FROM patients WHERE id = ? LIMIT 1`,
      [patient_id]
    );
    const dob = pts.length ? pts[0].dob : null;
    const theorDate = addDaysToDate(dob, target.due_days_from_birth);

    // 5. Upsert child_vaccine_records
    await db.execute(
      `INSERT INTO child_vaccine_records
         (patient_id, vaccine_schedule_id, given_at, given_by, notes, remarks,
          scheduled_date, completed_by_user_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?) AS new_row
       ON DUPLICATE KEY UPDATE
         given_at              = COALESCE(given_at, new_row.given_at),
         given_by              = COALESCE(new_row.given_by, given_by),
         notes                 = COALESCE(new_row.notes, notes),
         remarks               = COALESCE(new_row.remarks, remarks),
         scheduled_date        = COALESCE(new_row.scheduled_date, scheduled_date),
         completed_by_user_id  = COALESCE(new_row.completed_by_user_id, completed_by_user_id),
         updated_at            = CURRENT_TIMESTAMP`,
      [
        patient_id,
        vaccine_schedule_id,
        givenAtISO,
        given_by              || null,
        notes                 || null,
        remarks               || null,
        theorDate             || null,
        completed_by_user_id  || null,
      ]
    );

    // Fetch back the saved record
    const [saved] = await db.execute(
      `SELECT id AS record_id, given_at, given_by, scheduled_date
       FROM child_vaccine_records
       WHERE patient_id = ? AND vaccine_schedule_id = ? LIMIT 1`,
      [patient_id, vaccine_schedule_id]
    );
    const record = saved[0];

    // 6. Recompute the NEXT dose in this vaccine_key if one exists
    //    Update its scheduled_date = givenAtDate + next.interval_days
    const [nextScheds] = await db.execute(
      `SELECT id, interval_days, schedule_from, due_days_from_birth,
              vaccine_name, dose_label
       FROM vaccine_schedules
       WHERE vaccine_key = ? AND dose_number = ?
       LIMIT 1`,
      [target.vaccine_key, target.dose_number + 1]
    );

    let nextDueDateComputed = null;
    if (nextScheds.length) {
      const nextSched = nextScheds[0];
      if (nextSched.schedule_from === "previous_dose") {
        nextDueDateComputed = addDaysToDate(givenAtDate, nextSched.interval_days);
      } else {
        nextDueDateComputed = addDaysToDate(dob, nextSched.interval_days);
      }
      if (nextDueDateComputed) {
        // Upsert the next dose's scheduled_date so it reflects the actual shift
        await db.execute(
          `INSERT INTO child_vaccine_records (patient_id, vaccine_schedule_id, scheduled_date)
           VALUES (?, ?, ?) AS new_row
           ON DUPLICATE KEY UPDATE
             scheduled_date = new_row.scheduled_date,
             updated_at     = CURRENT_TIMESTAMP`,
          [patient_id, nextSched.id, nextDueDateComputed]
        );
      }

      // ── Step 1: Create vaccine dose reminders for the next dose ────────────
      // Fetch the patient's user_id (parent/guardian who receives notifications)
      // and child name for the notification message.
      try {
        const [patientRows] = await db.execute(
          `SELECT user_id, child_fullname FROM patients WHERE id = ? LIMIT 1`,
          [patient_id]
        );
        const parentUserId = patientRows.length ? patientRows[0].user_id : null;
        const childName    = patientRows.length ? patientRows[0].child_fullname : null;

        if (parentUserId) {
          const reminderResult = await createVaccineDoseReminders({
            patient_id,
            user_id:             parentUserId,
            vaccine_schedule_id: nextSched.id,
            vaccine_name:        nextSched.vaccine_name,
            dose_label:          nextSched.dose_label,
            due_date:            nextDueDateComputed,
            child_name:          childName,
          });
          console.log(
            `💉 [VaccineReminder] Reminders for patient ${patient_id}: ` +
            `created=${reminderResult.created}, skipped=${reminderResult.skipped}, ` +
            `overdue=${reminderResult.overdue}`
          );
        } else {
          console.warn(
            `⚠️ [VaccineReminder] Patient ${patient_id} has no linked user_id — ` +
            `cannot create vaccine dose reminders`
          );
        }
      } catch (reminderErr) {
        // Non-fatal — reminder creation failure should NOT abort the dose record save
        console.error(`❌ [VaccineReminder] Failed to create reminders for patient ${patient_id}:`, reminderErr);
      }
    } else {
      // No next dose exists — check if this was the LAST dose and congratulate
      try {
        const [patientRows] = await db.execute(
          `SELECT user_id, child_fullname FROM patients WHERE id = ? LIMIT 1`,
          [patient_id]
        );
        const parentUserId = patientRows.length ? patientRows[0].user_id : null;
        const childName    = patientRows.length ? patientRows[0].child_fullname : null;

        if (parentUserId) {
          // Count remaining non-completed doses to confirm all are done
          const [remaining] = await db.execute(
            `SELECT COUNT(*) AS cnt
               FROM vaccine_schedules vs
               LEFT JOIN child_vaccine_records cvr
                 ON  cvr.vaccine_schedule_id = vs.id
                 AND cvr.patient_id          = ?
                 AND cvr.given_at IS NOT NULL
              WHERE cvr.id IS NULL`,
            [patient_id]
          );
          if (remaining[0].cnt === 0) {
            await sendAllDosesCompletedNotification({ patient_id, user_id: parentUserId, child_name: childName });
          }
        }
      } catch (congrErr) {
        console.error(`❌ [VaccineReminder] Failed to send completion notification:`, congrErr);
      }
    }

    // 7. Emit realtime event
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
        next_dose_due_date:  nextDueDateComputed,
        message:             `${target.vaccine_name} (${target.dose_label}) has been marked as completed.`,
      });
    }

    return res.status(201).json({
      success: true,
      message: `${target.vaccine_name} (${target.dose_label}) marked as given.`,
      data: {
        record_id:             record.record_id,
        vaccine_schedule_id:   vaccine_schedule_id,
        given_at:              record.given_at,
        given_by:              record.given_by,
        scheduled_date:        record.scheduled_date,
        next_dose_due_date:    nextDueDateComputed,
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
 * When a dose is removed its given_at is cleared so the next dose's
 * record-based due date becomes null (locked) on the next API fetch.
 */
router.delete("/record/:recordId", authenticateAdmin, async (req, res) => {
  const recordId = parseInt(req.params.recordId, 10);
  if (!recordId) {
    return res.status(400).json({ success: false, message: "Invalid record ID" });
  }

  try {
    const [rows] = await db.execute(
      `SELECT cvr.id, cvr.patient_id, cvr.vaccine_schedule_id,
              vs.vaccine_name, vs.dose_label, vs.vaccine_key, vs.dose_number
       FROM child_vaccine_records cvr
       JOIN vaccine_schedules vs ON vs.id = cvr.vaccine_schedule_id
       WHERE cvr.id = ? LIMIT 1`,
      [recordId]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "Record not found" });
    }
    const rec = rows[0];

    // Hard-delete the record (given_at disappears, next dose becomes locked on next fetch)
    await db.execute("DELETE FROM child_vaccine_records WHERE id = ?", [recordId]);

    // Also clear the next dose's scheduled_date since it was anchored to this given_at
    const [nextScheds] = await db.execute(
      `SELECT id FROM vaccine_schedules
       WHERE vaccine_key = ? AND dose_number = ? LIMIT 1`,
      [rec.vaccine_key, rec.dose_number + 1]
    );
    if (nextScheds.length) {
      await db.execute(
        `UPDATE child_vaccine_records
            SET scheduled_date = NULL,
                updated_at     = CURRENT_TIMESTAMP
          WHERE patient_id          = ?
            AND vaccine_schedule_id = ?`,
        [rec.patient_id, nextScheds[0].id]
      );
    }

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


// ─── GET /vaccines/admin/badge/:patientId ─────────────────────────────────────
/**
 * Lightweight badge summary (status pill only — no full vaccine list).
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
    const patient  = patients[0];
    const svcType  = (patient.service_type || "").toLowerCase();
    if (!svcType.includes("immun")) {
      return res.json({ success: true, data: { not_immunization: true } });
    }

    const dobFlagged = patient.dob_needs_verification === 1 || patient.dob_needs_verification === true;
    if (dobFlagged) {
      return res.json({ success: true, data: { dob_needs_verification: true, overall_status: "unverified" } });
    }

    const age = ageInDays(patient.dob);

    const [schedules] = await db.execute(
      `SELECT id, vaccine_key, dose_number, schedule_from, interval_days,
              due_days_from_birth, due_days_max
       FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );
    const [records] = await db.execute(
      `SELECT vaccine_schedule_id, given_at
       FROM child_vaccine_records WHERE patient_id = ? AND given_at IS NOT NULL`,
      [patientId]
    );
    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    const doses = buildDoseList(schedules, recMap, patient.dob, age);

    let totalRequired  = schedules.length;
    let totalCompleted = 0;
    let hasOverdue     = false;
    let hasDueSoon     = false;
    let nextDueDate    = null;

    for (const d of doses) {
      if (d.status === "completed") { totalCompleted++; continue; }
      if (d.status === "overdue")  hasOverdue = true;
      if (d.status === "due_soon" && !nextDueDate) {
        nextDueDate = d.due_date;
        hasDueSoon  = true;
      }
    }

    return res.json({
      success: true,
      data: {
        overall_status:         hasOverdue ? "overdue" : hasDueSoon ? "action_needed" : "up_to_date",
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
