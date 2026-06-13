const db = require("../config/db");

// ─── Column existence cache ───────────────────────────────────────────────────
// Optional maternal columns that may or may not exist in older DB schemas.
const OPTIONAL_MATERNAL_COLS = [
  'lmp_date','edd_date','gestational_age_weeks',
  'gravida','para','abortus','stillbirth',
  'blood_pressure','weight','height','bmi',
  'fundal_height','fetal_heart_rate',
];

let _cachedMaternalColumns = null;

/**
 * Returns the subset of OPTIONAL_MATERNAL_COLS that actually exist in the
 * `patients` table.  Uses DESCRIBE (no INFORMATION_SCHEMA permission needed).
 * Result is cached for the lifetime of the process.
 */
async function getMaternalColumns(conn) {
  if (Array.isArray(_cachedMaternalColumns)) return _cachedMaternalColumns;

  try {
    const [rows] = await (conn || db).execute("DESCRIBE patients");
    const allCols = rows.map(r => r.Field);
    _cachedMaternalColumns = OPTIONAL_MATERNAL_COLS.filter(c => allCols.includes(c));
  } catch (err) {
    // DESCRIBE failed (DB unavailable, permission issue, etc.)
    // Return empty — do NOT cache so the next request retries.
    console.error("⚠️ getMaternalColumns: DESCRIBE patients failed:", err.message);
    return [];
  }
  return _cachedMaternalColumns;
}

// ─── Build the patient SELECT column list (list view only – no heavy cols) ─────
function buildListSelectCols(existingMaternalCols) {
  // Only the columns needed for the admin patient list view
  let cols = `
      id,
      user_id,
      child_fullname  AS childName,
      mother_fullname AS motherName,
      father_fullname AS fatherName,
      dob,
      sex,
      address,
      record_type     AS recordType,
      service_type    AS serviceType,
      health_center,
      barangay,
      family_number,
      status,
      created_at`;
  // Keep lightweight maternal columns that the list displays
  if (existingMaternalCols.includes('gravida'))  cols += ',\n      gravida';
  if (existingMaternalCols.includes('para'))     cols += ',\n      para';
  return cols;
}

// ─── Build the patient SELECT column list (full detail – for single record) ────
function buildFullSelectCols(existingMaternalCols) {
  let cols = `
      id,
      user_id,
      child_fullname  AS childName,
      mother_fullname AS motherName,
      father_fullname AS fatherName,
      dob,
      place_of_birth  AS placeOfBirth,
      birth_weight    AS birthWeight,
      birth_height    AS birthHeight,
      sex,
      address,
      record_type     AS recordType,
      service_type    AS serviceType,
      record_description AS recordDescription,
      family_serial_number,
      contact_number,
      spouse_name,
      living_children_count,
      monthly_income,
      religion,
      city,
      province,
      age,
      education,
      occupation,
      birth_attendant,
      facility_type,
      health_center,
      barangay,
      family_number,
      status,
      created_at`;
  for (const col of [
    'lmp_date','edd_date','gestational_age_weeks',
    'gravida','para','abortus','stillbirth',
    'blood_pressure','weight','height','bmi',
    'fundal_height','fetal_heart_rate',
  ]) {
    if (existingMaternalCols.includes(col)) cols += `,\n      ${col}`;
  }
  return cols;
}

// Get patients with pagination, server-side filtering, and search
exports.getPatients = async (req, res) => {
  try {
    // ── Pagination params — use Number() + |0 to guarantee plain JS integers
    // mysql2 prepared statements reject NaN / BigInt as LIMIT/OFFSET values.
    const page   = Math.max(1,   Number(req.query.page  || 1)  | 0);
    const limit  = Math.min(100, Math.max(1, Number(req.query.limit || 20) | 0));
    const offset = (page - 1) * limit;

    // ── Filter / search params ────────────────────────────────────────────────
    const searchQ      = (req.query.q           || '').trim();
    const serviceType  = (req.query.serviceType || '').trim();
    const genderFilter = (req.query.gender      || '').trim();
    const statusFilter = (req.query.status      || '').trim();
    const startDate    = (req.query.startDate   || '').trim();
    const endDate      = (req.query.endDate     || '').trim();
    const ageRange     = (req.query.ageRange    || '').trim();

    const existingCols = await getMaternalColumns();
    const selectCols   = buildListSelectCols(existingCols);

    // ── Build WHERE clauses ───────────────────────────────────────────────────
    const whereClauses = [];
    const params       = [];

    if (searchQ) {
      whereClauses.push('(child_fullname LIKE ? OR mother_fullname LIKE ? OR father_fullname LIKE ?)');
      const term = `%${searchQ}%`;
      params.push(term, term, term);
    }
    if (serviceType && serviceType !== 'All') {
      whereClauses.push('service_type = ?');
      params.push(serviceType);
    }
    if (genderFilter && genderFilter !== 'All') {
      whereClauses.push('sex = ?');
      params.push(genderFilter);
    }
    if (statusFilter && statusFilter !== 'All') {
      whereClauses.push('status = ?');
      params.push(statusFilter);
    }
    if (startDate) {
      whereClauses.push('DATE(created_at) >= ?');
      params.push(startDate);
    }
    if (endDate) {
      whereClauses.push('DATE(created_at) <= ?');
      params.push(endDate);
    }
    if (ageRange && ageRange !== 'All') {
      // Age derived from dob at query time
      if (ageRange === '0-1') {
        whereClauses.push('TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 0 AND 1');
      } else if (ageRange === '1-5') {
        whereClauses.push('TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 1 AND 5');
      } else if (ageRange === '5-10') {
        whereClauses.push('TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 5 AND 10');
      } else if (ageRange === '10+') {
        whereClauses.push('TIMESTAMPDIFF(YEAR, dob, CURDATE()) >= 10');
      }
    }

    const whereSQL = whereClauses.length ? `WHERE ${whereClauses.join(' AND ')}` : '';

    // ── COUNT total matching rows ─────────────────────────────────────────────
    // Use query() instead of execute() for the COUNT — avoids BigInt prepared-stmt issues
    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total FROM patients ${whereSQL}`,
      params
    );
    const total      = Number(countRows[0].total);
    const totalPages = Math.ceil(total / limit);

    // ── Fetch the page ────────────────────────────────────────────────────────
    const dataSQL = `SELECT ${selectCols} FROM patients ${whereSQL} ORDER BY created_at DESC LIMIT ? OFFSET ?`;
    // Use query() to avoid prepared-statement BigInt/type issues
    const [results] = await db.query(dataSQL, [...params, limit | 0, offset | 0]);

    res.status(200).json({
      success:    true,
      data:       results,
      total,
      page,
      totalPages,
    });
  } catch (error) {
    console.error("❌ Database error in getPatients:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch patients",
      error: error.message,
    });
  }
};

// Add new patient
exports.addPatient = async (req, res) => {
  const {
    userId,
    childName,
    motherName,
    fatherName,
    dob,
    lmpDate,
    eddDate,
    gestationalAgeWeeks,
    gravida,
    para,
    abortus,
    stillbirth,
    bloodPressure,
    weight,
    height,
    bmi,
    fundalHeight,
    fetalHeartRate,
    placeOfBirth,
    birthWeight,
    birthHeight,
    sex,
    address,
    recordType,
    serviceType,
    recordDescription,
    // Maternal care fields
    familySerialNumber,
    contactNumber,
    spouseName,
    livingChildrenCount,
    monthlyIncome,
    religion,
    city,
    province,
    age,
    education,
    occupation,
    birthAttendant,
    facilityType,
    // Immunization fields
    healthCenter,
    barangay,
    familyNumber
  } = req.body;

  // Validate required fields
  if (!userId || !childName || !motherName || !dob || !sex) {
    return res.status(400).json({
      success: false,
      message: "User ID, child name, mother name, date of birth, and sex are required",
    });
  }

  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();

    // Use cached column list (invalidates only on server restart)
    const existingColumns = await getMaternalColumns();
    
    // Build INSERT query based on existing columns
    let sql = `INSERT INTO patients (user_id, child_fullname, mother_fullname, father_fullname, dob, place_of_birth, birth_weight, birth_height, sex, address, status, record_type, service_type, record_description, family_serial_number, contact_number, spouse_name, living_children_count, monthly_income, religion, city, province, age, education, occupation, birth_attendant, facility_type, health_center, barangay, family_number`;
    let values = [userId, childName, motherName, fatherName || '', dob, placeOfBirth || '', birthWeight || '', birthHeight || '', sex, address || '', 'active', recordType || 'Diagnosis', serviceType || 'immunization', recordDescription || 'Initial record', familySerialNumber || '', contactNumber || '', spouseName || '', livingChildrenCount || 0, monthlyIncome || 0, religion || '', city || '', province || '', age || 0, education || '', occupation || '', birthAttendant || null, facilityType || '', healthCenter || '', barangay || '', familyNumber || ''];

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) {
      sql += ', lmp_date';
      values.push(lmpDate || null);
    }
    if (existingColumns.includes('edd_date')) {
      sql += ', edd_date';
      values.push(eddDate || null);
    }
    if (existingColumns.includes('gestational_age_weeks')) {
      sql += ', gestational_age_weeks';
      values.push(gestationalAgeWeeks || null);
    }
    if (existingColumns.includes('gravida')) {
      sql += ', gravida';
      values.push(gravida || 1);
    }
    if (existingColumns.includes('para')) {
      sql += ', para';
      values.push(para || 0);
    }
    if (existingColumns.includes('abortus')) {
      sql += ', abortus';
      values.push(abortus || 0);
    }
    if (existingColumns.includes('stillbirth')) {
      sql += ', stillbirth';
      values.push(stillbirth || 0);
    }
    if (existingColumns.includes('blood_pressure')) {
      sql += ', blood_pressure';
      values.push(bloodPressure || '');
    }
    if (existingColumns.includes('weight')) {
      sql += ', weight';
      values.push(weight || null);
    }
    if (existingColumns.includes('height')) {
      sql += ', height';
      values.push(height || null);
    }
    if (existingColumns.includes('bmi')) {
      sql += ', bmi';
      values.push(bmi || null);
    }
    if (existingColumns.includes('fundal_height')) {
      sql += ', fundal_height';
      values.push(fundalHeight || null);
    }
    if (existingColumns.includes('fetal_heart_rate')) {
      sql += ', fetal_heart_rate';
      values.push(fetalHeartRate || null);
    }

    sql += `) VALUES (${values.map(() => '?').join(', ')})`;

    const [result] = await connection.execute(sql, values);
    const patientId = result.insertId;

    // Automatically create initial health record for every new patient
    const healthRecordSql = `
      INSERT INTO health_records (
        user_id, patient_id, record_type, title, description, date_recorded
      ) VALUES (?, ?, 'Immunization', 'Initial Patient Record', 'Automatically created during patient registration', CURDATE())
    `;

    await connection.execute(healthRecordSql, [userId, patientId]);
    console.log("✅ Health record created successfully for patient ID:", patientId);

    // Fetch the created patient data using shared helper
    const fetchCols = buildFullSelectCols(existingColumns);
    const fetchSql = `SELECT ${fetchCols} FROM patients WHERE id = ?`;

    const [fetchResults] = await connection.execute(fetchSql, [patientId]);

    // Commit the transaction
    await connection.commit();

    // Trigger dashboard refresh for real-time updates
    // This will notify all connected admin dashboards to refresh their data
    if (req.app.locals.io) {
      req.app.locals.io.emit('patientAdded', fetchResults[0]);
      
      // Also emit to specific admin rooms if needed
      req.app.locals.io.to('admins').emit('newPatient', {
        patient: fetchResults[0],
        timestamp: new Date().toISOString()
      });
    }

    res.status(201).json({
      success: true,
      message: "Patient added successfully with health record",
      data: fetchResults[0],
    });
  } catch (error) {
    await connection.rollback();
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to add patient",
      error: error.message
    });
  } finally {
    connection.release();
  }
};

// Update patient
exports.updatePatient = async (req, res) => {
  const { id } = req.params;
  const {
    userId,
    childName,
    motherName,
    fatherName,
    dob,
    lmpDate,
    eddDate,
    gestationalAgeWeeks,
    gravida,
    para,
    abortus,
    stillbirth,
    bloodPressure,
    weight,
    height,
    bmi,
    fundalHeight,
    fetalHeartRate,
    placeOfBirth,
    birthWeight,
    birthHeight,
    sex,
    address,
    recordType,
    serviceType,
    recordDescription,
    // Maternal care fields
    familySerialNumber,
    contactNumber,
    spouseName,
    livingChildrenCount,
    monthlyIncome,
    religion,
    city,
    province,
    age,
    education,
    occupation,
    birthAttendant,
    facilityType,
    // Immunization fields
    healthCenter,
    barangay,
    familyNumber
  } = req.body;

  // Validate required fields
  if (!userId || !childName || !motherName || !dob || !sex) {
    return res.status(400).json({
      success: false,
      message: "User ID, child name, mother name, date of birth, and sex are required",
    });
  }

  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();

    // Use cached column list
    const existingColumns = await getMaternalColumns();
    
    // Build UPDATE query based on existing columns
    let sql = `UPDATE patients SET user_id = ?, child_fullname = ?, mother_fullname = ?, father_fullname = ?, dob = ?, place_of_birth = ?, birth_weight = ?, birth_height = ?, sex = ?, address = ?, record_type = ?, service_type = ?, record_description = ?, family_serial_number = ?, contact_number = ?, spouse_name = ?, living_children_count = ?, monthly_income = ?, religion = ?, city = ?, province = ?, age = ?, education = ?, occupation = ?, birth_attendant = ?, facility_type = ?, health_center = ?, barangay = ?, family_number = ?, updated_at = CURRENT_TIMESTAMP`;
    let values = [userId, childName, motherName, fatherName || '', dob, placeOfBirth || '', birthWeight || '', birthHeight || '', sex, address || '', recordType || 'Diagnosis', serviceType || 'immunization', recordDescription || '', familySerialNumber || '', contactNumber || '', spouseName || '', livingChildrenCount || 0, monthlyIncome || 0, religion || '', city || '', province || '', age || 0, education || '', occupation || '', birthAttendant || null, facilityType || '', healthCenter || '', barangay || '', familyNumber || ''];

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) {
      sql += ', lmp_date = ?';
      values.push(lmpDate || null);
    }
    if (existingColumns.includes('edd_date')) {
      sql += ', edd_date = ?';
      values.push(eddDate || null);
    }
    if (existingColumns.includes('gestational_age_weeks')) {
      sql += ', gestational_age_weeks = ?';
      values.push(gestationalAgeWeeks || null);
    }
    if (existingColumns.includes('gravida')) {
      sql += ', gravida = ?';
      values.push(gravida || 1);
    }
    if (existingColumns.includes('para')) {
      sql += ', para = ?';
      values.push(para || 0);
    }
    if (existingColumns.includes('abortus')) {
      sql += ', abortus = ?';
      values.push(abortus || 0);
    }
    if (existingColumns.includes('stillbirth')) {
      sql += ', stillbirth = ?';
      values.push(stillbirth || 0);
    }
    if (existingColumns.includes('blood_pressure')) {
      sql += ', blood_pressure = ?';
      values.push(bloodPressure || '');
    }
    if (existingColumns.includes('weight')) {
      sql += ', weight = ?';
      values.push(weight || null);
    }
    if (existingColumns.includes('height')) {
      sql += ', height = ?';
      values.push(height || null);
    }
    if (existingColumns.includes('bmi')) {
      sql += ', bmi = ?';
      values.push(bmi || null);
    }
    if (existingColumns.includes('fundal_height')) {
      sql += ', fundal_height = ?';
      values.push(fundalHeight || null);
    }
    if (existingColumns.includes('fetal_heart_rate')) {
      sql += ', fetal_heart_rate = ?';
      values.push(fetalHeartRate || null);
    }

    sql += ' WHERE id = ?';
    values.push(id);

    const [result] = await connection.execute(sql, values);

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: "Patient not found",
      });
    }

    // Update or create health record for this patient
    const checkHealthRecordSql = `
      SELECT id FROM health_records WHERE patient_id = ? LIMIT 1
    `;

    const [checkResults] = await connection.execute(checkHealthRecordSql, [id]);

    if (checkResults && checkResults.length > 0) {
      // Update existing health record
      const updateHealthRecordSql = `
        UPDATE health_records SET
          record_type = ?,
          title = ?,
          description = ?,
          date_recorded = CURDATE()
        WHERE patient_id = ? AND id = ?
      `;

      const updateHealthRecordValues = [
        recordType || 'Diagnosis',
        'Updated Health Record',
        recordDescription || 'Health record updated with patient information',
        id,
        checkResults[0].id
      ];

      try {
        await connection.execute(updateHealthRecordSql, updateHealthRecordValues);
      } catch (updateErr) {
        console.error("❌ Database error updating health record:", updateErr);
        // Continue even if health record update fails
      }
    } else {
      // Create new health record if none exists
      const createHealthRecordSql = `
        INSERT INTO health_records (
          user_id, patient_id, record_type, title, description, date_recorded
        ) VALUES (?, ?, ?, ?, ?, CURDATE())
      `;

      const createHealthRecordValues = [
        userId,
        id,
        recordType || 'Diagnosis',
        'Health Record',
        recordDescription || 'Health record created with patient information'
      ];

      try {
        await connection.execute(createHealthRecordSql, createHealthRecordValues);
      } catch (createErr) {
        console.error("❌ Database error creating health record:", createErr);
        // Continue even if health record creation fails
      }
    }

    // Commit the transaction
    await connection.commit();
    
    // Emit socket event for real-time updates
    if (req.app.locals.io) {
      req.app.locals.io.emit('patientUpdated', {
        id: id,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to specific admin rooms if needed
      req.app.locals.io.to('admins').emit('patientUpdated', {
        id: id,
        timestamp: new Date().toISOString()
      });
    }

    res.status(200).json({
      success: true,
      message: "Patient updated successfully with synchronized health record",
    });
  } catch (error) {
    await connection.rollback();
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to update patient",
      error: error.message
    });
  } finally {
    connection.release();
  }
};

// Delete patient (hard delete for immediate UI update)
exports.deletePatient = async (req, res) => {
  const { id } = req.params;

  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();

    // First, delete any related appointments
    const deleteAppointments = "DELETE FROM appointments WHERE patient_id = ?";
    await connection.execute(deleteAppointments, [id]);

    // Then delete health records
    const deleteHealthRecords = "DELETE FROM health_records WHERE patient_id = ?";
    try {
      await connection.execute(deleteHealthRecords, [id]);
    } catch (err) {
      console.error("❌ Database error deleting health records:", err);
      // Continue with patient deletion even if this fails
    }

    // Then delete the patient
    const deletePatient = "DELETE FROM patients WHERE id = ?";
    const [result] = await connection.execute(deletePatient, [id]);

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: "Patient not found",
      });
    }

    // Commit the transaction
    await connection.commit();
    
    // Emit socket event for real-time updates
    if (req.app.locals.io) {
      req.app.locals.io.emit('patientDeleted', {
        id: id,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to specific admin rooms if needed
      req.app.locals.io.to('admins').emit('patientDeleted', {
        id: id,
        timestamp: new Date().toISOString()
      });
    }

    res.status(200).json({
      success: true,
      message: "Patient deleted successfully",
    });
  } catch (error) {
    await connection.rollback();
    console.error("❌ Database error deleting patient:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to delete patient",
      error: error.message
    });
  } finally {
    connection.release();
  }
};

// Search patients — delegates to getPatients with q param
// (kept for backward compat with older clients)
exports.searchPatients = async (req, res) => {
  if (!req.query.q) {
    return res.status(400).json({
      success: false,
      message: "Search query is required",
    });
  }
  // Reuse the paginated getPatients handler
  return exports.getPatients(req, res);
};

// Get patient data for specific user
exports.getUserPatient = async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({
      success: false,
      message: "User ID is required",
    });
  }

  try {
    const existingColumns = await getMaternalColumns();
    const selectCols = buildFullSelectCols(existingColumns);

    const sql = `SELECT ${selectCols} FROM patients WHERE user_id = ? LIMIT 1`;
    const [results] = await db.execute(sql, [userId]);

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No patient record found for this user",
      });
    }

    const patient = results[0];
    console.log(`✅ Found patient data for user ${userId}: ${patient.childName}`);

    res.status(200).json({
      success: true,
      message: "Patient data fetched successfully",
      data: patient,
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch patient data",
      error: error.message,
    });
  }
};