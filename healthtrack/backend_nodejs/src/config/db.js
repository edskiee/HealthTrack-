const mysql = require("mysql2/promise");

// Create a connection pool instead of a single connection
// This is more efficient and handles connection management better
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+08:00', // Set timezone to Asia/Manila
  dateStrings: true,   // Return dates as strings instead of Date objects
  charset: 'utf8mb4'
});

// Test the connection
pool.getConnection()
  .then(connection => {
    console.log("✅ Connected to MySQL database");
    connection.release(); // Return the connection to the pool
  })
  .catch(err => {
    console.error("❌ Failed to connect to MySQL:", err.message);
  });

module.exports = pool;
