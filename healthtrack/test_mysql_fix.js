/**
 * Test script to verify MySQL promise fixes
 * 
 * This script tests the MySQL connection and queries to ensure
 * the promise-based approach is working correctly.
 */

const db = require("./backend_nodejs/src/config/db");

async function testConnection() {
  console.log("🧪 Testing MySQL connection and queries...");
  
  try {
    // Test basic connection
    console.log("1. Testing database connection...");
    const connection = await db.getConnection();
    console.log("✅ Database connection successful");
    
    // Test a simple query
    console.log("2. Testing simple query...");
    const [results] = await connection.execute("SELECT 1 as test");
    console.log("✅ Simple query successful:", results);
    
    // Test querying users table
    console.log("3. Testing users table query...");
    const [users] = await connection.execute("SELECT COUNT(*) as count FROM users");
    console.log("✅ Users table query successful. User count:", users[0].count);
    
    // Test querying patients table
    console.log("4. Testing patients table query...");
    const [patients] = await connection.execute("SELECT COUNT(*) as count FROM patients");
    console.log("✅ Patients table query successful. Patient count:", patients[0].count);
    
    // Test querying health_records table
    console.log("5. Testing health_records table query...");
    const [records] = await connection.execute("SELECT COUNT(*) as count FROM health_records");
    console.log("✅ Health records table query successful. Record count:", records[0].count);
    
    // Test querying appointments table
    console.log("6. Testing appointments table query...");
    const [appointments] = await connection.execute("SELECT COUNT(*) as count FROM appointments");
    console.log("✅ Appointments table query successful. Appointment count:", appointments[0].count);
    
    // Release the connection
    connection.release();
    
    console.log("\n🎉 All tests passed! MySQL promise fixes are working correctly.");
    console.log("\nYou can now start your backend server with: node backend_nodejs/src/server.js");
    
  } catch (error) {
    console.error("❌ Test failed:", error.message);
    console.error("Stack trace:", error.stack);
  }
}

// Run the test
testConnection();