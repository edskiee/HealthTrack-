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
  
  // Query to check users and their FCM tokens
  const query = `
    SELECT 
      id,
      username,
      email,
      full_name,
      CASE 
        WHEN fcm_token IS NULL THEN 'No Token'
        WHEN fcm_token = '' THEN 'Empty Token'
        ELSE 'Has Token'
      END AS token_status,
      CASE 
        WHEN fcm_token IS NULL THEN 0
        WHEN fcm_token = '' THEN 0
        ELSE 1
      END AS has_valid_token
    FROM users
    ORDER BY id
  `;
  
  connection.query(query, (error, results) => {
    if (error) {
      console.error('Error executing query:', error);
      connection.end();
      return;
    }
    
    console.log('\nUser FCM Token Status:');
    console.log('======================');
    
    let usersWithTokens = 0;
    let totalUsers = results.length;
    
    results.forEach(user => {
      console.log(`ID: ${user.id} | Username: ${user.username} | Name: ${user.full_name} | Token Status: ${user.token_status}`);
      if (user.has_valid_token) {
        usersWithTokens++;
      }
    });
    
    console.log('\nSummary:');
    console.log(`Total Users: ${totalUsers}`);
    console.log(`Users with Valid FCM Tokens: ${usersWithTokens}`);
    console.log(`Users without Valid FCM Tokens: ${totalUsers - usersWithTokens}`);
    console.log(`Percentage with Tokens: ${((usersWithTokens / totalUsers) * 100).toFixed(2)}%`);
    
    connection.end();
  });
});