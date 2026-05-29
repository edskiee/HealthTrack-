// Simple script to check if we can connect to the database
const mysql = require('mysql2');

// Database configuration (using the same config as the backend)
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

// Create connection
const connection = mysql.createConnection(dbConfig);

connection.connect((err) => {
  if (err) {
    console.error('Error connecting to database:', err);
    return;
  }
  console.log('Connected to database successfully');
  
  // Check for the specific admin user "edwin"
  connection.query('SELECT id, username, password FROM admins WHERE username = ?', ['edwin'], (err, results) => {
    if (err) {
      console.error('Error querying admin user:', err);
    } else {
      console.log('Admin user "edwin":', results);
    }
    
    // Check all admins
    connection.query('SELECT id, username, password FROM admins', (err, results) => {
      if (err) {
        console.error('Error querying admins:', err);
      } else {
        console.log('All admins:', results);
      }
      
      connection.end();
    });
  });
});