const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

async function applyNotificationsTable() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Create notifications table
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS notifications (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        appointment_id INT,
        notification_type ENUM('admin_appointment_notification', 'appointment_reminder', 'medication_reminder', 'follow_up_reminder', 'custom_message', 'system', 'status_update') NOT NULL,
        title VARCHAR(255),
        message TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        read_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
        INDEX idx_user_id (user_id),
        INDEX idx_notification_type (notification_type),
        INDEX idx_is_read (is_read),
        INDEX idx_created_at (created_at),
        
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL
      )
    `;
    
    await connection.execute(createTableQuery);
    console.log('✅ Notifications table created or already exists');
    
    // Close connection
    await connection.end();
    console.log('✅ Database connection closed');
    
  } catch (error) {
    console.error('❌ Error applying notifications table:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

// Run the function
applyNotificationsTable();