const fs = require('fs');
const mysql = require('mysql2/promise');

// Read the SQL file - fixed path
const sql = fs.readFileSync('../database/services_config_table.sql', 'utf8');

// Database configuration - using the same credentials as the backend
const config = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15', // Using the password from the backend config
  database: 'healthtrack',
  multipleStatements: true
};

async function applyServicesConfig() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(config);
    
    console.log('Connected to database');
    
    // Execute the SQL script
    const [results] = await connection.query(sql);
    
    console.log('Services config table created successfully!');
    console.log('Results:', results);
    
  } catch (error) {
    console.error('Error applying services config:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('Database connection closed');
    }
  }
}

// Run the function
applyServicesConfig();