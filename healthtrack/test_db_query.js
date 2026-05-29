const db = require("./backend_nodejs/src/config/db");

async function testQuery() {
  try {
    console.log("Testing database query...");
    
    const sql = "SELECT * FROM admins WHERE username = ? AND password = ?";
    const params = ['admin', '098f6bcd4621d373cade4e832627b4f6']; // MD5 of 'test'
    
    console.log("Executing query:", sql);
    console.log("With parameters:", params);
    
    const [results] = await db.execute(sql, params);
    
    console.log("Query executed successfully");
    console.log("Results:", results);
    
    if (results.length > 0) {
      console.log("Admin user found:", results[0]);
    } else {
      console.log("No admin user found with these credentials");
    }
  } catch (error) {
    console.error("Error executing query:", error);
    console.error("Error code:", error.code);
    console.error("Error message:", error.message);
  }
}

testQuery();