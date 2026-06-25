const db = require("../config/db");
// Removed HealthWorkerService reference since it's no longer used

// Helper function to convert full day names to abbreviations
function _getDayAbbreviation(fullDayName) {
  const dayMap = {
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
    'Saturday': 'Sat',
    'Sunday': 'Sun'
  };
  return dayMap[fullDayName] || fullDayName.substring(0, 3);
}

// Helper function to emit dashboard updates to all connected clients
function emitDashboardUpdate(io, updateType, data = null) {
  if (io) {
    io.emit('dashboard_update', {
      type: updateType,
      timestamp: new Date().toISOString(),
      data: data
    });
    console.log(`📤 Emitted dashboard update: ${updateType}`);
  }
}

// Get dashboard statistics
exports.getDashboardStats = async (req, res) => {
  try {
    const statsQuery = `
      SELECT 
        (SELECT COUNT(*) FROM patients) as totalPatients,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE()) as appointmentsToday,
        (SELECT COUNT(*) FROM appointments WHERE status = 'scheduled') as pendingApprovals,
        (SELECT COUNT(*) FROM health_records) as todayRecords,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'maternal') as maternalPatients,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'immunization') as immunizationPatients,
        (SELECT COUNT(*) FROM patients WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newPatientsLast30Days,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE() AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newAppointmentsLast30Days,
        (SELECT COUNT(*) FROM health_records WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newRecordsLast30Days
    `;
    
    // Query to get last month's data for comparison
    const lastMonthQuery = `
      SELECT 
        (SELECT COUNT(*) FROM patients WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthPatients,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE() AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthAppointments,
        (SELECT COUNT(*) FROM health_records WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthRecords,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'maternal' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthMaternalPatients,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'immunization' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthImmunizationPatients
    `;    
    const [statsResults] = await db.execute(statsQuery);
    const [lastMonthResults] = await db.execute(lastMonthQuery);

    const currentStats = (statsResults && statsResults[0]) || {};
    const lastMonthStats = (lastMonthResults && lastMonthResults[0]) || {};
    
    // Calculate percentage changes
    const calculateChange = (current, previous) => {
      if (previous === 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100;
    };
    
    const responseData = {
      success: true,
      data: {
        totalPatients: currentStats.totalPatients || 0,
        appointmentsToday: currentStats.appointmentsToday || 0,
        pendingApprovals: currentStats.pendingApprovals || 0,
        todayRecords: currentStats.todayRecords || 0,
        maternalPatients: currentStats.maternalPatients || 0,
        immunizationPatients: currentStats.immunizationPatients || 0,
        // Change indicators
        totalPatientsChange: calculateChange(currentStats.totalPatients || 0, lastMonthStats.lastMonthPatients || 0),
        maternalPatientsChange: calculateChange(currentStats.maternalPatients || 0, lastMonthStats.lastMonthMaternalPatients || 0),
        immunizationPatientsChange: calculateChange(currentStats.immunizationPatients || 0, lastMonthStats.lastMonthImmunizationPatients || 0),
        appointmentsTodayChange: calculateChange(currentStats.appointmentsToday || 0, lastMonthStats.lastMonthAppointments || 0),
        todayRecordsChange: calculateChange(currentStats.todayRecords || 0, lastMonthStats.lastMonthRecords || 0),
        pendingApprovalsChange: calculateChange(currentStats.pendingApprovals || 0, 0) // Assuming no previous data for pending approvals
      },
    };
    
    res.status(200).json(responseData);
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch dashboard statistics",
      error: error.message
    });
  }
};

// Get recent activities
exports.getRecentActivities = async (req, res) => {
  try {
    const activitiesQuery = `
      SELECT 
        'patient_add' as type,
        CONCAT('New patient ', child_fullname, ' registered') as description,
        created_at as time,
        child_fullname as patient_name
      FROM patients 
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ORDER BY created_at DESC
      LIMIT 10
    `;
    
    const [results] = await db.execute(activitiesQuery);

    // Always return an array, even if empty
    const activities = (results || []).map(activity => ({
      type: activity.type,
      description: activity.description,
      time: activity.time,
      patient_name: activity.patient_name
    }));

    res.status(200).json({
      success: true,
      data: activities,
      count: activities.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch recent activities",
      error: error.message
    });
  }
};

// Get today's appointments
exports.getTodayAppointments = async (req, res) => {
  try {
    const appointmentsQuery = `
      SELECT 
        a.id,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.status,
        COALESCE(p.child_fullname, 'Unknown Patient') as patient_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE DATE(a.appointment_date) = CURDATE()
      ORDER BY a.appointment_time ASC
    `;
    
    const [results] = await db.execute(appointmentsQuery);

    // Always return an array, even if empty
    const appointments = (results || []).map(apt => ({
      id: apt.id,
      patientName: apt.patient_name,
      type: apt.appointment_type,
      time: apt.appointment_time,
      doctor: apt.doctor_name,
      status: apt.status
    }));

    res.status(200).json({
      success: true,
      data: appointments,
      count: appointments.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch today's appointments",
      error: error.message
    });
  }
};

// Get weekly appointments data
exports.getWeeklyAppointments = async (req, res) => {
  try {
    const weeklyAppointmentsQuery = `
      SELECT 
        DAYNAME(a.appointment_date) as day_of_week,
        COUNT(*) as appointment_count
      FROM appointments a
      WHERE a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      AND a.appointment_date <= CURDATE()
      GROUP BY DAYNAME(a.appointment_date)
    `;
    
    const [results] = await db.execute(weeklyAppointmentsQuery);

    // Create a map with all days of the week
    const weeklyData = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0
    };

    // Fill in the actual data
    if (results && results.length > 0) {
      results.forEach(row => {
        const dayAbbrev = _getDayAbbreviation(row.day_of_week);
        weeklyData[dayAbbrev] = row.appointment_count;
      });
    }

    res.status(200).json({
      success: true,
      data: weeklyData,
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch weekly appointments",
      error: error.message
    });
  }
};

// Get most common baby conditions
exports.getBabyConditions = async (req, res) => {
  try {
    const conditionsQuery = `
      SELECT 
        diagnosis as condition_name,
        COUNT(*) as patient_count
      FROM health_records
      WHERE diagnosis IS NOT NULL 
      AND diagnosis != ''
      GROUP BY diagnosis
      ORDER BY patient_count DESC
      LIMIT 10
    `;
    
    const [results] = await db.execute(conditionsQuery);

    // Calculate total patients with conditions for percentage calculation
    const totalCountQuery = `
      SELECT COUNT(*) as total 
      FROM health_records 
      WHERE diagnosis IS NOT NULL 
      AND diagnosis != ''
    `;
    
    const [totalResults] = await db.execute(totalCountQuery);
    
    const totalConditions = (totalResults && totalResults[0] && totalResults[0].total) || 1;
    
    // Format the data for the frontend
    const conditionsData = (results || []).map(row => ({
      name: row.condition_name,
      patients: row.patient_count,
      percentage: Math.round((row.patient_count / totalConditions) * 100)
    }));

    res.status(200).json({
      success: true,
      data: conditionsData,
      count: conditionsData.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch baby conditions data",
      error: error.message
    });
  }
};

// Get age distribution data
exports.getAgeDistribution = async (req, res) => {
  try {
    const ageDistributionQuery = `
      SELECT 
        CASE 
          WHEN TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 0 AND 1 THEN '0-1 year'
          WHEN TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 2 AND 3 THEN '2-3 years'
          WHEN TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 4 AND 5 THEN '4-5 years'
          WHEN TIMESTAMPDIFF(YEAR, dob, CURDATE()) BETWEEN 6 AND 10 THEN '6-10 years'
          ELSE '11+ years'
        END as age_range,
        COUNT(*) as patient_count
      FROM patients
      WHERE dob IS NOT NULL
      GROUP BY age_range
      ORDER BY age_range
    `;
    
    const [results] = await db.execute(ageDistributionQuery);

    // Calculate total patients for percentage calculation
    const totalPatientsQuery = `
      SELECT COUNT(*) as total 
      FROM patients 
      WHERE dob IS NOT NULL
    `;
    
    const [totalResults] = await db.execute(totalPatientsQuery);
    
    const totalPatients = (totalResults && totalResults[0] && totalResults[0].total) || 1;
    
    // Format the data for the frontend
    const ageData = (results || []).map(row => ({
      range: row.age_range,
      babies: row.patient_count,
      percentage: Math.round((row.patient_count / totalPatients) * 100)
    }));

    res.status(200).json({
      success: true,
      data: ageData,
      count: ageData.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch age distribution data",
      error: error.message
    });
  }
};

// Get gender distribution data
exports.getGenderDistribution = async (req, res) => {
  try {
    const genderDistributionQuery = `
      SELECT 
        sex as gender,
        COUNT(*) as patient_count
      FROM patients
      WHERE sex IS NOT NULL AND sex != ''
      GROUP BY sex
      ORDER BY patient_count DESC
    `;
    
    const [results] = await db.execute(genderDistributionQuery);

    // Calculate total patients for percentage calculation
    const totalPatientsQuery = `
      SELECT COUNT(*) as total 
      FROM patients 
      WHERE sex IS NOT NULL AND sex != ''
    `;
    
    const [totalResults] = await db.execute(totalPatientsQuery);
    
    const totalPatients = (totalResults && totalResults[0] && totalResults[0].total) || 1;
    
    // Format the data for the frontend
    const genderData = (results || []).map(row => ({
      gender: row.gender,
      babies: row.patient_count,
      percentage: Math.round((row.patient_count / totalPatients) * 100)
    }));

    res.status(200).json({
      success: true,
      data: genderData,
      count: genderData.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch gender distribution data",
      error: error.message
    });
  }
};

// Get location distribution data
exports.getLocationDistribution = async (req, res) => {
  try {
    const locationDistributionQuery = `
      SELECT 
        SUBSTRING_INDEX(address, ',', -1) as location,
        COUNT(*) as patient_count
      FROM patients
      WHERE address IS NOT NULL AND address != ''
      GROUP BY location
      ORDER BY patient_count DESC
      LIMIT 10
    `;
    
    const [results] = await db.execute(locationDistributionQuery);

    // Calculate total patients for percentage calculation
    const totalPatientsQuery = `
      SELECT COUNT(*) as total 
      FROM patients 
      WHERE address IS NOT NULL AND address != ''
    `;
    
    const [totalResults] = await db.execute(totalPatientsQuery);
    
    const totalPatients = (totalResults && totalResults[0] && totalResults[0].total) || 1;
    
    // Format the data for the frontend
    const locationData = (results || []).map(row => ({
      location: row.location,
      babies: row.patient_count,
      percentage: Math.round((row.patient_count / totalPatients) * 100)
    }));

    res.status(200).json({
      success: true,
      data: locationData,
      count: locationData.length
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch location distribution data",
      error: error.message
    });
  }
};

// Get service type distribution data
exports.getServiceTypeDistribution = async (req, res) => {
  try {
    const serviceTypeQuery = `
      SELECT 
        service_type as service_type,
        COUNT(*) as patient_count
      FROM patients
      WHERE service_type IS NOT NULL
      GROUP BY service_type
    `;
    
    const [results] = await db.execute(serviceTypeQuery);

    // Format the data for the frontend
    const serviceData = (results || []).map(row => ({
      service_type: row.service_type,
      count: row.patient_count
    }));

    res.status(200).json({
      success: true,
      data: serviceData,
    });
  } catch (error) {
    console.error("❌ Database error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch service type distribution",
      error: error.message
    });
  }
};

// Emit real-time update when dashboard data changes
exports.emitUpdate = async (req, res) => {
  try {
    const io = req.app.locals.io;
    const { updateType, data } = req.body;
    
    if (io) {
      emitDashboardUpdate(io, updateType, data);
      res.status(200).json({ success: true, message: 'Update emitted successfully' });
    } else {
      res.status(500).json({ success: false, message: 'Socket.IO not available' });
    }
  } catch (error) {
    console.error("❌ Error emitting dashboard update:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to emit dashboard update",
      error: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// REPORTS ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

// GET /dashboard/reports/immunization-monthly
// Returns count of immunization patients registered per month for the current year
exports.getImmunizationMonthlyCounts = async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const [rows] = await db.execute(
      `SELECT
         MONTH(created_at) AS month_num,
         MONTHNAME(created_at) AS month_name,
         COUNT(*) AS count
       FROM patients
       WHERE service_type = 'immunization'
         AND YEAR(created_at) = ?
       GROUP BY month_num, month_name
       ORDER BY month_num`,
      [year]
    );

    const monthAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    // Build a full 12-month map initialised to 0, then fill actual values
    const result = {};
    monthAbbr.forEach(m => { result[m] = 0; });
    (rows || []).forEach(row => {
      const abbr = monthAbbr[row.month_num - 1];
      result[abbr] = Number(row.count);
    });

    res.status(200).json({ success: true, data: result, year });
  } catch (error) {
    console.error('❌ getImmunizationMonthlyCounts:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch immunization monthly counts', error: error.message });
  }
};

// GET /dashboard/reports/prenatal-monthly
// Returns count of maternal/prenatal patients registered per month for the current year
exports.getPrenatalMonthlyCounts = async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const [rows] = await db.execute(
      `SELECT
         MONTH(created_at) AS month_num,
         MONTHNAME(created_at) AS month_name,
         COUNT(*) AS count
       FROM patients
       WHERE service_type = 'maternal'
         AND YEAR(created_at) = ?
       GROUP BY month_num, month_name
       ORDER BY month_num`,
      [year]
    );

    const monthAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const result = {};
    monthAbbr.forEach(m => { result[m] = 0; });
    (rows || []).forEach(row => {
      const abbr = monthAbbr[row.month_num - 1];
      result[abbr] = Number(row.count);
    });

    res.status(200).json({ success: true, data: result, year });
  } catch (error) {
    console.error('❌ getPrenatalMonthlyCounts:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch prenatal monthly counts', error: error.message });
  }
};

// GET /dashboard/reports/vaccine-distribution
// Returns count of immunization patients grouped by their record_type (vaccine category)
exports.getVaccineDistribution = async (req, res) => {
  try {
    // Use health_records joined to immunization patients, grouped by record_type
    const [rows] = await db.execute(
      `SELECT
         COALESCE(NULLIF(hr.record_type, ''), 'General') AS category,
         COUNT(DISTINCT hr.patient_id) AS count
       FROM health_records hr
       JOIN patients p ON p.id = hr.patient_id
       WHERE p.service_type = 'immunization'
       GROUP BY category
       ORDER BY count DESC`
    );

    // Fallback: if no health records exist, count by patient record_type field
    let result = {};
    if (!rows || rows.length === 0) {
      const [pRows] = await db.execute(
        `SELECT
           COALESCE(NULLIF(record_type, ''), 'General') AS category,
           COUNT(*) AS count
         FROM patients
         WHERE service_type = 'immunization'
         GROUP BY category
         ORDER BY count DESC`
      );
      (pRows || []).forEach(r => { result[r.category] = Number(r.count); });
    } else {
      (rows || []).forEach(r => { result[r.category] = Number(r.count); });
    }

    res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error('❌ getVaccineDistribution:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch vaccine distribution', error: error.message });
  }
};

// GET /dashboard/reports/trimester-distribution
// Returns prenatal/maternal patients grouped by inferred trimester from age/DOB
// Uses patient record_description or record_type as trimester indicator if available,
// otherwise falls back to a proportional split of the total maternal count.
exports.getTrimesterDistribution = async (req, res) => {
  try {
    // Try to group by record_type which may contain trimester info
    const [rows] = await db.execute(
      `SELECT
         CASE
           WHEN LOWER(record_type) LIKE '%1st%' OR LOWER(record_description) LIKE '%1st%' THEN '1st Trimester'
           WHEN LOWER(record_type) LIKE '%2nd%' OR LOWER(record_description) LIKE '%2nd%' THEN '2nd Trimester'
           WHEN LOWER(record_type) LIKE '%3rd%' OR LOWER(record_description) LIKE '%3rd%' THEN '3rd Trimester'
           ELSE 'Unspecified'
         END AS trimester,
         COUNT(*) AS count
       FROM patients
       WHERE service_type = 'maternal'
       GROUP BY trimester
       ORDER BY count DESC`
    );

    const result = {};
    (rows || []).forEach(r => { result[r.trimester] = Number(r.count); });

    res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error('❌ getTrimesterDistribution:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch trimester distribution', error: error.message });
  }
};

// GET /dashboard/reports/immunization-patients
// Returns all immunization patients with their latest health record info
exports.getImmunizationPatients = async (req, res) => {
  try {
    // mysql2 prepared statements reject NaN/BigInt as LIMIT/OFFSET — use Number()|0 + query()
    const limit  = Math.min(200, Math.max(1, Number(req.query.limit  || 100) | 0));
    const offset = Math.max(0, Number(req.query.offset || 0) | 0);

    const [rows] = await db.query(
      `SELECT
         p.id,
         p.child_fullname,
         p.mother_fullname,
         p.dob,
         p.created_at,
         -- Latest health record for this patient
         (SELECT hr2.record_type
            FROM health_records hr2
           WHERE hr2.patient_id = p.id
           ORDER BY hr2.created_at DESC LIMIT 1) AS latest_record_type,
         -- All distinct vaccine record types as comma-separated string
         (SELECT GROUP_CONCAT(DISTINCT hr3.record_type ORDER BY hr3.created_at SEPARATOR ', ')
            FROM health_records hr3
           WHERE hr3.patient_id = p.id) AS vaccines_given,
         -- Next scheduled date from appointments
         (SELECT a.appointment_date
            FROM appointments a
           WHERE a.patient_id = p.id
             AND a.appointment_date >= CURDATE()
           ORDER BY a.appointment_date ASC LIMIT 1) AS next_due
       FROM patients p
       WHERE p.service_type = 'immunization'
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total FROM patients WHERE service_type = 'immunization'`
    );

    const data = (rows || []).map(r => ({
      childName:    r.child_fullname   || 'Unknown',
      motherName:   r.mother_fullname  || 'Unknown',
      dob:          r.dob              || null,
      vaccinesGiven: r.vaccines_given  || r.latest_record_type || 'General',
      nextDue:      r.next_due         || null,
      recordType:   r.latest_record_type || 'Immunization',
    }));

    res.status(200).json({
      success: true,
      data,
      total: Number(countRows[0]?.total || 0),
    });
  } catch (error) {
    console.error('❌ getImmunizationPatients:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch immunization patients', error: error.message });
  }
};

// GET /dashboard/reports/prenatal-patients
// Returns all maternal/prenatal patients
exports.getPrenatalPatients = async (req, res) => {
  try {
    // mysql2 prepared statements reject NaN/BigInt as LIMIT/OFFSET — use Number()|0 + query()
    const limit  = Math.min(200, Math.max(1, Number(req.query.limit  || 100) | 0));
    const offset = Math.max(0, Number(req.query.offset || 0) | 0);

    const [rows] = await db.query(
      `SELECT
         p.id,
         p.child_fullname,
         p.mother_fullname,
         p.dob,
         p.created_at,
         p.record_type,
         p.record_description,
         -- Last visit: most recent health record date
         (SELECT DATE(hr.created_at)
            FROM health_records hr
           WHERE hr.patient_id = p.id
           ORDER BY hr.created_at DESC LIMIT 1) AS last_visit,
         -- Next appointment date
         (SELECT a.appointment_date
            FROM appointments a
           WHERE a.patient_id = p.id
             AND a.appointment_date >= CURDATE()
           ORDER BY a.appointment_date ASC LIMIT 1) AS next_appointment
       FROM patients p
       WHERE p.service_type = 'maternal'
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total FROM patients WHERE service_type = 'maternal'`
    );

    const data = (rows || []).map(r => {
      // Infer trimester from record fields
      let trimester = 'Unspecified';
      const rt  = (r.record_type        || '').toLowerCase();
      const rd  = (r.record_description || '').toLowerCase();
      if (rt.includes('1st') || rd.includes('1st')) trimester = '1st Trimester';
      else if (rt.includes('2nd') || rd.includes('2nd')) trimester = '2nd Trimester';
      else if (rt.includes('3rd') || rd.includes('3rd')) trimester = '3rd Trimester';

      return {
        patientName:     r.mother_fullname || r.child_fullname || 'Unknown',
        dob:             r.dob             || null,
        trimester,
        lastVisit:       r.last_visit      || null,
        nextAppointment: r.next_appointment || null,
        riskLevel:       'Low', // no risk field in schema — default to Low
      };
    });

    res.status(200).json({
      success: true,
      data,
      total: Number(countRows[0]?.total || 0),
    });
  } catch (error) {
    console.error('❌ getPrenatalPatients:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch prenatal patients', error: error.message });
  }
};
