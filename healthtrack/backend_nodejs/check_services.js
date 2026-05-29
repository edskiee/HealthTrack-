const db = require('./src/config/db');

async function checkServices() {
  try {
    const [rows] = await db.execute('SELECT * FROM services_config');
    console.log('Services in database:');
    rows.forEach(row => {
      console.log(`- ID: ${row.id}, Name: ${row.service_name}, Type: ${row.service_type}, Enabled: ${row.is_enabled}`);
    });
  } catch (error) {
    console.error('Error fetching services:', error);
  } finally {
    process.exit(0);
  }
}

checkServices();