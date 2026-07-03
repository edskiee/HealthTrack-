const db = require("../config/db");

// Get all health records with complete patient information — paginated
exports.getHealthRecords = async (req, res) => {
  try {
    // ── Pagination ──────────────────────────────────────────────────────────
    const page   = Math.max(1,   Number(req.query.page  || 1)  | 0);
    const limit  = Math.min(100, Math.max(1, Number(req.query.limit || 20) | 0));
    const offset = (page - 1) * limit;

    // ── Server-side filters ─────────────────────────────────────────────────
    const searchQ      = (req.query.q           || '').trim();
    const serviceType  = (req.query.serviceType || '').trim();
    const recordType   = (req.query.recordType  || '').trim();
    const genderFilter = (req.query.gender      || '').trim();
    const startDate    = (req.query.startDate   || '').trim();
    const endDate      = (req.query.endDate     || '').trim();

    const whereClauses = [];
    const params       = [];

    if (searchQ) {
      // Match on child name, mother name, OR any child belonging to a parent whose
      // other children also match — so searching "Prince Malunoc" finds the parent card
      // even if the health record row was for a sibling named "Baby Cruz".
      whereClauses.push(`(
        p.child_fullname  LIKE ? OR
        p.mother_fullname LIKE ? OR
        hr.title          LIKE ? OR
        p.user_id IN (
          SELECT DISTINCT user_id FROM patients
          WHERE user_id IS NOT NULL AND child_fullname LIKE ?
        )
      )`);
      const term = `%${searchQ}%`;
      params.push(term, term, term, term);
    }
    if (serviceType && serviceType !== 'All') {
      whereClauses.push('p.service_type = ?');
      params.push(serviceType);
    }
    if (recordType && recordType !== 'All') {
      whereClauses.push('hr.record_type = ?');
      params.push(recordType);
    }
    if (genderFilter && genderFilter !== 'All') {
      whereClauses.push('p.sex = ?');
      params.push(genderFilter);
    }
    if (startDate) {
      whereClauses.push('DATE(hr.created_at) >= ?');
      params.push(startDate);
    }
    if (endDate) {
      whereClauses.push('DATE(hr.created_at) <= ?');
      params.push(endDate);
    }

    const whereSQL = whereClauses.length
      ? `WHERE ${whereClauses.join(' AND ')}`
      : '';

    // ── COUNT ───────────────────────────────────────────────────────────────
    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total
       FROM health_records hr
       LEFT JOIN patients p ON hr.patient_id = p.id
       ${whereSQL}`,
      params
    );
    const total      = Number(countRows[0].total);
    const totalPages = Math.ceil(total / limit);

    // ── Fetch page ──────────────────────────────────────────────────────────
    const sql = `
      SELECT
        hr.id,
        hr.id          AS record_id,
        hr.user_id,
        hr.patient_id,
        hr.record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.record_values,
        hr.unit,
        hr.date_recorded,
        hr.doctor_name,
        hr.clinic_hospital,
        hr.attachments,
        hr.created_at,
        hr.updated_at,
        p.child_fullname        AS patient_name,
        p.mother_fullname,
        p.father_fullname,
        p.dob                   AS date_of_birth,
        p.dob_needs_verification,
        p.place_of_birth,
        p.birth_weight,
        p.birth_height,
        p.sex,
        p.address,
        p.record_type           AS patient_record_type,
        p.record_description    AS patient_record_description,
        p.service_type,
        p.health_center,
        p.barangay,
        p.family_number,
        p.family_serial_number,
        p.contact_number,
        p.spouse_name,
        p.living_children_count,
        p.monthly_income,
        p.religion,
        p.city,
        p.province,
        p.age                   AS patient_age,
        p.education,
        p.occupation,
        p.birth_attendant,
        p.facility_type,
        (SELECT COUNT(*) FROM patients pc WHERE pc.user_id = p.user_id) AS child_count
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      ${whereSQL}
      ORDER BY hr.created_at DESC
      LIMIT ? OFFSET ?
    `;

    const [results] = await db.query(sql, [...params, limit | 0, offset | 0]);

    const processedResults = (results || []).map(record => ({
      id:                       record.id || null,
      record_id:                record.id || null,
      user_id:                  record.user_id || null,
      patient_id:               record.patient_id || null,
      record_type:              record.record_type || "General",
      title:                    record.title || "Untitled Record",
      description:              record.description || "No description",
      diagnosis:                record.diagnosis || "No diagnosis",
      record_values:            record.record_values || "",
      unit:                     record.unit || "",
      date_recorded:            record.date_recorded || new Date().toISOString().split("T")[0],
      doctor_name:              record.doctor_name || "",
      clinic_hospital:          record.clinic_hospital || "",
      attachments:              record.attachments || null,
      created_at:               record.created_at || new Date().toISOString(),
      updated_at:               record.updated_at || new Date().toISOString(),
      // Patient fields
      patient_name:             record.patient_name || "Unknown Patient",
      name:                     record.patient_name || "Unknown Patient",
      mother_fullname:          record.mother_fullname || "Unknown",
      father_fullname:          record.father_fullname || "Unknown",
      date_of_birth:            record.date_of_birth || null,
      dob_needs_verification:   record.dob_needs_verification === 1 || record.dob_needs_verification === true,
      place_of_birth:           record.place_of_birth || "Unknown",
      birth_weight:             record.birth_weight || "Unknown",
      birth_height:             record.birth_height || "Unknown",
      sex:                      record.sex || "Unknown",
      gender:                   record.sex || "Unknown",
      address:                  record.address || "Unknown",
      patient_record_type:      record.patient_record_type || "General",
      patient_record_description: record.patient_record_description || "No description",
      service_type:             record.service_type || "immunization",
      health_center:            record.health_center || "",
      barangay:                 record.barangay || "",
      family_number:            record.family_number || "",
      family_serial_number:     record.family_serial_number || "",
      contact_number:           record.contact_number || "",
      spouse_name:              record.spouse_name || "",
      living_children_count:    record.living_children_count || 0,
      monthly_income:           record.monthly_income || 0,
      religion:                 record.religion || "",
      city:                     record.city || "",
      province:                 record.province || "",
      patient_age:              record.patient_age || 0,
      education:                record.education || "",
      occupation:               record.occupation || "",
      birth_attendant:          record.birth_attendant || "",
      facility_type:            record.facility_type || "",
      child_count:              Number(record.child_count) || 1,
      // Legacy aliases
      status:                   "Active",
      age:                      record.patient_age || 0,
      date_of_visit:            record.date_recorded || new Date().toISOString().split("T")[0],
    }));

    res.status(200).json({
      success:    true,
      data:       processedResults,
      total,
      page,
      totalPages,
    });
  } catch (error) {
    console.error("❌ Unexpected error in getHealthRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};
// Get all patients with their health records (including patients with no records)
exports.getAllPatientsWithRecords = async (req, res) => {
  try {
    const sql = `
      SELECT
        p.id                    AS patient_id,
        p.child_fullname,
        p.mother_fullname,
        p.father_fullname,
        p.dob,
        p.place_of_birth,
        p.birth_weight,
        p.birth_height,
        p.sex,
        p.address,
        p.record_type,
        p.record_description,
        p.status,
        p.created_at,
        p.service_type,
        p.health_center,
        p.barangay,
        p.family_number,
        p.family_serial_number,
        p.contact_number,
        p.spouse_name,
        p.living_children_count,
        p.monthly_income,
        p.religion,
        p.city,
        p.province,
        p.age                   AS patient_age,
        p.education,
        p.occupation,
        p.birth_attendant,
        p.facility_type,
        hr.id                   AS record_id,
        hr.record_type          AS health_record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.date_recorded,
        hr.created_at           AS record_created_at
      FROM patients p
      LEFT JOIN health_records hr ON p.id = hr.patient_id
      ORDER BY p.created_at DESC, hr.created_at DESC
    `;

    const [results] = await db.execute(sql);

    const patientMap = new Map();

    (results || []).forEach(row => {
      const patientId = row.patient_id;

      if (!patientMap.has(patientId)) {
        patientMap.set(patientId, {
          patient_id:             patientId,
          child_fullname:         row.child_fullname || "Unknown",
          mother_fullname:        row.mother_fullname || "Unknown",
          father_fullname:        row.father_fullname || "Unknown",
          dob:                    row.dob || null,
          place_of_birth:         row.place_of_birth || "Unknown",
          birth_weight:           row.birth_weight || "Unknown",
          birth_height:           row.birth_height || "Unknown",
          sex:                    row.sex || "Unknown",
          address:                row.address || "Unknown",
          record_type:            row.record_type || "General",
          record_description:     row.record_description || "No description",
          status:                 row.status || "Active",
          created_at:             row.created_at || new Date().toISOString(),
          service_type:           row.service_type || "immunization",
          health_center:          row.health_center || "",
          barangay:               row.barangay || "",
          family_number:          row.family_number || "",
          family_serial_number:   row.family_serial_number || "",
          contact_number:         row.contact_number || "",
          spouse_name:            row.spouse_name || "",
          living_children_count:  row.living_children_count || 0,
          monthly_income:         row.monthly_income || 0,
          religion:               row.religion || "",
          city:                   row.city || "",
          province:               row.province || "",
          patient_age:            row.patient_age || 0,
          education:              row.education || "",
          occupation:             row.occupation || "",
          birth_attendant:        row.birth_attendant || "",
          facility_type:          row.facility_type || "",
          health_records:         [],
        });
      }

      if (row.record_id) {
        patientMap.get(patientId).health_records.push({
          record_id:    row.record_id,
          record_type:  row.health_record_type || "General",
          title:        row.title || "Untitled Record",
          description:  row.description || "No description",
          diagnosis:    row.diagnosis || "No diagnosis",
          date_recorded: row.date_recorded || new Date().toISOString().split("T")[0],
          // Legacy alias
          date_of_visit: row.date_recorded || new Date().toISOString().split("T")[0],
          created_at:   row.record_created_at || new Date().toISOString(),
        });
      }
    });

    const patientsWithRecords = Array.from(patientMap.values());

    res.status(200).json({
      success: true,
      data:    patientsWithRecords,
      count:   patientsWithRecords.length,
    });
  } catch (error) {
    console.error("❌ Unexpected error in getAllPatientsWithRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};

// Add new health record
exports.addHealthRecord = async (req, res) => {
  try {
    const {
      patientId,
      userId,
      recordType,
      title,
      description,
      diagnosis,
      dateOfVisit,   // accepted for backwards-compat, stored as date_recorded
      dateRecorded,
      recordValues,
      unit,
      doctorName,
      clinicHospital,
    } = req.body;

    if (!patientId || !userId) {
      return res.status(400).json({
        success: false,
        message: "Patient ID and User ID are required",
      });
    }

    const sql = `
      INSERT INTO health_records (
        patient_id, user_id, record_type, title, description,
        diagnosis, record_values, unit, date_recorded, doctor_name, clinic_hospital
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      patientId,
      userId,
      recordType     || "General",
      title          || "Untitled Record",
      description    || "",
      diagnosis      || "",
      recordValues   || "",
      unit           || "",
      dateRecorded   || dateOfVisit || new Date().toISOString().split("T")[0],
      doctorName     || "",
      clinicHospital || "",
    ];

    const [result] = await db.execute(sql, values);
    const recordId = result.insertId;
    console.log("✅ Health record added successfully with ID:", recordId);

    if (req.app.locals.io) {
      req.app.locals.io.emit("healthRecordAdded", { record_id: recordId, patient_id: patientId });
    }

    const fetchSql = `
      SELECT
        hr.id,
        hr.id AS record_id,
        hr.user_id,
        hr.patient_id,
        hr.record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.record_values,
        hr.unit,
        hr.date_recorded,
        hr.doctor_name,
        hr.clinic_hospital,
        hr.created_at,
        p.child_fullname AS patient_name
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      WHERE hr.id = ?
    `;

    const [fetchResults] = await db.execute(fetchSql, [recordId]);
    const row = fetchResults[0] || {};

    res.status(201).json({
      success: true,
      message: "Health record added successfully",
      data: {
        ...row,
        record_id:    row.id,
        date_of_visit: row.date_recorded,
      },
    });
  } catch (error) {
    console.error("❌ Unexpected error in addHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};

// Update health record
exports.updateHealthRecord = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      recordType,
      title,
      description,
      diagnosis,
      dateOfVisit,   // legacy alias
      dateRecorded,
      recordValues,
      unit,
      doctorName,
      clinicHospital,
    } = req.body;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Record ID is required",
      });
    }

    const sql = `
      UPDATE health_records SET
        record_type    = ?,
        title          = ?,
        description    = ?,
        diagnosis      = ?,
        record_values  = ?,
        unit           = ?,
        date_recorded  = ?,
        doctor_name    = ?,
        clinic_hospital = ?,
        updated_at     = CURRENT_TIMESTAMP
      WHERE id = ?
    `;

    const values = [
      recordType     || "General",
      title          || "Untitled Record",
      description    || "",
      diagnosis      || "",
      recordValues   || "",
      unit           || "",
      dateRecorded   || dateOfVisit || new Date().toISOString().split("T")[0],
      doctorName     || "",
      clinicHospital || "",
      id,
    ];

    const [result] = await db.execute(sql, values);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Health record not found",
      });
    }

    console.log("✅ Health record updated successfully with ID:", id);

    if (req.app.locals.io) {
      req.app.locals.io.emit("healthRecordUpdated", { record_id: id });
    }

    const fetchSql = `
      SELECT
        hr.id,
        hr.id AS record_id,
        hr.user_id,
        hr.patient_id,
        hr.record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.record_values,
        hr.unit,
        hr.date_recorded,
        hr.doctor_name,
        hr.clinic_hospital,
        hr.created_at,
        p.child_fullname AS patient_name
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      WHERE hr.id = ?
    `;

    const [fetchResults] = await db.execute(fetchSql, [id]);
    const row = fetchResults[0] || {};

    res.status(200).json({
      success: true,
      message: "Health record updated successfully",
      data: {
        ...row,
        record_id:    row.id,
        date_of_visit: row.date_recorded,
      },
    });
  } catch (error) {
    console.error("❌ Unexpected error in updateHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};

// Delete health record
exports.deleteHealthRecord = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Record ID is required",
      });
    }

    const sql = "DELETE FROM health_records WHERE id = ?";
    const [result] = await db.execute(sql, [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Health record not found",
      });
    }

    console.log("✅ Health record deleted successfully with ID:", id);

    if (req.app.locals.io) {
      req.app.locals.io.emit("healthRecordDeleted", { record_id: id });
    }

    res.status(200).json({
      success: true,
      message: "Health record deleted successfully",
    });
  } catch (error) {
    console.error("❌ Unexpected error in deleteHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};

// Get health records for a specific patient
exports.getPatientHealthRecords = async (req, res) => {
  try {
    const { patientId } = req.params;

    if (!patientId) {
      return res.status(400).json({
        success: false,
        message: "Patient ID is required",
      });
    }

    const sql = `
      SELECT
        id,
        id          AS record_id,
        user_id,
        patient_id,
        record_type,
        title,
        description,
        diagnosis,
        record_values,
        unit,
        date_recorded,
        doctor_name,
        clinic_hospital,
        created_at,
        updated_at
      FROM health_records
      WHERE patient_id = ?
      ORDER BY created_at DESC
    `;

    const [results] = await db.execute(sql, [patientId]);

    // Add legacy aliases so Flutter clients that read date_of_visit / status still work
    const mapped = (results || []).map(r => ({
      ...r,
      record_id:    r.id,
      date_of_visit: r.date_recorded,
      status:       "Active",
    }));

    res.status(200).json({
      success: true,
      data:    mapped,
      count:   mapped.length,
    });
  } catch (error) {
    console.error("❌ Unexpected error in getPatientHealthRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};

// Get a specific health record by ID
exports.getHealthRecordById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Record ID is required",
      });
    }

    const sql = `
      SELECT
        hr.id,
        hr.id          AS record_id,
        hr.user_id,
        hr.patient_id,
        hr.record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.record_values,
        hr.unit,
        hr.date_recorded,
        hr.doctor_name,
        hr.clinic_hospital,
        hr.attachments,
        hr.created_at,
        hr.updated_at,
        p.child_fullname        AS patient_name,
        p.mother_fullname,
        p.father_fullname,
        p.dob                   AS date_of_birth,
        p.dob_needs_verification,
        p.place_of_birth,
        p.birth_weight,
        p.birth_height,
        p.sex,
        p.address,
        p.record_type           AS patient_record_type,
        p.record_description    AS patient_record_description,
        p.service_type,
        p.health_center,
        p.barangay,
        p.family_number,
        p.family_serial_number,
        p.contact_number,
        p.spouse_name,
        p.living_children_count,
        p.monthly_income,
        p.religion,
        p.city,
        p.province,
        p.age                   AS patient_age,
        p.education,
        p.occupation,
        p.birth_attendant,
        p.facility_type
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      WHERE hr.id = ?
    `;

    const [results] = await db.execute(sql, [id]);

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Health record not found",
      });
    }

    const record = results[0];
    const processedRecord = {
      id:                       record.id || null,
      record_id:                record.id || null,
      user_id:                  record.user_id || null,
      patient_id:               record.patient_id || null,
      record_type:              record.record_type || "General",
      title:                    record.title || "Untitled Record",
      description:              record.description || "No description",
      diagnosis:                record.diagnosis || "No diagnosis",
      record_values:            record.record_values || "",
      unit:                     record.unit || "",
      date_recorded:            record.date_recorded || new Date().toISOString().split("T")[0],
      doctor_name:              record.doctor_name || "",
      clinic_hospital:          record.clinic_hospital || "",
      attachments:              record.attachments || null,
      created_at:               record.created_at || new Date().toISOString(),
      updated_at:               record.updated_at || new Date().toISOString(),
      // Patient fields
      patient_name:             record.patient_name || "Unknown Patient",
      name:                     record.patient_name || "Unknown Patient",
      mother_fullname:          record.mother_fullname || "Unknown",
      father_fullname:          record.father_fullname || "Unknown",
      date_of_birth:            record.date_of_birth || null,
      dob_needs_verification:   record.dob_needs_verification === 1 || record.dob_needs_verification === true,
      place_of_birth:           record.place_of_birth || "Unknown",
      birth_weight:             record.birth_weight || "Unknown",
      birth_height:             record.birth_height || "Unknown",
      sex:                      record.sex || "Unknown",
      gender:                   record.sex || "Unknown",
      address:                  record.address || "Unknown",
      patient_record_type:      record.patient_record_type || "General",
      patient_record_description: record.patient_record_description || "No description",
      service_type:             record.service_type || "immunization",
      health_center:            record.health_center || "",
      barangay:                 record.barangay || "",
      family_number:            record.family_number || "",
      family_serial_number:     record.family_serial_number || "",
      contact_number:           record.contact_number || "",
      spouse_name:              record.spouse_name || "",
      living_children_count:    record.living_children_count || 0,
      monthly_income:           record.monthly_income || 0,
      religion:                 record.religion || "",
      city:                     record.city || "",
      province:                 record.province || "",
      patient_age:              record.patient_age || 0,
      education:                record.education || "",
      occupation:               record.occupation || "",
      birth_attendant:          record.birth_attendant || "",
      facility_type:            record.facility_type || "",
      // Legacy aliases
      status:                   "Active",
      age:                      record.patient_age || 0,
      date_of_visit:            record.date_recorded || new Date().toISOString().split("T")[0],
    };

    res.status(200).json({
      success: true,
      data: processedRecord,
    });
  } catch (error) {
    console.error("❌ Unexpected error in getHealthRecordById:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error:   error.message,
    });
  }
};
