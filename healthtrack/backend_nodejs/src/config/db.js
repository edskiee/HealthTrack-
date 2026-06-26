"use strict";

const mysql = require("mysql2/promise");

// ─── Build connection config ──────────────────────────────────────────────────

function logDbConnectionHint(err) {
  if (!err || err.code !== "ENOTFOUND") return;

  console.error(`   DNS lookup failed for DB_HOST="${process.env.DB_HOST}"`);
  console.error("   That hostname does not exist. Copy the exact Host from your database provider:");
  console.error("   • Aiven: Console → MySQL service → Overview → Connection information");
  console.error("   • Railway: Project → MySQL → Variables → MYSQLHOST / MYSQLPORT");
  if (process.env.DB_NAME === "defaultdb" && process.env.DB_PORT === "3306") {
    console.error("   Hint: Aiven MySQL uses DB_PORT=12236 and DB_NAME=defaultdb (not 3306).");
  }
}

const requiredDbVars = ["DB_HOST", "DB_USER", "DB_PASS", "DB_NAME"];
const missingDbVars = requiredDbVars.filter((key) => !process.env[key]);
if (missingDbVars.length > 0) {
  console.error(`❌ Missing database env vars: ${missingDbVars.join(", ")}`);
}

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
    logDbConnectionHint(err);
  });

module.exports = pool;
