const mysql = require('mysql2');

// Database connection configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

// Create connection
const connection = mysql.createConnection(dbConfig);

// Connect to database
connection.connect((err) => {
  if (err) {
    console.error('Error connecting to database:', err);
    return;
  }
  console.log('Connected to MySQL database');
  
  // Query to check the user with FCM token
  const query = `
    SELECT 
      id,
      username,
      email,
      full_name,
      fcm_token,
      LENGTH(fcm_token) as token_length,
      created_at
    FROM users
    WHERE fcm_token IS NOT NULL AND fcm_token != ''
    ORDER BY id
    LIMIT 1
  `;
  
  connection.query(query, (error, results) => {
    if (error) {
      console.error('Error executing query:', error);
      connection.end();
      return;
    }
    
    if (results.length > 0) {
      const user = results[0];
      console.log('\nUser with FCM Token:');
      console.log('====================');
      console.log(`ID: ${user.id}`);
      console.log(`Username: ${user.username}`);
      console.log(`Name: ${user.full_name}`);
      console.log(`Email: ${user.email}`);
      console.log(`Token Length: ${user.token_length}`);
      console.log(`Created At: ${user.created_at}`);
      console.log(`Token (first 50 chars): ${user.fcm_token.substring(0, 50)}...`);
    } else {
      console.log('No users found with FCM tokens');
    }
    
    connection.end();
  });
});