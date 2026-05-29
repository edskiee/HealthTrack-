const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function applyMissingTables() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Read and execute the services_config table script
    const fs = require('fs');
    const path = require('path');
    
    const servicesConfigSql = fs.readFileSync(path.join(__dirname, 'database', 'services_config_table.sql'), 'utf8');
    console.log('Applying services_config table schema...');
    
    // Split the SQL into individual statements and execute them
    const servicesStatements = servicesConfigSql.split(';').filter(stmt => stmt.trim() !== '');
    
    for (const statement of servicesStatements) {
      if (statement.trim() !== '') {
        try {
          await connection.execute(statement);
          console.log('✓ Executed statement');
        } catch (err) {
          // Ignore errors for CREATE TABLE IF NOT EXISTS and INSERT IGNORE
          if (!err.message.includes('Duplicate') && !err.message.includes('already exists')) {
            console.warn('⚠ Warning:', err.message);
          }
        }
      }
    }
    
    console.log('✅ Services config table applied successfully');
    
    // Read and execute the health_workers table script
    const healthWorkersSql = fs.readFileSync(path.join(__dirname, 'database', 'health_workers_table.sql'), 'utf8');
    console.log('Applying health_workers table schema...');
    
    // Split the SQL into individual statements and execute them
    const healthWorkersStatements = healthWorkersSql.split(';').filter(stmt => stmt.trim() !== '');
    
    for (const statement of healthWorkersStatements) {
      if (statement.trim() !== '') {
        try {
          await connection.execute(statement);
          console.log('✓ Executed statement');
        } catch (err) {
          // Ignore errors for CREATE TABLE IF NOT EXISTS and INSERT IGNORE
          if (!err.message.includes('Duplicate') && !err.message.includes('already exists')) {
            console.warn('⚠ Warning:', err.message);
          }
        }
      }
    }
    
    console.log('✅ Health workers table applied successfully');
    
    // Verify tables were created
    const [tables] = await connection.execute("SHOW TABLES LIKE 'services_config'");
    if (tables.length > 0) {
      console.log('✅ services_config table verified');
    } else {
      console.error('❌ services_config table not found');
    }
    
    const [tables2] = await connection.execute("SHOW TABLES LIKE 'health_workers'");
    if (tables2.length > 0) {
      console.log('✅ health_workers table verified');
    } else {
      console.error('❌ health_workers table not found');
    }
    
    const [tables3] = await connection.execute("SHOW TABLES LIKE 'health_worker_schedule'");
    if (tables3.length > 0) {
      console.log('✅ health_worker_schedule table verified');
    } else {
      console.error('❌ health_worker_schedule table not found');
    }
    
  } catch (error) {
    console.error('❌ Error applying missing tables:', error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('✅ Database connection closed');
    }
  }
}

// Run the function
applyMissingTables();