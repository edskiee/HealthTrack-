const db = require("../config/db");

async function writeAudit(adminId, action, req, metadata = null) {
  try {
    const ua = typeof req?.get === "function" ? req.get("User-Agent") : "";
    await db.execute(
      `INSERT INTO audit_logs (admin_id, action, ip_address, user_agent, metadata)
       VALUES (?, ?, ?, ?, ?)`,
      [
        adminId,
        action,
        req?.ip ?? null,
        ua || null,
        metadata === null ? null : JSON.stringify(metadata),
      ]
    );
  } catch (e) {
    console.warn("⚠️ audit_logs insert failed:", e.message);
  }
}

module.exports = { writeAudit };
