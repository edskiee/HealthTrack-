const db = require("../config/db");

// Get all health records with complete patient information
exports.getHealthRecords = async (req, res) => {
  try {
    const sql = `
      SELECT 
        hr.id,
        hr.record_id,
        hr.patient_id,
        hr.name,
        hr.age,
        hr.gender,
        hr.status,
        hr.diagnosis,
        hr.date_of_visit,
        hr.record_type,
        hr.title,
        hr.description,
        hr.created_at,
        p.child_fullname as patient_name,
        p.mother_fullname,
        p.father_fullname,
        p.dob as date_of_birth,
        p.place_of_birth,
        p.birth_weight,
        p.birth_height,
        p.sex,
        p.address,
        p.record_type as patient_record_type,
        p.record_description as patient_record_description,
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
        p.age as patient_age,
        p.education,
        p.occupation,
        p.birth_attendant,
        p.facility_type
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      ORDER BY hr.created_at DESC
    `;

    const [results] = await db.execute(sql);

    // Process results to ensure no NULL values and clean data
    const processedResults = (results || []).map(record => ({
      id: record.id || null,
      record_id: record.record_id || `REC-${record.id || Date.now()}`,
      patient_id: record.patient_id || null,
      name: record.name || record.patient_name || 'Unknown Patient',
      age: record.age || 0,
      gender: record.gender || record.sex || 'Unknown',
      status: record.status || 'Active',
      diagnosis: record.diagnosis || 'No diagnosis',
      date_of_visit: record.date_of_visit || new Date().toISOString().split('T')[0],
      record_type: record.record_type || 'General',
      title: record.title || 'Untitled Record',
      description: record.description || 'No description',
      created_at: record.created_at || new Date().toISOString(),
      patient_name: record.patient_name || 'Unknown Patient',
      mother_fullname: record.mother_fullname || 'Unknown',
      father_fullname: record.father_fullname || 'Unknown',
      date_of_birth: record.date_of_birth || null,
      place_of_birth: record.place_of_birth || 'Unknown',
      birth_weight: record.birth_weight || 'Unknown',
      birth_height: record.birth_height || 'Unknown',
      sex: record.sex || record.gender || 'Unknown',
      address: record.address || 'Unknown',
      patient_record_type: record.patient_record_type || 'General',
      patient_record_description: record.patient_record_description || 'No description',
      service_type: record.service_type || 'immunization',
      health_center: record.health_center || '',
      barangay: record.barangay || '',
      family_number: record.family_number || '',
      family_serial_number: record.family_serial_number || '',
      contact_number: record.contact_number || '',
      spouse_name: record.spouse_name || '',
      living_children_count: record.living_children_count || 0,
      monthly_income: record.monthly_income || 0,
      religion: record.religion || '',
      city: record.city || '',
      province: record.province || '',
      patient_age: record.patient_age || 0,
      education: record.education || '',
      occupation: record.occupation || '',
      birth_attendant: record.birth_attendant || '',
      facility_type: record.facility_type || ''
    }));

    res.status(200).json({
      success: true,
      data: processedResults,
      count: processedResults.length
    });
  } catch (error) {
    console.error("❌ Unexpected error in getHealthRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Get all patients with their health records (including patients with no records)
exports.getAllPatientsWithRecords = async (req, res) => {
  try {
    const sql = `
      SELECT 
        p.id as patient_id,
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
        p.age as patient_age,
        p.education,
        p.occupation,
        p.birth_attendant,
        p.facility_type,
        hr.id as record_id,
        hr.record_type as health_record_type,
        hr.title,
        hr.description,
        hr.diagnosis,
        hr.date_of_visit,
        hr.created_at as record_created_at
      FROM patients p
      LEFT JOIN health_records hr ON p.id = hr.patient_id
      ORDER BY p.created_at DESC, hr.created_at DESC
    `;

    const [results] = await db.execute(sql);

    // Group patients with their records
    const patientMap = new Map();
    
    (results || []).forEach(row => {
      const patientId = row.patient_id;
      
      if (!patientMap.has(patientId)) {
        patientMap.set(patientId, {
          patient_id: patientId,
          child_fullname: row.child_fullname || 'Unknown',
          mother_fullname: row.mother_fullname || 'Unknown',
          father_fullname: row.father_fullname || 'Unknown',
          dob: row.dob || null,
          place_of_birth: row.place_of_birth || 'Unknown',
          birth_weight: row.birth_weight || 'Unknown',
          birth_height: row.birth_height || 'Unknown',
          sex: row.sex || 'Unknown',
          address: row.address || 'Unknown',
          record_type: row.record_type || 'General',
          record_description: row.record_description || 'No description',
          status: row.status || 'Active',
          created_at: row.created_at || new Date().toISOString(),
          service_type: row.service_type || 'immunization',
          health_center: row.health_center || '',
          barangay: row.barangay || '',
          family_number: row.family_number || '',
          family_serial_number: row.family_serial_number || '',
          contact_number: row.contact_number || '',
          spouse_name: row.spouse_name || '',
          living_children_count: row.living_children_count || 0,
          monthly_income: row.monthly_income || 0,
          religion: row.religion || '',
          city: row.city || '',
          province: row.province || '',
          patient_age: row.patient_age || 0,
          education: row.education || '',
          occupation: row.occupation || '',
          birth_attendant: row.birth_attendant || '',
          facility_type: row.facility_type || '',
          health_records: []
        });
      }
      
      // Add health record if it exists
      if (row.record_id) {
        const patient = patientMap.get(patientId);
        patient.health_records.push({
          record_id: row.record_id,
          record_type: row.health_record_type || 'General',
          title: row.title || 'Untitled Record',
          description: row.description || 'No description',
          diagnosis: row.diagnosis || 'No diagnosis',
          date_of_visit: row.date_of_visit || new Date().toISOString().split('T')[0],
          created_at: row.record_created_at || new Date().toISOString()
        });
      }
    });

    const patientsWithRecords = Array.from(patientMap.values());
    
    res.status(200).json({
      success: true,
      data: patientsWithRecords,
      count: patientsWithRecords.length
    });
  } catch (error) {
    console.error("❌ Unexpected error in getAllPatientsWithRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
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
      dateOfVisit,
      name,
      age,
      gender,
      status
    } = req.body;

    // Validate required fields
    if (!patientId || !userId) {
      return res.status(400).json({
        success: false,
        message: "Patient ID and User ID are required"
      });
    }

    const sql = `
      INSERT INTO health_records (
        patient_id, user_id, record_type, title, description, 
        diagnosis, date_of_visit, name, age, gender, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      patientId,
      userId,
      recordType || 'General',
      title || 'Untitled Record',
      description || '',
      diagnosis || '',
      dateOfVisit || new Date().toISOString().split('T')[0],
      name || '',
      age || 0,
      gender || '',
      status || 'Active'
    ];

    const [result] = await db.execute(sql, values);
    const recordId = result.insertId;
    console.log("✅ Health record added successfully with ID:", recordId);

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit('healthRecordAdded', { record_id: recordId, patient_id: patientId });
    }

    // Fetch the created health record data
    const fetchSql = `
      SELECT 
        hr.id,
        hr.record_id,
        hr.patient_id,
        hr.name,
        hr.age,
        hr.gender,
        hr.status,
        hr.diagnosis,
        hr.date_of_visit,
        hr.record_type,
        hr.title,
        hr.description,
        hr.created_at,
        p.child_fullname as patient_name
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      WHERE hr.id = ?
    `;

    const [fetchResults] = await db.execute(fetchSql, [recordId]);

    res.status(201).json({
      success: true,
      message: "Health record added successfully",
      data: fetchResults[0]
    });
  } catch (error) {
    console.error("❌ Unexpected error in addHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
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
      dateOfVisit,
      name,
      age,
      gender,
      status
    } = req.body;

    // Validate required parameter
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Record ID is required"
      });
    }

    const sql = `
      UPDATE health_records SET 
        record_type = ?,
        title = ?,
        description = ?,
        diagnosis = ?,
        date_of_visit = ?,
        name = ?,
        age = ?,
        gender = ?,
        status = ?,
        created_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `;

    const values = [
      recordType || 'General',
      title || 'Untitled Record',
      description || '',
      diagnosis || '',
      dateOfVisit || new Date().toISOString().split('T')[0],
      name || '',
      age || 0,
      gender || '',
      status || 'Active',
      id
    ];

    const [result] = await db.execute(sql, values);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Health record not found"
      });
    }

    console.log("✅ Health record updated successfully with ID:", id);

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit('healthRecordUpdated', { record_id: id });
    }

    // Fetch the updated health record data
    const fetchSql = `
      SELECT 
        hr.id,
        hr.record_id,
        hr.patient_id,
        hr.name,
        hr.age,
        hr.gender,
        hr.status,
        hr.diagnosis,
        hr.date_of_visit,
        hr.record_type,
        hr.title,
        hr.description,
        hr.created_at,
        p.child_fullname as patient_name
      FROM health_records hr
      LEFT JOIN patients p ON hr.patient_id = p.id
      WHERE hr.id = ?
    `;

    const [fetchResults] = await db.execute(fetchSql, [id]);

    res.status(200).json({
      success: true,
      message: "Health record updated successfully",
      data: fetchResults[0]
    });
  } catch (error) {
    console.error("❌ Unexpected error in updateHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Delete health record
exports.deleteHealthRecord = async (req, res) => {
  try {
    const { id } = req.params;

    // Validate required parameter
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Record ID is required"
      });
    }

    const sql = "DELETE FROM health_records WHERE id = ?";

    const [result] = await db.execute(sql, [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Health record not found"
      });
    }

    console.log("✅ Health record deleted successfully with ID:", id);

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit('healthRecordDeleted', { record_id: id });
    }

    res.status(200).json({
      success: true,
      message: "Health record deleted successfully"
    });
  } catch (error) {
    console.error("❌ Unexpected error in deleteHealthRecord:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
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
        message: "Patient ID is required"
      });
    }

    const sql = `
      SELECT 
        id,
        record_id,
        patient_id,
        name,
        age,
        gender,
        status,
        diagnosis,
        date_of_visit,
        record_type,
        title,
        description,
        created_at
      FROM health_records
      WHERE patient_id = ?
      ORDER BY created_at DESC
    `;

    const [results] = await db.execute(sql, [patientId]);

    res.status(200).json({
      success: true,
      data: results || [],
      count: (results || []).length
    });
  } catch (error) {
    console.error("❌ Unexpected error in getPatientHealthRecords:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
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
        message: "Record ID is required"
      });
    }

    const sql = `
      SELECT 
        hr.id,
        hr.record_id,
        hr.patient_id,
        hr.name,
        hr.age,
        hr.gender,
        hr.status,
        hr.diagnosis,
        hr.date_of_visit,
        hr.record_type,
        hr.title,
        hr.description,
        hr.created_at,
        p.child_fullname as patient_name,
        p.mother_fullname,
        p.father_fullname,
        p.dob as date_of_birth,
        p.place_of_birth,
        p.birth_weight,
        p.birth_height,
        p.sex,
        p.address,
        p.record_type as patient_record_type,
        p.record_description as patient_record_description,
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
        p.age as patient_age,
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
        message: "Health record not found"
      });
    }

    // Process result to ensure no NULL values and clean data
    const record = results[0];
    const processedRecord = {
      id: record.id || null,
      record_id: record.record_id || `REC-${record.id || Date.now()}`,
      patient_id: record.patient_id || null,
      name: record.name || record.patient_name || 'Unknown Patient',
      age: record.age || 0,
      gender: record.gender || record.sex || 'Unknown',
      status: record.status || 'Active',
      diagnosis: record.diagnosis || 'No diagnosis',
      date_of_visit: record.date_of_visit || new Date().toISOString().split('T')[0],
      record_type: record.record_type || 'General',
      title: record.title || 'Untitled Record',
      description: record.description || 'No description',
      created_at: record.created_at || new Date().toISOString(),
      patient_name: record.patient_name || 'Unknown Patient',
      mother_fullname: record.mother_fullname || 'Unknown',
      father_fullname: record.father_fullname || 'Unknown',
      date_of_birth: record.date_of_birth || null,
      place_of_birth: record.place_of_birth || 'Unknown',
      birth_weight: record.birth_weight || 'Unknown',
      birth_height: record.birth_height || 'Unknown',
      sex: record.sex || record.gender || 'Unknown',
      address: record.address || 'Unknown',
      patient_record_type: record.patient_record_type || 'General',
      patient_record_description: record.patient_record_description || 'No description',
      service_type: record.service_type || 'immunization',
      health_center: record.health_center || '',
      barangay: record.barangay || '',
      family_number: record.family_number || '',
      family_serial_number: record.family_serial_number || '',
      contact_number: record.contact_number || '',
      spouse_name: record.spouse_name || '',
      living_children_count: record.living_children_count || 0,
      monthly_income: record.monthly_income || 0,
      religion: record.religion || '',
      city: record.city || '',
      province: record.province || '',
      patient_age: record.patient_age || 0,
      education: record.education || '',
      occupation: record.occupation || '',
      birth_attendant: record.birth_attendant || '',
      facility_type: record.facility_type || ''
    };

    res.status(200).json({
      success: true,
      data: processedRecord
    });
  } catch (error) {
    console.error("❌ Unexpected error in getHealthRecordById:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};