const mysql = require('mysql2/promise');
require('dotenv').config();

async function migrateDatabase() {
  const localConfig = {
    host: process.env.LOCAL_DB_HOST || 'localhost',
    user: process.env.LOCAL_DB_USER || 'root',
    password: process.env.LOCAL_DB_PASS || '',
    database: process.env.LOCAL_DB_NAME || 'healthtrack',
    port: process.env.LOCAL_DB_PORT || 3306
  };

  const railwayConfig = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306
  };

  try {
    console.log('Connecting to local database...');
    const localConnection = await mysql.createConnection(localConfig);
    
    console.log('Connecting to Railway database...');
    const railwayConnection = await mysql.createConnection(railwayConfig);
    
    console.log('Getting table list...');
    const [tables] = await localConnection.query('SHOW TABLES');
    
    for (const table of tables) {
      const tableName = Object.values(table)[0];
      console.log(`Migrating table: ${tableName}`);
      
      // Get data from local
      const [rows] = await localConnection.query(`SELECT * FROM ${tableName}`);
      
      if (rows.length > 0) {
        // Get column names
        const columns = Object.keys(rows[0]).join(', ');
        const placeholders = rows.map(() => '?').join(', ');
        
        // Insert into Railway
        for (const row of rows) {
          const values = Object.values(row);
          await railwayConnection.query(
            `INSERT INTO ${tableName} (${columns}) VALUES (${placeholders})`,
            values
          );
        }
        
        console.log(`  Migrated ${rows.length} rows from ${tableName}`);
      }
    }
    
    console.log('Migration completed successfully!');
    
    await localConnection.end();
    await railwayConnection.end();
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

migrateDatabase();
