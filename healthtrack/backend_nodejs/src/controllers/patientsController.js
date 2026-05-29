const db = require("../config/db");

// Get all patients with error handling for missing columns
exports.getPatients = async (req, res) => {
  try {
    // First, check if the new columns exist
    const checkColumnsSql = `
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'patients' 
      AND COLUMN_NAME IN ('lmp_date', 'edd_date', 'gestational_age_weeks', 'gravida', 'para', 'abortus', 'stillbirth', 'blood_pressure', 'weight', 'height', 'bmi', 'fundal_height', 'fetal_heart_rate')
    `;

    const [columnResults] = await db.execute(checkColumnsSql);

    // Get list of existing columns
    const existingColumns = columnResults.map(row => row.COLUMN_NAME);
    
    // Build SQL query based on existing columns
    let sql = `
      SELECT 
        id,
        user_id,
        child_fullname as childName,
        mother_fullname as motherName,
        father_fullname as fatherName,
        dob,
        place_of_birth as placeOfBirth,
        birth_weight as birthWeight,
        birth_height as birthHeight,
        sex,
        address,
        record_type as recordType,
        service_type as serviceType,
        record_description as recordDescription,
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
        created_at
    `;

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) sql += ',\n      lmp_date';
    if (existingColumns.includes('edd_date')) sql += ',\n      edd_date';
    if (existingColumns.includes('gestational_age_weeks')) sql += ',\n      gestational_age_weeks';
    if (existingColumns.includes('gravida')) sql += ',\n      gravida';
    if (existingColumns.includes('para')) sql += ',\n      para';
    if (existingColumns.includes('abortus')) sql += ',\n      abortus';
    if (existingColumns.includes('stillbirth')) sql += ',\n      stillbirth';
    if (existingColumns.includes('blood_pressure')) sql += ',\n      blood_pressure';
    if (existingColumns.includes('weight')) sql += ',\n      weight';
    if (existingColumns.includes('height')) sql += ',\n      height';
    if (existingColumns.includes('bmi')) sql += ',\n      bmi';
    if (existingColumns.includes('fundal_height')) sql += ',\n      fundal_height';
    if (existingColumns.includes('fetal_heart_rate')) sql += ',\n      fetal_heart_rate';

    sql += `
      FROM patients 
      ORDER BY created_at DESC
    `;

    const [results] = await db.execute(sql);

    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch patients",
      error: error.message
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

    // First, check if the new columns exist
    const checkColumnsSql = `
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'patients' 
      AND COLUMN_NAME IN ('lmp_date', 'edd_date', 'gestational_age_weeks', 'gravida', 'para', 'abortus', 'stillbirth', 'blood_pressure', 'weight', 'height', 'bmi', 'fundal_height', 'fetal_heart_rate')
    `;

    const [columnResults] = await connection.execute(checkColumnsSql);

    // Get list of existing columns
    const existingColumns = columnResults.map(row => row.COLUMN_NAME);
    
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

    // Create initial health record for the patient
    const healthRecordSql = `
      INSERT INTO health_records (
        user_id, patient_id, record_type, title, description, date_recorded
      ) VALUES (?, ?, ?, ?, ?, CURDATE())
    `;

    const healthRecordValues = [
      userId, // galing sa req.body.userId
      patientId,
      recordType || 'Diagnosis',
      'Initial Health Record',
      recordDescription || 'Initial health record created upon patient registration'
    ];

    // Always create health record when createHealthRecord flag is true or not specified
    const shouldCreateHealthRecord = req.body.createHealthRecord !== false;

    if (shouldCreateHealthRecord) {
      try {
        await connection.execute(healthRecordSql, healthRecordValues);
        console.log("✅ Health record created successfully for patient ID:", patientId);
      } catch (healthErr) {
        console.error("❌ Database error creating health record:", healthErr);
        // Continue even if health record creation fails
      }
    } else {
      console.log("⚠️ Health record creation skipped based on request flag for patient ID:", patientId);
    }

    // Fetch the created patient data
    let fetchSql = `
      SELECT 
        id,
        user_id,
        child_fullname as childName,
        mother_fullname as motherName,
        father_fullname as fatherName,
        dob,
        place_of_birth as placeOfBirth,
        birth_weight as birthWeight,
        birth_height as birthHeight,
        sex,
        address,
        status,
        record_type as recordType,
        service_type as serviceType,
        record_description as recordDescription,
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
        created_at,
        updated_at
    `;

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) fetchSql += ',\n      lmp_date';
    if (existingColumns.includes('edd_date')) fetchSql += ',\n      edd_date';
    if (existingColumns.includes('gestational_age_weeks')) fetchSql += ',\n      gestational_age_weeks';
    if (existingColumns.includes('gravida')) fetchSql += ',\n      gravida';
    if (existingColumns.includes('para')) fetchSql += ',\n      para';
    if (existingColumns.includes('abortus')) fetchSql += ',\n      abortus';
    if (existingColumns.includes('stillbirth')) fetchSql += ',\n      stillbirth';
    if (existingColumns.includes('blood_pressure')) fetchSql += ',\n      blood_pressure';
    if (existingColumns.includes('weight')) fetchSql += ',\n      weight';
    if (existingColumns.includes('height')) fetchSql += ',\n      height';
    if (existingColumns.includes('bmi')) fetchSql += ',\n      bmi';
    if (existingColumns.includes('fundal_height')) fetchSql += ',\n      fundal_height';
    if (existingColumns.includes('fetal_heart_rate')) fetchSql += ',\n      fetal_heart_rate';

    fetchSql += `
      FROM patients 
      WHERE id = ?
    `;

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

    // First, check if the new columns exist
    const checkColumnsSql = `
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'patients' 
      AND COLUMN_NAME IN ('lmp_date', 'edd_date', 'gestational_age_weeks', 'gravida', 'para', 'abortus', 'stillbirth', 'blood_pressure', 'weight', 'height', 'bmi', 'fundal_height', 'fetal_heart_rate')
    `;

    const [columnResults] = await connection.execute(checkColumnsSql);

    // Get list of existing columns
    const existingColumns = columnResults.map(row => row.COLUMN_NAME);
    
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

// Search patients
exports.searchPatients = async (req, res) => {
  const { q } = req.query;

  if (!q) {
    return res.status(400).json({
      success: false,
      message: "Search query is required",
    });
  }

  try {
    // First, check if the new columns exist
    const checkColumnsSql = `
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'patients' 
      AND COLUMN_NAME IN ('lmp_date', 'edd_date', 'gestational_age_weeks', 'gravida', 'para', 'abortus', 'stillbirth', 'blood_pressure', 'weight', 'height', 'bmi', 'fundal_height', 'fetal_heart_rate')
    `;

    const [columnResults] = await db.execute(checkColumnsSql);

    // Get list of existing columns
    const existingColumns = columnResults.map(row => row.COLUMN_NAME);
    
    let sql = `
      SELECT 
        id,
        user_id,
        child_fullname as childName,
        mother_fullname as motherName,
        father_fullname as fatherName,
        dob,
        place_of_birth as placeOfBirth,
        birth_weight as birthWeight,
        birth_height as birthHeight,
        sex,
        address,
        record_type as recordType,
        service_type as serviceType,
        status,
        created_at
    `;

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) sql += ',\n      lmp_date';
    if (existingColumns.includes('edd_date')) sql += ',\n      edd_date';
    if (existingColumns.includes('gestational_age_weeks')) sql += ',\n      gestational_age_weeks';
    if (existingColumns.includes('gravida')) sql += ',\n      gravida';
    if (existingColumns.includes('para')) sql += ',\n      para';
    if (existingColumns.includes('abortus')) sql += ',\n      abortus';
    if (existingColumns.includes('stillbirth')) sql += ',\n      stillbirth';
    if (existingColumns.includes('blood_pressure')) sql += ',\n      blood_pressure';
    if (existingColumns.includes('weight')) sql += ',\n      weight';
    if (existingColumns.includes('height')) sql += ',\n      height';
    if (existingColumns.includes('bmi')) sql += ',\n      bmi';
    if (existingColumns.includes('fundal_height')) sql += ',\n      fundal_height';
    if (existingColumns.includes('fetal_heart_rate')) sql += ',\n      fetal_heart_rate';

    const searchTerm = `%${q}%`;

    sql += `
      FROM patients 
      WHERE (
          child_fullname LIKE ? OR 
          mother_fullname LIKE ? OR 
          father_fullname LIKE ?
        )
      ORDER BY created_at DESC
    `;

    const [results] = await db.execute(sql, [searchTerm, searchTerm, searchTerm]);

    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to search patients",
      error: error.message
    });
  }
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
    // First, check if the new columns exist
    const checkColumnsSql = `
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'patients' 
      AND COLUMN_NAME IN ('lmp_date', 'edd_date', 'gestational_age_weeks', 'gravida', 'para', 'abortus', 'stillbirth', 'blood_pressure', 'weight', 'height', 'bmi', 'fundal_height', 'fetal_heart_rate')
    `;

    const [columnResults] = await db.execute(checkColumnsSql);

    // Get list of existing columns
    const existingColumns = columnResults.map(row => row.COLUMN_NAME);
    
    let sql = `
      SELECT 
        id,
        user_id,
        child_fullname,
        mother_fullname,
        father_fullname,
        dob,
        place_of_birth,
        birth_weight,
        birth_height,
        sex,
        address,
        record_type as recordType,
        service_type as serviceType,
        status,
        created_at,
        updated_at
    `;

    // Add maternal care columns only if they exist
    if (existingColumns.includes('lmp_date')) sql += ',\n      lmp_date';
    if (existingColumns.includes('edd_date')) sql += ',\n      edd_date';
    if (existingColumns.includes('gestational_age_weeks')) sql += ',\n      gestational_age_weeks';
    if (existingColumns.includes('gravida')) sql += ',\n      gravida';
    if (existingColumns.includes('para')) sql += ',\n      para';
    if (existingColumns.includes('abortus')) sql += ',\n      abortus';
    if (existingColumns.includes('stillbirth')) sql += ',\n      stillbirth';
    if (existingColumns.includes('blood_pressure')) sql += ',\n      blood_pressure';
    if (existingColumns.includes('weight')) sql += ',\n      weight';
    if (existingColumns.includes('height')) sql += ',\n      height';
    if (existingColumns.includes('bmi')) sql += ',\n      bmi';
    if (existingColumns.includes('fundal_height')) sql += ',\n      fundal_height';
    if (existingColumns.includes('fetal_heart_rate')) sql += ',\n      fetal_heart_rate';

    sql += `
      FROM patients 
      WHERE user_id = ?
      LIMIT 1
    `;

    const [results] = await db.execute(sql, [userId]);

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No patient record found for this user",
      });
    }

    const patient = results[0];
    console.log(`✅ Found patient data for user ${userId}: ${patient.child_fullname}`);

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
      error: error.message
    });
  }
};