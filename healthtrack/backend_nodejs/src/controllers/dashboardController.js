const db = require("../config/db");
// Removed HealthWorkerService reference since it's no longer used

// ─── 5-minute in-memory cache for /dashboard/reports/* ───────────────────────
//
// Keyed by a string built from the route + query params.
// Each entry: { data, expiresAt }
//
// Usage inside a controller:
//   const cached = reportCache.get(key);
//   if (cached) return res.json(cached);
//   ... query DB ...
//   reportCache.set(key, responseData);
//   return res.json(responseData);
//
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

const _cacheStore = new Map(); // key → { data, expiresAt }

const reportCache = {
  /** Return cached data if still fresh, otherwise null. */
  get(key) {
    const entry = _cacheStore.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      _cacheStore.delete(key);
      return null;
    }
    return entry.data;
  },

  /** Store data for CACHE_TTL_MS from now. */
  set(key, data) {
    _cacheStore.set(key, { data, expiresAt: Date.now() + CACHE_TTL_MS });
  },

  /** Invalidate a specific key (e.g. after admin triggers manual refresh). */
  invalidate(key) {
    _cacheStore.delete(key);
  },

  /** Flush ALL report cache entries — called when admin clicks Refresh. */
  flush() {
    _cacheStore.clear();
    console.log("🗑️  Report cache flushed");
  },

  /** Number of live entries — used by health/monitoring logs. */
  size() {
    // Prune expired entries while counting
    let live = 0;
    for (const [k, v] of _cacheStore) {
      if (Date.now() > v.expiresAt) { _cacheStore.delete(k); }
      else { live++; }
    }
    return live;
  },
};

// Expose cache so server.js can reference cache.size() in monitoring logs
module.exports.reportCache = reportCache;

// ─── Request-volume monitor ───────────────────────────────────────────────────
// Counts how many /dashboard/reports/* hits land in each 60-second window.
let _reportRequestCount = 0;
let _reportWindowStart  = Date.now();

function trackReportRequest(endpoint) {
  _reportRequestCount++;
  const now = Date.now();

  if (now - _reportWindowStart >= 60_000) {
    if (_reportRequestCount > 50) {
      console.warn(
        `⚠️  High reports request volume: ${_reportRequestCount} requests in the last 60s`
      );
    } else {
      console.log(
        `📊 Reports request volume: ${_reportRequestCount} req/min  (cache entries: ${reportCache.size()})`
      );
    }
    _reportRequestCount = 0;
    _reportWindowStart  = now;
  }
}

// Helper: build a cache key from a request
function cacheKey(req) {
  return `${req.path}?${new URLSearchParams(req.query).toString()}`;
}

// Helper: wrap a controller handler with cache + volume tracking
function withCache(handler) {
  return async (req, res, next) => {
    trackReportRequest(req.path);

    const key    = cacheKey(req);
    const cached = reportCache.get(key);

    if (cached) {
      console.log(`📦 Cache HIT  ${req.path}`);
      // Attach a header so the client knows it received cached data
      res.setHeader("X-Cache", "HIT");
      return res.json(cached);
    }

    console.log(`🔍 Cache MISS ${req.path} — querying DB`);
    res.setHeader("X-Cache", "MISS");

    // Intercept res.json to populate the cache transparently
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      // Only cache successful responses
      if (res.statusCode >= 200 && res.statusCode < 300 && body?.success !== false) {
        reportCache.set(key, body);
      }
      return originalJson(body);
    };

    return handler(req, res, next);
  };
}

// Export so routes can use it
module.exports.withCache = withCache;

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
// Returns all immunization patients with their latest health record info.
//
// BEFORE: 3 correlated subqueries per row × N rows = 3N extra queries.
// AFTER:  2 derived-table LEFT JOINs aggregated once for the whole result set,
//         plus COUNT(*) OVER() to eliminate the separate COUNT query.
exports.getImmunizationPatients = async (req, res) => {
  try {
    // mysql2 prepared statements reject NaN/BigInt as LIMIT/OFFSET — use Number()|0 + query()
    const limit  = Math.min(200, Math.max(1, Number(req.query.limit  || 100) | 0));
    const offset = Math.max(0, Number(req.query.offset || 0) | 0);

    // ── Derived table: one aggregate row per patient from health_records ──────
    // hr_agg gives us both latest_record_type and vaccines_given in a single
    // pass over health_records — replaces the two correlated subqueries on hr2/hr3.
    //
    // ── Derived table: earliest upcoming appointment per patient ─────────────
    // appt_next gives us next_due with a MIN() aggregate — replaces the
    // correlated subquery on appointments.
    //
    // ── COUNT(*) OVER() — total matching rows without a second round-trip ─────
    const [rows] = await db.query(
      `SELECT
         p.id,
         p.child_fullname,
         p.mother_fullname,
         p.dob,
         p.created_at,
         hr_agg.latest_record_type,
         hr_agg.vaccines_given,
         appt_next.next_due,
         COUNT(*) OVER() AS total_count
       FROM patients p
       -- Aggregate all health_records for immunization patients in one scan
       LEFT JOIN (
         SELECT
           patient_id,
           -- Latest record_type: use MAX trick on (created_at, record_type) pair
           SUBSTRING_INDEX(
             MAX(CONCAT(DATE_FORMAT(created_at, '%Y%m%d%H%i%s'), '||', record_type)),
             '||', -1
           ) AS latest_record_type,
           GROUP_CONCAT(DISTINCT record_type ORDER BY created_at SEPARATOR ', ') AS vaccines_given
         FROM health_records
         GROUP BY patient_id
       ) AS hr_agg ON hr_agg.patient_id = p.id
       -- Earliest future appointment per patient in one scan
       LEFT JOIN (
         SELECT patient_id, MIN(appointment_date) AS next_due
         FROM appointments
         WHERE appointment_date >= CURDATE()
         GROUP BY patient_id
       ) AS appt_next ON appt_next.patient_id = p.id
       WHERE p.service_type = 'immunization'
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const total = rows.length > 0 ? Number(rows[0].total_count || 0) : 0;

    const data = (rows || []).map(r => ({
      childName:     r.child_fullname       || 'Unknown',
      motherName:    r.mother_fullname      || 'Unknown',
      dob:           r.dob                  || null,
      vaccinesGiven: r.vaccines_given       || r.latest_record_type || 'General',
      nextDue:       r.next_due             || null,
      recordType:    r.latest_record_type   || 'Immunization',
    }));

    res.status(200).json({
      success: true,
      data,
      total,
    });
  } catch (error) {
    console.error('❌ getImmunizationPatients:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch immunization patients', error: error.message });
  }
};

// GET /dashboard/reports/prenatal-patients
// Returns all maternal/prenatal patients.
//
// BEFORE: 2 correlated subqueries per row + a separate COUNT query.
// AFTER:  2 derived-table LEFT JOINs aggregated once + COUNT(*) OVER() so
//         the total is read from the first result row — zero extra round-trips.
exports.getPrenatalPatients = async (req, res) => {
  try {
    // mysql2 prepared statements reject NaN/BigInt as LIMIT/OFFSET — use Number()|0 + query()
    const limit  = Math.min(200, Math.max(1, Number(req.query.limit  || 100) | 0));
    const offset = Math.max(0, Number(req.query.offset || 0) | 0);

    // ── hr_last: most recent health record date per patient ───────────────────
    // Replaces: (SELECT DATE(hr.created_at) … ORDER BY hr.created_at DESC LIMIT 1)
    //
    // ── appt_next: earliest upcoming appointment per patient ──────────────────
    // Replaces: (SELECT a.appointment_date … ORDER BY a.appointment_date ASC LIMIT 1)
    //
    // ── COUNT(*) OVER() eliminates the second SELECT COUNT(*) round-trip ──────
    const [rows] = await db.query(
      `SELECT
         p.id,
         p.child_fullname,
         p.mother_fullname,
         p.dob,
         p.created_at,
         p.record_type,
         p.record_description,
         hr_last.last_visit,
         appt_next.next_appointment,
         COUNT(*) OVER() AS total_count
       FROM patients p
       -- Most recent health record date per patient — single table scan
       LEFT JOIN (
         SELECT patient_id, DATE(MAX(created_at)) AS last_visit
         FROM health_records
         GROUP BY patient_id
       ) AS hr_last ON hr_last.patient_id = p.id
       -- Earliest upcoming appointment per patient — single table scan
       LEFT JOIN (
         SELECT patient_id, MIN(appointment_date) AS next_appointment
         FROM appointments
         WHERE appointment_date >= CURDATE()
         GROUP BY patient_id
       ) AS appt_next ON appt_next.patient_id = p.id
       WHERE p.service_type = 'maternal'
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const total = rows.length > 0 ? Number(rows[0].total_count || 0) : 0;

    const data = (rows || []).map(r => {
      // Infer trimester from record fields
      let trimester = 'Unspecified';
      const rt  = (r.record_type        || '').toLowerCase();
      const rd  = (r.record_description || '').toLowerCase();
      if (rt.includes('1st') || rd.includes('1st')) trimester = '1st Trimester';
      else if (rt.includes('2nd') || rd.includes('2nd')) trimester = '2nd Trimester';
      else if (rt.includes('3rd') || rd.includes('3rd')) trimester = '3rd Trimester';

      return {
        patientName:     r.mother_fullname  || r.child_fullname || 'Unknown',
        dob:             r.dob              || null,
        trimester,
        lastVisit:       r.last_visit       || null,
        nextAppointment: r.next_appointment || null,
        riskLevel:       'Low', // no risk field in schema — default to Low
      };
    });

    res.status(200).json({
      success: true,
      data,
      total,
    });
  } catch (error) {
    console.error('❌ getPrenatalPatients:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch prenatal patients', error: error.message });
  }
};


// ─────────────────────────────────────────────────────────────────────────────
// NEW REPORTS ENDPOINTS — Steps 1–6, 8–9
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Shared helper: parse a YYYY-MM-DD date string from a query param,
 * falling back to `defaultDate` if missing or invalid.
 */
function _parseDate(raw, defaultDate) {
  if (!raw) return defaultDate;
  const d = new Date(raw);
  return isNaN(d.getTime()) ? defaultDate : d;
}

function _fmtDate(d) {
  return d.toISOString().split('T')[0]; // "YYYY-MM-DD"
}

// ── Step 1: DOH Form 1 — real data from child_vaccine_records ────────────────
//
// GET /dashboard/reports/doh-form1?start=YYYY-MM-DD&end=YYYY-MM-DD
//
// Returns per-vaccine M/F/T counts grouped by month+year.
// Each row: { vaccine_key, vaccine_name, dose_number, month, year, male, female, total }
// The frontend groups these into the 17-row (months + quarters + annual) matrix.
exports.getDohForm1Data = async (req, res) => {
  try {
    const now = new Date();
    const defaultStart = new Date(now.getFullYear(), 0, 1); // Jan 1 current year
    const defaultEnd   = now;

    const startDate = _parseDate(req.query.start, defaultStart);
    const endDate   = _parseDate(req.query.end,   defaultEnd);

    // Clamp endDate to end of day
    const endDateEod = new Date(endDate);
    endDateEod.setHours(23, 59, 59, 999);

    const [rows] = await db.execute(
      `SELECT
         vs.vaccine_key,
         vs.vaccine_name,
         vs.dose_number,
         MONTH(cvr.given_at)   AS month_num,
         YEAR(cvr.given_at)    AS year_num,
         SUM(CASE WHEN LOWER(TRIM(p.sex)) IN ('male','m')   THEN 1 ELSE 0 END) AS male_count,
         SUM(CASE WHEN LOWER(TRIM(p.sex)) IN ('female','f') THEN 1 ELSE 0 END) AS female_count,
         COUNT(*) AS total_count
       FROM child_vaccine_records cvr
       JOIN vaccine_schedules vs  ON vs.id  = cvr.vaccine_schedule_id
       JOIN patients          p   ON p.id   = cvr.patient_id
       WHERE cvr.given_at IS NOT NULL
         AND cvr.given_at >= ?
         AND cvr.given_at <= ?
         AND p.service_type = 'immunization'
       GROUP BY vs.vaccine_key, vs.vaccine_name, vs.dose_number, month_num, year_num
       ORDER BY vs.sort_order, vs.dose_number, year_num, month_num`,
      [_fmtDate(startDate), _fmtDate(endDateEod)]
    );

    res.status(200).json({ success: true, data: rows || [], startDate: _fmtDate(startDate), endDate: _fmtDate(endDateEod) });
  } catch (error) {
    console.error('❌ getDohForm1Data:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch DOH Form 1 data', error: error.message });
  }
};

// ── Step 2: Immunization patients with real next-due dates ───────────────────
//
// GET /dashboard/reports/immunization-patients-v2?limit=200&offset=0&start=YYYY-MM-DD&end=YYYY-MM-DD
//
// Returns children with vaccinesGiven (comma-separated vaccine names from
// child_vaccine_records) and nextDue (earliest pending vaccine due date from
// vaccine_schedules computation done in the buildDoseList logic — approximated
// here as: earliest not-yet-given dose's due date).
//
// BEFORE: 4 correlated subqueries per row (vaccines_given, doses_given_count,
//         next_due_date, next_vaccine_name) + a separate COUNT query.
// AFTER:  3 derived-table LEFT JOINs aggregated once over the whole table
//         + COUNT(*) OVER() — eliminates the second round-trip entirely.
//
// How the "next pending dose" JOIN works without correlated NOT EXISTS:
//   cvr_given  aggregates given vaccine_schedule_ids per patient as a JSON array.
//   vs_pending picks the earliest schedule row whose id does NOT appear in
//   that array — one scan of vaccine_schedules, one scan of child_vaccine_records.
exports.getImmunizationPatientsV2 = async (req, res) => {
  try {
    const limit  = Math.min(500, Math.max(1, Number(req.query.limit  || 200) | 0));
    const offset = Math.max(0,               Number(req.query.offset || 0)   | 0);

    const now          = new Date();
    const defaultStart = new Date(2000, 0, 1);
    const startDate    = _parseDate(req.query.start, defaultStart);
    const endDate      = _parseDate(req.query.end,   now);
    endDate.setHours(23, 59, 59, 999);

    // ── cvr_given: per-patient aggregate of all given doses ──────────────────
    // Replaces the vaccines_given and doses_given_count correlated subqueries.
    //
    // ── vs_next: per-patient earliest pending vaccine_schedule ───────────────
    // Strategy: LEFT JOIN all schedules to given records, keep only rows where
    // the child has NOT received that schedule (given_at IS NULL after the join),
    // then pick the minimum sort_order per patient.
    // This replaces the two NOT EXISTS correlated subqueries for next_due_date
    // and next_vaccine_name.
    //
    // ── COUNT(*) OVER() removes the separate COUNT query ─────────────────────
    const [rows] = await db.query(
      `SELECT
         p.id,
         p.child_fullname,
         p.mother_fullname,
         p.dob,
         p.sex,
         p.barangay,
         p.created_at,
         cvr_given.vaccines_given,
         cvr_given.doses_given_count,
         vs_next.next_due_date,
         vs_next.next_vaccine_name,
         COUNT(*) OVER() AS total_count
       FROM patients p
       -- ── Aggregate given doses per patient (one scan of child_vaccine_records
       --    joined to vaccine_schedules) ──────────────────────────────────────
       LEFT JOIN (
         SELECT
           cvr.patient_id,
           GROUP_CONCAT(DISTINCT vs.vaccine_name ORDER BY vs.sort_order SEPARATOR ', ') AS vaccines_given,
           COUNT(cvr.id) AS doses_given_count
         FROM child_vaccine_records cvr
         JOIN vaccine_schedules vs ON vs.id = cvr.vaccine_schedule_id
         WHERE cvr.given_at IS NOT NULL
         GROUP BY cvr.patient_id
       ) AS cvr_given ON cvr_given.patient_id = p.id
       -- ── Earliest pending vaccine per patient ─────────────────────────────
       -- All schedules anti-joined against given records; pick first by sort_order.
       LEFT JOIN (
         SELECT
           pending.patient_id,
           DATE_ADD(pending.dob, INTERVAL pending.due_days_from_birth DAY) AS next_due_date,
           pending.vaccine_name AS next_vaccine_name
         FROM (
           SELECT
             p2.id          AS patient_id,
             p2.dob,
             vs2.vaccine_name,
             vs2.due_days_from_birth,
             vs2.sort_order,
             vs2.dose_number,
             -- NULL when the child has NOT received this schedule yet
             cvr2.given_at
           FROM patients p2
           JOIN vaccine_schedules vs2 ON 1=1        -- cross join: all schedules
           LEFT JOIN child_vaccine_records cvr2
             ON cvr2.patient_id = p2.id
            AND cvr2.vaccine_schedule_id = vs2.id
            AND cvr2.given_at IS NOT NULL
           WHERE p2.service_type = 'immunization'
             AND cvr2.id IS NULL                    -- not yet given
         ) AS pending
         -- Keep only the earliest pending schedule per patient
         WHERE (pending.patient_id, pending.sort_order, pending.dose_number) IN (
           SELECT patient_id, MIN(sort_order), MIN(dose_number)
           FROM (
             SELECT p3.id AS patient_id, vs3.sort_order, vs3.dose_number
             FROM patients p3
             JOIN vaccine_schedules vs3 ON 1=1
             LEFT JOIN child_vaccine_records cvr3
               ON cvr3.patient_id = p3.id
              AND cvr3.vaccine_schedule_id = vs3.id
              AND cvr3.given_at IS NOT NULL
             WHERE p3.service_type = 'immunization'
               AND cvr3.id IS NULL
           ) AS min_pending
           GROUP BY patient_id
         )
       ) AS vs_next ON vs_next.patient_id = p.id
       WHERE p.service_type = 'immunization'
         AND p.created_at >= ?
         AND p.created_at <= ?
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [_fmtDate(startDate), _fmtDate(endDate), limit, offset]
    );

    const total = rows.length > 0 ? Number(rows[0].total_count || 0) : 0;

    const data = (rows || []).map(r => {
      const nextDue = r.next_due_date ? new Date(r.next_due_date) : null;
      const today   = new Date(); today.setHours(0,0,0,0);
      let nextDueStatus = null;
      if (nextDue) {
        nextDue.setHours(0,0,0,0);
        nextDueStatus = nextDue < today ? 'overdue' : 'upcoming';
      }

      return {
        id:              r.id,
        childName:       r.child_fullname    || 'Unknown',
        motherName:      r.mother_fullname   || 'Unknown',
        dob:             r.dob               || null,
        sex:             r.sex               || null,
        barangay:        r.barangay          || null,
        vaccinesGiven:   r.vaccines_given    || (r.doses_given_count > 0 ? 'Doses given' : 'None yet'),
        dosesGivenCount: Number(r.doses_given_count || 0),
        nextDue:         r.next_due_date     || null,
        nextVaccineName: r.next_vaccine_name || null,
        nextDueStatus,
        recordType:      'Immunization',
      };
    });

    res.status(200).json({
      success: true,
      data,
      total,
    });
  } catch (error) {
    console.error('❌ getImmunizationPatientsV2:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch immunization patients v2', error: error.message });
  }
};

// ── Step 3: Vaccination coverage rate per vaccine ────────────────────────────
//
// GET /dashboard/reports/immunization-coverage
//
// For each vaccine_key, returns:
//   total_registered (immunization patients),
//   completed (children who have given_at for ALL doses of this vaccine),
//   coverage_pct
exports.getImmunizationCoverage = async (req, res) => {
  try {
    // Total immunization patients
    const [[{ total_registered }]] = await db.execute(
      `SELECT COUNT(*) AS total_registered FROM patients WHERE service_type = 'immunization'`
    );
    const total = Number(total_registered || 0);

    // Per vaccine: doses required + children who completed all doses
    const [rows] = await db.execute(
      `SELECT
         vs.vaccine_key,
         vs.vaccine_name,
         COUNT(DISTINCT vs.id)            AS doses_required,
         MIN(vs.sort_order)               AS min_sort_order,
         (SELECT COUNT(DISTINCT sub_cvr.patient_id)
            FROM child_vaccine_records sub_cvr
            JOIN vaccine_schedules sub_vs ON sub_vs.id = sub_cvr.vaccine_schedule_id
           WHERE sub_vs.vaccine_key = vs.vaccine_key
             AND sub_cvr.given_at IS NOT NULL
           GROUP BY sub_cvr.patient_id
          HAVING COUNT(DISTINCT sub_cvr.vaccine_schedule_id) = COUNT(DISTINCT sub_vs.id)
         ) AS completed_raw
       FROM vaccine_schedules vs
       GROUP BY vs.vaccine_key, vs.vaccine_name
       ORDER BY min_sort_order`
    );

    // Recalculate completed properly using a two-step query
    const coverage = [];
    for (const row of rows || []) {
      const dosesRequired = Number(row.doses_required || 1);
      const [compRows] = await db.execute(
        `SELECT COUNT(*) AS completed
           FROM (
             SELECT cvr.patient_id
               FROM child_vaccine_records cvr
               JOIN vaccine_schedules vs2 ON vs2.id = cvr.vaccine_schedule_id
              WHERE vs2.vaccine_key = ?
                AND cvr.given_at IS NOT NULL
              GROUP BY cvr.patient_id
             HAVING COUNT(DISTINCT cvr.vaccine_schedule_id) >= ?
           ) AS completed_patients`,
        [row.vaccine_key, dosesRequired]
      );
      const completed = Number(compRows[0]?.completed || 0);
      const pct = total > 0 ? Math.round((completed / total) * 100) : 0;
      coverage.push({
        vaccineKey:    row.vaccine_key,
        vaccineName:   row.vaccine_name,
        dosesRequired,
        completed,
        totalRegistered: total,
        coveragePct:   pct,
      });
    }

    res.status(200).json({ success: true, data: coverage, totalRegistered: total });
  } catch (error) {
    console.error('❌ getImmunizationCoverage:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch immunization coverage', error: error.message });
  }
};

// ── Step 4: Overdue children count per barangay ───────────────────────────────
//
// GET /dashboard/reports/overdue-by-barangay
//
// A child is "overdue" if at least one vaccine has a computed due date in the past
// and no given_at record exists.
// Approximation: given DOB + due_days_from_birth < TODAY and not yet given.
exports.getOverdueByBarangay = async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT
         COALESCE(NULLIF(TRIM(p.barangay), ''), 'Unspecified') AS barangay,
         COUNT(DISTINCT p.id)                                   AS overdue_children,
         -- Most common overdue vaccine
         (SELECT vs2.vaccine_name
            FROM vaccine_schedules vs2
            JOIN patients p2 ON p2.service_type = 'immunization'
           WHERE COALESCE(NULLIF(TRIM(p2.barangay),''), 'Unspecified')
                   = COALESCE(NULLIF(TRIM(p.barangay),''), 'Unspecified')
             AND p2.dob IS NOT NULL
             AND DATE_ADD(p2.dob, INTERVAL vs2.due_days_from_birth DAY) < CURDATE()
             AND NOT EXISTS (
               SELECT 1 FROM child_vaccine_records cvr2
                WHERE cvr2.patient_id = p2.id
                  AND cvr2.vaccine_schedule_id = vs2.id
                  AND cvr2.given_at IS NOT NULL
             )
           GROUP BY vs2.vaccine_name
           ORDER BY COUNT(*) DESC
           LIMIT 1) AS most_common_overdue_vaccine
       FROM patients p
       JOIN vaccine_schedules vs ON 1=1
       WHERE p.service_type = 'immunization'
         AND p.dob IS NOT NULL
         AND DATE_ADD(p.dob, INTERVAL vs.due_days_from_birth DAY) < CURDATE()
         AND NOT EXISTS (
           SELECT 1 FROM child_vaccine_records cvr
            WHERE cvr.patient_id = p.id
              AND cvr.vaccine_schedule_id = vs.id
              AND cvr.given_at IS NOT NULL
         )
       GROUP BY barangay
       ORDER BY overdue_children DESC`
    );

    res.status(200).json({ success: true, data: rows || [] });
  } catch (error) {
    console.error('❌ getOverdueByBarangay:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch overdue by barangay', error: error.message });
  }
};

// ── Step 5: Monthly completed vs missed appointments breakdown ────────────────
//
// GET /dashboard/reports/monthly-appointments?year=YYYY&serviceType=immunization|maternal
//
// Returns per-month completed and missed (no_show) appointment counts.
exports.getMonthlyAppointmentsBreakdown = async (req, res) => {
  try {
    const year        = parseInt(req.query.year) || new Date().getFullYear();
    const serviceType = (req.query.serviceType || 'immunization').toLowerCase();

    // Map serviceType to appointment_type LIKE pattern
    const typePattern = serviceType === 'maternal' ? '%maternal%' : '%immunization%';

    const [rows] = await db.execute(
      `SELECT
         MONTH(a.appointment_date) AS month_num,
         SUM(CASE WHEN a.status = 'completed' THEN 1 ELSE 0 END) AS completed,
         SUM(CASE WHEN a.status = 'no_show'   THEN 1 ELSE 0 END) AS missed
       FROM appointments a
       WHERE YEAR(a.appointment_date) = ?
         AND LOWER(a.appointment_type) LIKE ?
         AND a.status IN ('completed', 'no_show')
       GROUP BY month_num
       ORDER BY month_num`,
      [year, typePattern]
    );

    const monthAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const result = {};
    monthAbbr.forEach(m => { result[m] = { completed: 0, missed: 0 }; });
    (rows || []).forEach(row => {
      const abbr = monthAbbr[row.month_num - 1];
      if (abbr) {
        result[abbr].completed = Number(row.completed || 0);
        result[abbr].missed    = Number(row.missed    || 0);
      }
    });

    // Totals for the summary line
    const totalCompleted = Object.values(result).reduce((s, v) => s + v.completed, 0);
    const totalMissed    = Object.values(result).reduce((s, v) => s + v.missed,    0);
    const totalAll       = totalCompleted + totalMissed;
    const attendanceRate = totalAll > 0 ? Math.round((totalCompleted / totalAll) * 100) : 0;

    res.status(200).json({
      success: true,
      data: result,
      year,
      summary: { totalCompleted, totalMissed, attendanceRate },
    });
  } catch (error) {
    console.error('❌ getMonthlyAppointmentsBreakdown:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch monthly appointments breakdown', error: error.message });
  }
};

// ── Step 6: Barangay-level breakdown table ────────────────────────────────────
//
// GET /dashboard/reports/barangay-breakdown
//
// Returns per-barangay:
//   total_children, fully_vaccinated, partially_vaccinated, not_started, overdue_count
//
// Definitions:
//   fully_vaccinated    = all 14 vaccine schedule doses given
//   partially_vaccinated = 1–13 doses given, no overdue dose
//   not_started         = 0 doses given AND child's age >= 0 days
//   overdue_count       = children with ≥1 overdue dose
exports.getBarangayBreakdown = async (req, res) => {
  try {
    const TOTAL_DOSES = 14; // all doses in the EPI schedule

    const [rows] = await db.execute(
      `SELECT
         COALESCE(NULLIF(TRIM(p.barangay), ''), 'Unspecified') AS barangay,
         COUNT(DISTINCT p.id) AS total_children,
         -- Fully vaccinated: all 14 doses given
         COUNT(DISTINCT CASE
           WHEN (SELECT COUNT(*) FROM child_vaccine_records cvr_f
                  WHERE cvr_f.patient_id = p.id AND cvr_f.given_at IS NOT NULL) >= ?
           THEN p.id END) AS fully_vaccinated,
         -- Not started: 0 doses given
         COUNT(DISTINCT CASE
           WHEN (SELECT COUNT(*) FROM child_vaccine_records cvr_ns
                  WHERE cvr_ns.patient_id = p.id AND cvr_ns.given_at IS NOT NULL) = 0
           THEN p.id END) AS not_started,
         -- Overdue: at least one overdue dose (due_days_from_birth past + not given)
         COUNT(DISTINCT CASE
           WHEN EXISTS (
             SELECT 1 FROM vaccine_schedules vs_ov
              WHERE p.dob IS NOT NULL
                AND DATE_ADD(p.dob, INTERVAL vs_ov.due_days_from_birth DAY) < CURDATE()
                AND NOT EXISTS (
                  SELECT 1 FROM child_vaccine_records cvr_ov
                   WHERE cvr_ov.patient_id = p.id
                     AND cvr_ov.vaccine_schedule_id = vs_ov.id
                     AND cvr_ov.given_at IS NOT NULL
                )
           ) THEN p.id END) AS overdue_count
       FROM patients p
       WHERE p.service_type = 'immunization'
       GROUP BY barangay
       ORDER BY total_children DESC`,
      [TOTAL_DOSES]
    );

    // Compute partially_vaccinated = total - fully - not_started
    // (children with some doses but not all — may overlap with overdue)
    const data = (rows || []).map(r => {
      const total    = Number(r.total_children    || 0);
      const fully    = Number(r.fully_vaccinated  || 0);
      const notStart = Number(r.not_started       || 0);
      const overdue  = Number(r.overdue_count     || 0);
      const partial  = Math.max(0, total - fully - notStart);
      return {
        barangay:           r.barangay,
        totalChildren:      total,
        fullyVaccinated:    fully,
        partiallyVaccinated: partial,
        notStarted:         notStart,
        overdueCount:       overdue,
      };
    });

    res.status(200).json({ success: true, data });
  } catch (error) {
    console.error('❌ getBarangayBreakdown:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch barangay breakdown', error: error.message });
  }
};

// ── Step 8: Prenatal monthly completed vs missed ──────────────────────────────
// (reuses getMonthlyAppointmentsBreakdown with serviceType=maternal)
// No separate export needed — the frontend passes serviceType=maternal.
