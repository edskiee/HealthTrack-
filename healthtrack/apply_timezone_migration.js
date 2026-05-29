/**
 * Database migration script to add timezone column to users table
 * This script applies the timezone column fix
 */

const db = require('./backend_nodejs/src/config/db');

async function applyTimezoneMigration() {
  console.log('🔧 Applying timezone column migration...\n');

  try {
    // Check if timezone column already exists
    console.log('📋 Checking if timezone column already exists...');
    try {
      const [result] = await db.execute('DESCRIBE users');
      const timezoneColumn = result.find(col => col.Field === 'timezone');
      
      if (timezoneColumn) {
        console.log('✅ Timezone column already exists in users table');
        console.log(`   Type: ${timezoneColumn.Type}, Default: ${timezoneColumn.Default}`);
        return true;
      }
    } catch (error) {
      console.log('❌ Error checking timezone column:', error.message);
      return false;
    }

    // Add timezone column
    console.log('📋 Adding timezone column to users table...');
    try {
      await db.execute(`
        ALTER TABLE users 
        ADD COLUMN timezone VARCHAR(50) DEFAULT 'Asia/Manila' 
        AFTER fcm_token
      `);
      console.log('✅ Timezone column added successfully');
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log('⚠️ Timezone column already exists (duplicate field error)');
      } else {
        console.log('❌ Error adding timezone column:', error.message);
        return false;
      }
    }

    // Add index for better performance
    console.log('📋 Adding index for timezone column...');
    try {
      await db.execute(`
        ALTER TABLE users 
        ADD INDEX idx_timezone (timezone)
      `);
      console.log('✅ Timezone index added successfully');
    } catch (error) {
      if (error.code === 'ER_DUP_KEYNAME') {
        console.log('⚠️ Timezone index already exists');
      } else {
        console.log('⚠️ Warning: Could not add timezone index:', error.message);
      }
    }

    // Update existing users to have the default timezone
    console.log('📋 Updating existing users with default timezone...');
    try {
      const [result] = await db.execute(`
        UPDATE users 
        SET timezone = 'Asia/Manila' 
        WHERE timezone IS NULL
      `);
      console.log(`✅ Updated ${result.affectedRows} users with default timezone`);
    } catch (error) {
      console.log('⚠️ Warning: Could not update existing users:', error.message);
    }

    // Verify the migration
    console.log('📋 Verifying migration...');
    try {
      const [result] = await db.execute('DESCRIBE users');
      const timezoneColumn = result.find(col => col.Field === 'timezone');
      
      if (timezoneColumn) {
        console.log('✅ Timezone column verification successful');
        console.log(`   Type: ${timezoneColumn.Type}, Default: ${timezoneColumn.Default}`);
        
        // Show sample data
        const [users] = await db.execute(`
          SELECT id, username, timezone 
          FROM users 
          ORDER BY id 
          LIMIT 5
        `);
        
        console.log('✅ Sample user timezone data:');
        users.forEach(user => {
          console.log(`   User ${user.id} (${user.username}): ${user.timezone || 'NULL'}`);
        });
        
        return true;
      } else {
        console.log('❌ Timezone column verification failed');
        return false;
      }
    } catch (error) {
      console.log('❌ Error verifying migration:', error.message);
      return false;
    }

  } catch (error) {
    console.error('❌ Migration failed:', error);
    return false;
  }
}

// Run the migration
async function runMigration() {
  console.log('🚀 Starting timezone column migration...\n');
  
  const success = await applyTimezoneMigration();
  
  if (success) {
    console.log('\n🎉 Timezone column migration completed successfully!');
    console.log('📋 The appointment reminder system should now work without errors.');
    console.log('💡 You can now run: node test_timezone_fix.js to verify the fix.');
  } else {
    console.log('\n❌ Timezone column migration failed.');
    console.log('💡 Please check the errors above and try again.');
  }
  
  // Close database connection
  try {
    await db.end();
    console.log('\n🔌 Database connection closed');
  } catch (error) {
    console.log('⚠️ Error closing database connection:', error.message);
  }
  
  process.exit(success ? 0 : 1);
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run the migration
runMigration().catch(error => {
  console.error('❌ Migration runner failed:', error);
  process.exit(1);
});
