const mysql = require('mysql2');

const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
});

console.log('Connecting to database...');

db.connect((err) => {
  if (err) {
    console.error('Error connecting to database:', err.message);
    process.exit(1);
  } else {
    console.log('✅ Connected to database');
    
    // Check users table
    db.query('DESCRIBE users', (err, results) => {
      if (err) {
        console.error('Error describing users table:', err.message);
      } else {
        console.log('\n📋 Users table structure:');
        results.forEach(row => {
          console.log(`  ${row.Field}: ${row.Type}`);
        });
      }
      
      // Check patients table
      db.query('DESCRIBE patients', (err, results) => {
        if (err) {
          console.error('Error describing patients table:', err.message);
        } else {
          console.log('\n📋 Patients table structure:');
          results.forEach(row => {
            console.log(`  ${row.Field}: ${row.Type}`);
          });
        }
        
        // Check notifications table
        db.query('DESCRIBE notifications', (err, results) => {
          if (err) {
            console.error('Error describing notifications table:', err.message);
          } else {
            console.log('\n📋 Notifications table structure:');
            results.forEach(row => {
              console.log(`  ${row.Field}: ${row.Type}`);
            });
          }
          
          // Close connection
          db.end();
        });
      });
    });
  }
});