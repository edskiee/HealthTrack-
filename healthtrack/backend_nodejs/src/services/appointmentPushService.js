const db = require("../config/db");
const { sendPushNotification, normalizeFcmToken, isValidFcmToken } = require("./firebaseService");
const { isUserPushEnabled } = require("./pushNotificationPolicy");

const HEALTHTRACK_ICON = "ic_launcher";

async function createUserDeviceTokensTable() {
  const sql = `
    CREATE TABLE IF NOT EXISTS user_device_tokens (
      id INT PRIMARY KEY AUTO_INCREMENT,
      user_id INT NOT NULL,
      device_id VARCHAR(191) NOT NULL,
      fcm_token VARCHAR(500) NOT NULL,
      platform VARCHAR(32) DEFAULT NULL,
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_device_user (user_id, device_id),
      UNIQUE KEY uniq_token (fcm_token),
      INDEX idx_user_active (user_id, is_active),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `;
  await db.execute(sql);
}

async function getUserFcmTokens(userId) {
  await createUserDeviceTokensTable();
  const tokenSet = new Set();
  const [rows] = await db.execute(
    "SELECT fcm_token FROM user_device_tokens WHERE user_id = ? AND is_active = 1",
    [userId]
  );
  rows.forEach((row) => {
    const token = normalizeFcmToken(row.fcm_token);
    if (token && isValidFcmToken(token)) tokenSet.add(token);
  });

  const [users] = await db.execute("SELECT fcm_token FROM users WHERE id = ?", [userId]);
  if (users.length > 0 && users[0].fcm_token) {
    const fallbackToken = normalizeFcmToken(users[0].fcm_token);
    if (fallbackToken && isValidFcmToken(fallbackToken)) tokenSet.add(fallbackToken);
  }

  return Array.from(tokenSet);
}

async function deactivateInvalidToken(token) {
  await db.execute("UPDATE users SET fcm_token = NULL WHERE fcm_token = ?", [token]);
  await db.execute(
    "UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?",
    [token]
  );
}

async function hasRecentDuplicate(userId, notificationType, dedupeKey) {
  if (!dedupeKey) return false;
  await ensureDedupeColumn();
  const [rows] = await db.execute(
    `SELECT id FROM notification_history
     WHERE user_id = ? AND notification_type = ? AND dedupe_key = ?
     LIMIT 1`,
    [userId, notificationType, dedupeKey]
  );
  return rows.length > 0;
}

async function ensureDedupeColumn() {
  try {
    await db.execute("ALTER TABLE notification_history ADD COLUMN dedupe_key VARCHAR(191) NULL");
  } catch (error) {
    if (error.code !== "ER_DUP_FIELDNAME") throw error;
  }
}

async function persistHistory(userId, title, body, notificationType, payload, status, errorMessage, dedupeKey) {
  await ensureDedupeColumn();
  await db.execute(
    `INSERT INTO notification_history
    (user_id, title, message, notification_type, payload, status, error_message, dedupe_key, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
    [userId, title, body, notificationType, JSON.stringify(payload), status, errorMessage || null, dedupeKey || null]
  );
}

function buildPayload(type, title, body, data = {}) {
  const resolvedTitle = title || "HealthTrack";
  const resolvedBody = body || "You have a new notification";
  return {
    title: resolvedTitle,
    body: resolvedBody,
    icon: HEALTHTRACK_ICON,
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    notificationType: type,
    data: {
      ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      type,
      icon: HEALTHTRACK_ICON,
      timestamp: new Date().toISOString(),
      title: resolvedTitle,
      body: resolvedBody,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  };
}

async function sendToUserDevices(userId, type, title, body, data = {}, dedupeKey) {
  if (await hasRecentDuplicate(userId, type, dedupeKey)) {
    return { success: true, skipped: true, reason: "duplicate" };
  }

  if (!(await isUserPushEnabled(userId))) {
    console.log(`// DEBUG FCM skipped sendToUserDevices: user ${userId} disabled push`);
    return {
      success: false,
      error: "Push notifications disabled by user",
      code: "push-disabled-by-user",
      skipped: true,
    };
  }

  const tokens = await getUserFcmTokens(userId);
  if (tokens.length === 0) {
    await persistHistory(userId, title, body, type, buildPayload(type, title, body, data), "failed", "No active FCM tokens", dedupeKey);
    return { success: false, error: "No active FCM tokens" };
  }

  const payload = buildPayload(type, title, body, data);
  let successCount = 0;
  const failures = [];

  for (const token of tokens) {
    const result = await sendPushNotification(token, payload, userId);
    if (result.success) {
      successCount += 1;
      continue;
    }
    failures.push({ token, code: result.code, error: result.error });
    if (result.code === "messaging/invalid-registration-token" || result.code === "messaging/registration-token-not-registered") {
      await deactivateInvalidToken(token);
    }
  }

  await persistHistory(
    userId,
    title,
    body,
    type,
    payload,
    successCount > 0 ? "sent" : "failed",
    failures.length ? JSON.stringify(failures) : null,
    dedupeKey
  );

  return { success: successCount > 0, successCount, failureCount: failures.length, failures };
}

async function sendApprovalNotification(userToken, data, userId = null) {
  return sendPushNotification(
    userToken,
    buildPayload(
      "appointment_approved",
      data?.title || "Appointment Approved",
      data?.body || "Your appointment has been approved",
      data || {}
    ),
    userId
  );
}

async function sendRescheduleNotification(userToken, data, userId = null) {
  return sendPushNotification(
    userToken,
    buildPayload(
      "appointment_rescheduled",
      data?.title || "Appointment Rescheduled",
      data?.body || "Your appointment has been rescheduled",
      data || {}
    ),
    userId
  );
}

async function sendReminderNotification(userToken, data, userId = null) {
  return sendPushNotification(
    userToken,
    buildPayload(
      "appointment_reminder",
      data?.title || "Appointment Reminder",
      data?.body || "You have an upcoming appointment",
      data || {}
    ),
    userId
  );
}

module.exports = {
  createUserDeviceTokensTable,
  getUserFcmTokens,
  sendToUserDevices,
  sendApprovalNotification,
  sendRescheduleNotification,
  sendReminderNotification,
};
