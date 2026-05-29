// index.js
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const admin = require('firebase-admin');
const mysql = require('mysql2/promise');
const path = require('path');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ---------------- CONFIG ----------------
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json'); // put your JSON here
const PORT = 3000;
const DB_CONFIG = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',       // <-- set your MySQL password
  database: 'healthtrack'
};
// ----------------------------------------

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

// Get DB connection
async function getDbConnection() {
  return await mysql.createConnection(DB_CONFIG);
}

// Save device token
app.post('/api/save_token', async (req, res) => {
  try {
    const { user_id, fcm_token } = req.body;
    if (!user_id || !fcm_token) return res.status(400).json({ status: 'error', message: 'Missing user_id or fcm_token' });

    const conn = await getDbConnection();
    const [result] = await conn.execute('UPDATE users SET fcm_token = ? WHERE id = ?', [fcm_token, user_id]);
    await conn.end();
    return res.json({ status: 'success', result });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// Send FCM to a token (single send)
app.post('/api/send_fcm', async (req, res) => {
  try {
    const { token, title, body, data } = req.body;
    if (!token) return res.status(400).json({ status: 'error', message: 'Missing token' });

    const message = {
      token,
      notification: { title: title || 'HealthTrack', body: body || '' },
      data: data || {}
    };

    const response = await admin.messaging().send(message);
    return res.json({ status: 'success', response });
  } catch (err) {
    console.error('send_fcm error:', err);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// Admin endpoint: save notification row and send push to user
app.post('/api/admin/send_notification', async (req, res) => {
  try {
    const { user_id, title, body, data } = req.body;
    if (!user_id || !title) return res.status(400).json({ status: 'error', message: 'Missing user_id or title' });

    const conn = await getDbConnection();
    const [rows] = await conn.execute('SELECT fcm_token FROM users WHERE id = ?', [user_id]);
    const token = rows[0] ? rows[0].fcm_token : null;

    // save notification to DB
    const dataPayload = JSON.stringify(data || {});
    await conn.execute('INSERT INTO notifications (user_id, title, body, data_payload) VALUES (?, ?, ?, ?)', [user_id, title, body, dataPayload]);
    await conn.end();

    if (!token) {
      return res.json({ status: 'warning', message: 'Notification saved in DB but user has no token' });
    }

    const message = {
      token,
      notification: { title, body },
      data: data || {}
    };

    const fcmResponse = await admin.messaging().send(message);
    return res.json({ status: 'success', fcmResponse });
  } catch (err) {
    console.error('admin/send_notification error:', err);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`HealthTrack API running on http://localhost:${PORT}`);
});
