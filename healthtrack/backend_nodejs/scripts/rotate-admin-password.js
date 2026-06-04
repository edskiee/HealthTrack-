/**
 * Rotate default admin password on remote MySQL (e.g. Railway).
 *
 * Usage (PowerShell) — set Railway MySQL vars first:
 *   $env:DB_HOST="your-host"
 *   $env:DB_USER="root"
 *   $env:DB_PASS="your-pass"
 *   $env:DB_PORT="3306"
 *   $env:DB_NAME="healthtrack"
 *   node scripts/rotate-admin-password.js
 *
 * Optional: pass a password as the first argument.
 */
require("dotenv").config({ path: require("path").join(__dirname, "../.env") });
const crypto = require("crypto");
const mysql = require("mysql2/promise");

const username = process.env.ADMIN_USERNAME || "admin";
const newPassword = process.argv[2] || crypto.randomBytes(18).toString("base64url");

async function main() {
  const { DB_HOST, DB_USER, DB_PASS, DB_NAME } = process.env;
  const port = Number(process.env.DB_PORT || 3306);

  if (!DB_HOST || !DB_USER || !DB_PASS || !DB_NAME) {
    console.error("Missing DB_HOST, DB_USER, DB_PASS, or DB_NAME in environment.");
    process.exit(1);
  }

  if (DB_HOST === "localhost" && process.env.NODE_ENV === "production") {
    console.warn("Warning: DB_HOST is localhost — use Railway MySQL credentials.");
  }

  const hashedPassword = crypto.createHash("md5").update(newPassword).digest("hex");

  const conn = await mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASS,
    database: DB_NAME,
    port,
  });

  const [result] = await conn.execute(
    "UPDATE admins SET password = ? WHERE username = ?",
    [hashedPassword, username]
  );

  await conn.end();

  if (result.affectedRows === 0) {
    console.error(`No admin row updated for username "${username}".`);
    process.exit(1);
  }

  console.log("Admin password updated.");
  console.log("Username:", username);
  console.log("New password (save this securely):", newPassword);
  console.log("Stored as MD5 (matches backend adminLogin).");
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
