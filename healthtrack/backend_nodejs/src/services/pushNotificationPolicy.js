const db = require("../config/db");

const RETRYABLE_FCM_CODES = new Set([
  "messaging/internal-error",
  "messaging/server-unavailable",
  "messaging/unknown-error",
]);

/**
 * Mask FCM token for logs (// DEBUG).
 * @param {string} token
 * @returns {string}
 */
function maskFcmTokenForLog(token) {
  if (!token || typeof token !== "string" || token.length < 12) return "(invalid)";
  return `${token.slice(0, 4)}…${token.slice(-4)} (len=${token.length})`;
}

/**
 * Returns false when user has explicitly disabled push (push_notifications_enabled = 0).
 * If the column is missing (migration not applied), returns true.
 * @param {number|string|null|undefined} userId
 * @returns {Promise<boolean>}
 */
async function isUserPushEnabled(userId) {
  if (userId === null || userId === undefined) return true;
  const id = Number.parseInt(String(userId), 10);
  if (!Number.isFinite(id) || id <= 0) return true;
  try {
    const [rows] = await db.execute(
      "SELECT COALESCE(push_notifications_enabled, 1) AS en FROM users WHERE id = ?",
      [id]
    );
    if (!rows.length) return true;
    return Number(rows[0].en) !== 0;
  } catch (e) {
    if (e.code === "ER_BAD_FIELD_ERROR") return true;
    console.error("// DEBUG isUserPushEnabled query failed:", e.message || e);
    return true;
  }
}

module.exports = {
  RETRYABLE_FCM_CODES,
  maskFcmTokenForLog,
  isUserPushEnabled,
};
