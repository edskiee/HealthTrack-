const db = require("./backend_nodejs/src/config/db");

async function testDashboardQuery() {
  try {
    console.log("Testing dashboard statistics query...");
    
    const statsQuery = `
      SELECT 
        (SELECT COUNT(*) FROM patients) as totalPatients,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE()) as appointmentsToday,
        (SELECT COUNT(*) FROM appointments WHERE status = 'scheduled') as pendingApprovals,
        (SELECT COUNT(*) FROM health_records WHERE DATE(created_at) = CURDATE()) as todayRecords,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'maternal') as maternalPatients,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'immunization') as immunizationPatients,
        (SELECT COUNT(*) FROM patients WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newPatientsLast30Days,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE() AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newAppointmentsLast30Days,
        (SELECT COUNT(*) FROM health_records WHERE DATE(created_at) = CURDATE() AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) as newRecordsLast30Days
    `;
    
    console.log("Executing stats query:", statsQuery);
    
    const [statsResults] = await db.execute(statsQuery);
    console.log("Stats query executed successfully");
    console.log("Stats results:", statsResults);
    
    // Query to get last month's data for comparison
    const lastMonthQuery = `
      SELECT 
        (SELECT COUNT(*) FROM patients WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthPatients,
        (SELECT COUNT(*) FROM appointments WHERE DATE(appointment_date) = CURDATE() AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthAppointments,
        (SELECT COUNT(*) FROM health_records WHERE DATE(created_at) = CURDATE() AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthRecords,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'maternal' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthMaternalPatients,
        (SELECT COUNT(*) FROM patients WHERE service_type = 'immunization' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)) as lastMonthImmunizationPatients
    `;
    
    console.log("Executing last month query:", lastMonthQuery);
    
    const [lastMonthResults] = await db.execute(lastMonthQuery);
    console.log("Last month query executed successfully");
    console.log("Last month results:", lastMonthResults);
    
  } catch (error) {
    console.error("Error executing dashboard query:", error);
    console.error("Error code:", error.code);
    console.error("Error message:", error.message);
    if (error.sql) {
      console.error("SQL query that failed:", error.sql);
    }
  }
}

testDashboardQuery();