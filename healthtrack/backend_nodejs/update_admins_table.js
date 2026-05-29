const db = require("./src/config/db");

async function updateAdminsTable() {
  try {
    console.log("Updating admins table schema...");
    
    // Add full_name column if it doesn't exist
    try {
      const addFullNameSql = "ALTER TABLE admins ADD COLUMN full_name VARCHAR(100)";
      await db.execute(addFullNameSql);
      console.log("✅ Added full_name column");
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log("✅ full_name column already exists");
      } else {
        console.error("Error adding full_name column:", error);
      }
    }
    
    // Add email column if it doesn't exist
    try {
      const addEmailSql = "ALTER TABLE admins ADD COLUMN email VARCHAR(100)";
      await db.execute(addEmailSql);
      console.log("✅ Added email column");
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log("✅ email column already exists");
      } else {
        console.error("Error adding email column:", error);
      }
    }
    
    // Add last_login column if it doesn't exist
    try {
      const addLastLoginSql = "ALTER TABLE admins ADD COLUMN last_login TIMESTAMP NULL";
      await db.execute(addLastLoginSql);
      console.log("✅ Added last_login column");
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log("✅ last_login column already exists");
      } else {
        console.error("Error adding last_login column:", error);
      }
    }
    
    // Add created_at column if it doesn't exist
    try {
      const addCreatedAtSql = "ALTER TABLE admins ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP";
      await db.execute(addCreatedAtSql);
      console.log("✅ Added created_at column");
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log("✅ created_at column already exists");
      } else {
        console.error("Error adding created_at column:", error);
      }
    }
    
    // Add updated_at column if it doesn't exist
    try {
      const addUpdatedAtSql = "ALTER TABLE admins ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP";
      await db.execute(addUpdatedAtSql);
      console.log("✅ Added updated_at column");
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log("✅ updated_at column already exists");
      } else {
        console.error("Error adding updated_at column:", error);
      }
    }
    
    console.log("✅ Admins table schema updated successfully!");
    process.exit(0);
  } catch (error) {
    console.error("❌ Error updating admins table:", error);
    process.exit(1);
  }
}

updateAdminsTable();