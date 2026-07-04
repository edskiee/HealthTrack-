/**
 * vaccines.js  —  Vaccine Tracking API Routes
 * ─────────────────────────────────────────────────────────────────────────────
 * Mount in your Express app with:
 *   const vaccineRoutes = require('./routes/vaccines');
 *   app.use('/vaccines', authenticateToken, vaccineRoutes);
 *
 * Assumes:
 *   • `pool`   — your existing pg Pool (require('../db') or wherever it lives)
 *   • `io`     — your Socket.IO server instance (passed via app.set / require)
 *   • `authenticateToken` middleware already applied at mount point
 *
 * Endpoints exposed:
 *   GET  /vaccines/dashboard/:patientId   — today summary + next-due vaccine
 *   GET  /vaccines/card/:patientId        — full dose-by-dose schedule card
 *   POST /vaccines/record                 — admin marks a dose as given
 *   DELETE /vaccines/record/:recordId     — admin un-marks a dose (corrections)
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const express = require('express');
const router  = express.Router();

// ─── helpers ─────────────────────────────────────────────────────────────────

/**
 * Compute a dose's live status given the child's age in days and whether
 * the dose has already been given.
 *
 * Status values (match the Flutter VaccineDoseStatus enum exactly):
 *   completed | due_soon | overdue | not_yet_due | locked
 *
 * "locked" is only set by the caller when a prior dose in the same vaccine
 * group is not yet completed — this function never returns "locked".
 */
function computeDoseStatus(ageInDays, schedule, givenAt) {
  if (givenAt) return 'completed';

  const { due_days_from_birth: dueDays, due_days_max: dueMax } = schedule;

  if (ageInDays > dueMax)  return 'overdue';
  if (ageInDays >= dueDays) return 'due_soon';
  return 'not_yet_due';
}

/**
 * Given an ISO date-of-birth string, return the child's age in whole days
 * relative to "now" (server clock, UTC).  Returns 0 for invalid/missing DOB.
 */
function ageInDaysFromDob(dob) {
  if (!dob) return 0;
  const birth = new Date(dob);
  if (isNaN(birth.getTime())) return 0;
  const diffMs = Date.now() - birth.getTime();
  return Math.max(0, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
}

/** Reusable: fetch patient row (id, dob) — throws 404 if not found. */
async function requirePatient(pool, patientId) {
  const result = await pool.query(
    `SELECT p.id,
            COALESCE(p.dob, p.date_of_birth) AS dob,
            p.child_fullname,
            p.mother_fullname
     FROM   patients p
     WHERE  p.id = $1
     LIMIT  1`,
    [patientId]
  );
  if (result.rows.length === 0) {
    const err = new Error(`Patient ${patientId} not found`);
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

/**
 * Fetch all schedule rows plus the child's existing vaccine records
 * in a single round-trip.  Returns { schedules, recordsByScheduleId }.
 */
async function fetchSchedulesAndRecords(pool, patientId) {
  // All master schedule rows, ordered by sort_order
  const schedQ = await pool.query(
    `SELECT id, vaccine_name, vaccine_key, dose_number, dose_label,
            schedule_label, due_days_from_birth, due_days_max, sort_order
     FROM   vaccine_schedules
     ORDER  BY sort_order, dose_number`
  );

  // All records for this child
  const recQ = await pool.query(
    `SELECT cvr.id AS record_id,
            cvr.vaccine_schedule_id,
            cvr.given_at,
            cvr.given_by,
            cvr.notes
     FROM   child_vaccine_records cvr
     WHERE  cvr.patient_id = $1`,
    [patientId]
  );

  // Index records by schedule id for O(1) lookup
  const recordsByScheduleId = {};
  for (const row of recQ.rows) {
    recordsByScheduleId[row.vaccine_schedule_id] = row;
  }

  return { schedules: schedQ.rows, recordsByScheduleId };
}

// ─── GET /vaccines/dashboard/:patientId ──────────────────────────────────────
/**
 * Returns a compact summary for the Dashboard screen:
 * {
 *   success: true,
 *   data: {
 *     child_name: string,
 *     today_completed: number,   // doses whose given_at is local-today (server UTC)
 *     today_in_progress: number, // doses that are due_soon today (not yet given)
 *     today_missed: number,      // doses that became overdue today
 *     last_completed: { vaccine_name, dose_label, given_at, given_by } | null,
 *     next_due: { vaccine_name, dose_label, schedule_label, due_date_estimate } | null,
 *     fully_up_to_date: boolean
 *   }
 * }
 */
router.get('/dashboard/:patientId', async (req, res) => {
  const pool = req.app.get('pool');
  const patientId = parseInt(req.params.patientId, 10);

  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid patient ID' });
  }

  try {
    const patient = await requirePatient(pool, patientId);
    const ageInDays = ageInDaysFromDob(patient.dob);
    const dob = patient.dob ? new Date(patient.dob) : null;

    const { schedules, recordsByScheduleId } = await fetchSchedulesAndRecords(pool, patientId);

    // ── Today boundaries (UTC) ──────────────────────────────────────────────
    const now = new Date();
    const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const todayEnd   = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

    // ── Per-vaccine sequential lock state ──────────────────────────────────
    // Track the last computed status per vaccine_key so we can enforce the lock.
    // Within each vaccine_key group (sorted by dose_number), if any dose is not
    // 'completed', all subsequent doses for that key are 'locked'.
    const vaccineGroupLocked = {}; // vaccine_key → true if locked

    let todayCompleted  = 0;
    let todayInProgress = 0;
    let todayMissed     = 0;
    let lastCompleted   = null;
    let nextDue         = null;

    for (const sched of schedules) {
      const record = recordsByScheduleId[sched.id] || null;
      const givenAt = record ? record.given_at : null;

      // Sequential lock: if this vaccine_key was flagged locked, skip computation
      let status;
      if (vaccineGroupLocked[sched.vaccine_key]) {
        status = 'locked';
      } else {
        status = computeDoseStatus(ageInDays, sched, givenAt);
        // If this dose is NOT completed, lock all subsequent doses of same vaccine
        if (status !== 'completed') {
          vaccineGroupLocked[sched.vaccine_key] = true;
        }
      }

      // ── Today counts ─────────────────────────────────────────────────────
      if (status === 'completed' && givenAt) {
        const gDate = new Date(givenAt);
        if (gDate >= todayStart && gDate < todayEnd) {
          todayCompleted++;
        }
      } else if (status === 'due_soon') {
        // Due-soon doses that are due *today* count as in-progress
        if (dob) {
          const dueDateMs = dob.getTime() + sched.due_days_from_birth * 24 * 60 * 60 * 1000;
          const dueDate = new Date(dueDateMs);
          if (dueDate >= todayStart && dueDate < todayEnd) {
            todayInProgress++;
          }
        }
      } else if (status === 'overdue') {
        // Missed: overdue and the max window expired today or earlier
        if (dob) {
          const maxDateMs = dob.getTime() + sched.due_days_max * 24 * 60 * 60 * 1000;
          const maxDate = new Date(maxDateMs);
          if (maxDate >= todayStart && maxDate < todayEnd) {
            todayMissed++;
          }
        }
      }

      // ── Last completed ───────────────────────────────────────────────────
      if (status === 'completed' && givenAt) {
        if (
          !lastCompleted ||
          new Date(givenAt) > new Date(lastCompleted.given_at)
        ) {
          lastCompleted = {
            vaccine_name: sched.vaccine_name,
            dose_label:   sched.dose_label,
            given_at:     givenAt,
            given_by:     record.given_by || null,
          };
        }
      }

      // ── Next due ─────────────────────────────────────────────────────────
      // Pick the earliest non-completed, non-locked dose as "next up"
      if ((status === 'due_soon' || status === 'not_yet_due') && !nextDue) {
        let dueDateEstimate = null;
        if (dob) {
          const dueDateMs = dob.getTime() + sched.due_days_from_birth * 24 * 60 * 60 * 1000;
          dueDateEstimate = new Date(dueDateMs).toISOString().split('T')[0];
        }
        nextDue = {
          vaccine_name:      sched.vaccine_name,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          status:            status,
        };
      }
    }

    // "Fully up to date" means every applicable (non-locked, non-not_yet_due) dose is completed
    // Simpler definition: no dose is overdue or due_soon
    const hasActionable = schedules.some(sched => {
      const record = recordsByScheduleId[sched.id] || null;
      const givenAt = record ? record.given_at : null;
      if (givenAt) return false; // completed
      const status = computeDoseStatus(ageInDays, sched, givenAt);
      return status === 'overdue' || status === 'due_soon';
    });
    const fullyUpToDate = !hasActionable && lastCompleted !== null;

    return res.json({
      success: true,
      data: {
        child_name:       patient.child_fullname || patient.mother_fullname || 'Unknown',
        today_completed:  todayCompleted,
        today_in_progress: todayInProgress,
        today_missed:     todayMissed,
        last_completed:   lastCompleted,
        next_due:         nextDue,
        fully_up_to_date: fullyUpToDate,
      },
    });
  } catch (err) {
    console.error('[GET /vaccines/dashboard] error:', err);
    const status = err.statusCode || 500;
    return res.status(status).json({ success: false, message: err.message || 'Server error' });
  }
});

// ─── GET /vaccines/card/:patientId ───────────────────────────────────────────
/**
 * Returns the full vaccine card — every vaccine in the master schedule with
 * each dose's live status, computed fresh on every request.
 *
 * Response shape:
 * {
 *   success: true,
 *   data: {
 *     child_name: string,
 *     dob: string | null,
 *     age_in_days: number,
 *     vaccines: [
 *       {
 *         vaccine_name: string,
 *         vaccine_key: string,
 *         doses: [
 *           {
 *             schedule_id: number,
 *             record_id: number | null,
 *             dose_number: number,
 *             dose_label: string,
 *             schedule_label: string,
 *             due_date_estimate: string | null,  // ISO date
 *             given_at: string | null,
 *             given_by: string | null,
 *             notes: string | null,
 *             status: 'completed'|'due_soon'|'overdue'|'not_yet_due'|'locked'
 *           }
 *         ]
 *       }
 *     ],
 *     next_due: { vaccine_name, dose_label, schedule_label, due_date_estimate } | null,
 *     overdue_alert: { vaccine_name, dose_label } | null   // first overdue dose
 *   }
 * }
 */
router.get('/card/:patientId', async (req, res) => {
  const pool = req.app.get('pool');
  const patientId = parseInt(req.params.patientId, 10);

  if (!patientId || patientId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid patient ID' });
  }

  try {
    const patient = await requirePatient(pool, patientId);
    const ageInDays = ageInDaysFromDob(patient.dob);
    const dob = patient.dob ? new Date(patient.dob) : null;

    const { schedules, recordsByScheduleId } = await fetchSchedulesAndRecords(pool, patientId);

    // Group schedules by vaccine_key, preserving sort_order
    const vaccineMap = new Map(); // vaccine_key → { vaccine_name, doses: [] }
    for (const sched of schedules) {
      if (!vaccineMap.has(sched.vaccine_key)) {
        vaccineMap.set(sched.vaccine_key, {
          vaccine_name: sched.vaccine_name,
          vaccine_key:  sched.vaccine_key,
          doses: [],
        });
      }
      vaccineMap.get(sched.vaccine_key).doses.push(sched);
    }

    // Build output, computing live status and enforcing sequential lock
    const vaccinesOut = [];
    const vaccineGroupLocked = {};
    let nextDue = null;
    let overdueAlert = null;

    for (const [vaccineKey, group] of vaccineMap.entries()) {
      const dosesOut = [];

      for (const sched of group.doses) {
        const record  = recordsByScheduleId[sched.id] || null;
        const givenAt = record ? record.given_at : null;

        let status;
        if (vaccineGroupLocked[vaccineKey]) {
          status = 'locked';
        } else {
          status = computeDoseStatus(ageInDays, sched, givenAt);
          if (status !== 'completed') {
            vaccineGroupLocked[vaccineKey] = true;
          }
        }

        // Compute estimated due date from DOB + offset
        let dueDateEstimate = null;
        if (dob) {
          const dueDateMs = dob.getTime() + sched.due_days_from_birth * 24 * 60 * 60 * 1000;
          dueDateEstimate = new Date(dueDateMs).toISOString().split('T')[0];
        }

        dosesOut.push({
          schedule_id:       sched.id,
          record_id:         record ? record.record_id : null,
          dose_number:       sched.dose_number,
          dose_label:        sched.dose_label,
          schedule_label:    sched.schedule_label,
          due_date_estimate: dueDateEstimate,
          given_at:          givenAt || null,
          given_by:          record ? record.given_by || null : null,
          notes:             record ? record.notes  || null : null,
          status,
        });

        // First overdue dose → alert banner
        if (!overdueAlert && status === 'overdue') {
          overdueAlert = {
            vaccine_name: sched.vaccine_name,
            dose_label:   sched.dose_label,
          };
        }

        // First actionable non-completed dose → next due suggestion
        if (!nextDue && (status === 'due_soon' || status === 'not_yet_due')) {
          nextDue = {
            vaccine_name:      sched.vaccine_name,
            dose_label:        sched.dose_label,
            schedule_label:    sched.schedule_label,
            due_date_estimate: dueDateEstimate,
            status,
          };
        }
      }

      vaccinesOut.push({ ...group, doses: dosesOut });
    }

    return res.json({
      success: true,
      data: {
        child_name:    patient.child_fullname || patient.mother_fullname || 'Unknown',
        dob:           patient.dob ? new Date(patient.dob).toISOString().split('T')[0] : null,
        age_in_days:   ageInDays,
        vaccines:      vaccinesOut,
        next_due:      nextDue,
        overdue_alert: overdueAlert,
      },
    });
  } catch (err) {
    console.error('[GET /vaccines/card] error:', err);
    const status = err.statusCode || 500;
    return res.status(status).json({ success: false, message: err.message || 'Server error' });
  }
});

// ─── POST /vaccines/record ────────────────────────────────────────────────────
/**
 * Admin marks a dose as given (completed).
 * Body: { patient_id, vaccine_schedule_id, given_by?, notes? }
 *
 * Server-side sequential lock enforcement:
 *   Rejects the request if any prior dose (lower dose_number, same vaccine_key)
 *   for this patient is not yet recorded as given.
 *
 * On success, emits `vaccineRecordUpdated` to the patient's Socket.IO room.
 */
router.post('/record', async (req, res) => {
  const pool = req.app.get('pool');
  const io   = req.app.get('io');

  const { patient_id, vaccine_schedule_id, given_by, notes } = req.body;

  if (!patient_id || !vaccine_schedule_id) {
    return res.status(400).json({
      success: false,
      message: 'patient_id and vaccine_schedule_id are required',
    });
  }

  try {
    // 1. Fetch the target schedule row
    const schedQ = await pool.query(
      `SELECT id, vaccine_key, dose_number, vaccine_name, dose_label
       FROM   vaccine_schedules
       WHERE  id = $1`,
      [vaccine_schedule_id]
    );
    if (schedQ.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Vaccine schedule not found' });
    }
    const targetSched = schedQ.rows[0];

    // 2. Sequential lock check: all prior doses of same vaccine_key must be completed
    if (targetSched.dose_number > 1) {
      const priorQ = await pool.query(
        `SELECT vs.dose_number
         FROM   vaccine_schedules vs
         LEFT   JOIN child_vaccine_records cvr
                ON  cvr.vaccine_schedule_id = vs.id
                AND cvr.patient_id          = $1
                AND cvr.given_at IS NOT NULL
         WHERE  vs.vaccine_key  = $2
           AND  vs.dose_number  < $3
           AND  cvr.id IS NULL
         LIMIT  1`,
        [patient_id, targetSched.vaccine_key, targetSched.dose_number]
      );
      if (priorQ.rows.length > 0) {
        return res.status(422).json({
          success: false,
          message: `Cannot mark this dose as given — dose ${priorQ.rows[0].dose_number} must be completed first.`,
        });
      }
    }

    // 3. Upsert the record (idempotent — re-marking an already-given dose is a no-op update)
    const upsertQ = await pool.query(
      `INSERT INTO child_vaccine_records
         (patient_id, vaccine_schedule_id, given_at, given_by, notes)
       VALUES ($1, $2, NOW(), $3, $4)
       ON CONFLICT (patient_id, vaccine_schedule_id)
       DO UPDATE SET
         given_at = COALESCE(child_vaccine_records.given_at, EXCLUDED.given_at),
         given_by = COALESCE(EXCLUDED.given_by, child_vaccine_records.given_by),
         notes    = COALESCE(EXCLUDED.notes,    child_vaccine_records.notes),
         updated_at = NOW()
       RETURNING id, given_at, given_by`,
      [patient_id, vaccine_schedule_id, given_by || null, notes || null]
    );

    const savedRecord = upsertQ.rows[0];

    // 4. Emit realtime event to the patient's room so the Flutter app updates instantly
    if (io) {
      io.to(`user_${patient_id}`).emit('vaccineRecordUpdated', {
        type:               'vaccine_record_updated',
        patient_id:         patient_id,
        vaccine_schedule_id: vaccine_schedule_id,
        vaccine_name:       targetSched.vaccine_name,
        dose_label:         targetSched.dose_label,
        given_at:           savedRecord.given_at,
        given_by:           savedRecord.given_by,
        message:            `${targetSched.vaccine_name} (${targetSched.dose_label}) has been marked as completed.`,
      });
    }

    return res.status(201).json({
      success: true,
      message: `${targetSched.vaccine_name} (${targetSched.dose_label}) marked as given.`,
      data: {
        record_id:          savedRecord.id,
        vaccine_schedule_id: vaccine_schedule_id,
        given_at:           savedRecord.given_at,
        given_by:           savedRecord.given_by,
      },
    });
  } catch (err) {
    console.error('[POST /vaccines/record] error:', err);
    return res.status(500).json({ success: false, message: err.message || 'Server error' });
  }
});

// ─── DELETE /vaccines/record/:recordId ───────────────────────────────────────
/**
 * Admin un-marks a dose (correction / data entry error).
 * Emits `vaccineRecordUpdated` to patient room on success.
 */
router.delete('/record/:recordId', async (req, res) => {
  const pool = req.app.get('pool');
  const io   = req.app.get('io');
  const recordId = parseInt(req.params.recordId, 10);

  if (!recordId) {
    return res.status(400).json({ success: false, message: 'Invalid record ID' });
  }

  try {
    // Fetch record before deletion so we can emit the right event
    const fetchQ = await pool.query(
      `SELECT cvr.id, cvr.patient_id, cvr.vaccine_schedule_id,
              vs.vaccine_name, vs.dose_label
       FROM   child_vaccine_records cvr
       JOIN   vaccine_schedules vs ON vs.id = cvr.vaccine_schedule_id
       WHERE  cvr.id = $1`,
      [recordId]
    );
    if (fetchQ.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Record not found' });
    }
    const rec = fetchQ.rows[0];

    await pool.query('DELETE FROM child_vaccine_records WHERE id = $1', [recordId]);

    if (io) {
      io.to(`user_${rec.patient_id}`).emit('vaccineRecordUpdated', {
        type:               'vaccine_record_removed',
        patient_id:         rec.patient_id,
        vaccine_schedule_id: rec.vaccine_schedule_id,
        vaccine_name:       rec.vaccine_name,
        dose_label:         rec.dose_label,
        message:            `${rec.vaccine_name} (${rec.dose_label}) completion was removed.`,
      });
    }

    return res.json({ success: true, message: 'Vaccine record removed.' });
  } catch (err) {
    console.error('[DELETE /vaccines/record] error:', err);
    return res.status(500).json({ success: false, message: err.message || 'Server error' });
  }
});

module.exports = router;
