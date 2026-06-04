"use strict";

const mysql = require("mysql2/promise");

// ─── Build connection config ──────────────────────────────────────────────────

const poolConfig = {
  host:             process.env.DB_HOST,
  user:             process.env.DB_USER,
  password:         process.env.DB_PASS,
  database:         process.env.DB_NAME,
  port:             parseInt(process.env.DB_PORT || "3306", 10),
  waitForConnections: true,
  connectionLimit:  10,
  queueLimit:       0,
  timezone:         "+08:00",  // Asia/Manila
  dateStrings:      true,       // Return DATE/DATETIME as strings, not JS Date objects
  charset:          "utf8mb4",
};

// Railway MySQL requires SSL — enable when DB_SSL=true or NODE_ENV=production
// and a non-localhost host is configured.
const isRemoteHost =
  process.env.DB_HOST &&
  !["localhost", "127.0.0.1", "::1"].includes(process.env.DB_HOST);

if (isRemoteHost || process.env.DB_SSL === "true") {
  poolConfig.ssl = { rejectUnauthorized: false }; // Railway uses self-signed certs
}

// ─── Create pool ──────────────────────────────────────────────────────────────

const pool = mysql.createPool(poolConfig);

// Test connection on startup — log result but do NOT crash the process.
// Render may start the container before Railway MySQL is fully ready;
// mysql2 will retry from the pool automatically.
pool.getConnection()
  .then(connection => {
    console.log("✅ Connected to MySQL database");
    connection.release();
  })
  .catch(err => {
    console.error("❌ MySQL connection error:", err.message);
    console.error("   Check DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT env vars.");
  });

module.exports = pool;
