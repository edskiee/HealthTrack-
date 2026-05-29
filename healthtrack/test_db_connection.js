const db = require("./backend_nodejs/src/config/db");

// Test database connection and simple query
console.log("Testing database connection...");

const sql = "SELECT * FROM admins WHERE username = ? AND password = ?";
const testCredentials = ['admin', '098f6bcd4621d373cade4e832627b4f6']; // MD5 hash of 'test'

console.log("Executing query:", sql);
console.log("With parameters:", testCredentials);

db.query(sql, testCredentials, (err, results) => {
  if (err) {
    console.error("❌ Database error:", err);
    console.error("Error code:", err.code);
    console.error("Error message:", err.message);
    return;
  }
  
  console.log("✅ Query executed successfully");
  console.log("Results:", results);
  
  if (results.length > 0) {
    console.log("✅ Admin user found:", results[0]);
  } else {
    console.log("❌ No admin user found with these credentials");
  }
});