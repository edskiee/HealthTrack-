/**
 * Firebase Admin SDK Service
 * Initializes using environment variables only — no JSON key files.
 *
 * Required environment variables:
 *   FIREBASE_PROJECT_ID
 *   FIREBASE_PRIVATE_KEY   (with literal \n characters for newlines)
 *   FIREBASE_CLIENT_EMAIL
 */

const admin = require('firebase-admin');
const db = require("../config/db");
const { isUserPushEnabled, maskFcmTokenForLog, RETRYABLE_FCM_CODES } = require("./pushNotificationPolicy");

// ─── Firebase Initialization ──────────────────────────────────────────────────

let firebaseAdmin = null;

function initializeFirebase() {
  const projectId   = process.env.FIREBASE_PROJECT_ID;
  const privateKey  = process.env.FIREBASE_PRIVATE_KEY;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

  if (!projectId || !privateKey || !clientEmail) {
    console.warn(
      '⚠️  Firebase credentials missing. Set FIREBASE_PROJECT_ID, ' +
      'FIREBASE_PRIVATE_KEY, and FIREBASE_CLIENT_EMAIL. ' +
      'Push notifications will be disabled.'
    );
    return null;
  }

  try {
    const app = admin.initializeApp({
      credential: admin.credential.cert({
        project_id:   projectId,
        private_key:  privateKey.replace(/\\n/g, '\n'),
        client_email: clientEmail,
      }),
    });
    console.log('✅ Firebase Admin SDK initialized successfully');
    return app;
  } catch (error) {
    console.error('❌ Firebase Admin SDK initialization failed:', error.message);
    return null;
  }
}

firebaseAdmin = initializeFirebase();

// ─── Token Helpers ────────────────────────────────────────────────────────────

/**
 * Returns true when the token string passes basic format requirements.
 * FCM tokens: long, no spaces, alphanumeric + colon/dash/underscore/period.
 */
function isValidFcmToken(token) {
  if (!token || typeof token !== 'string') return false;
  if (token.includes(' '))  return false;
  if (token.length < 50)    return false;
  return /^[a-zA-Z0-9:_\-.]+$/.test(token);
}

/**
 * Trims whitespace and strips accidental surrounding quotes.
 */
function normalizeFcmToken(token) {
  if (typeof token !== 'string') return token;
  let t = token.trim();
  if ((t.startsWith('"') && t.endsWith('"')) ||
      (t.startsWith("'") && t.endsWith("'"))) {
    t = t.slice(1, -1).trim();
  }
  return t;
}

// ─── Internal DB Helpers ──────────────────────────────────────────────────────

async function scrubInvalidFcmTokenEverywhere(normalizedToken) {
  if (!normalizedToken) return;
  try {
    await db.execute('UPDATE users SET fcm_token = NULL WHERE fcm_token = ?',              [normalizedToken]);
    await db.execute('UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?',    [normalizedToken]);
  } catch (dbError) {
    console.error('FCM scrub DB error:', dbError.message || dbError);
  }
}

async function resolveUserIdForFcmToken(normalizedToken) {
  if (!normalizedToken) return null;
  try {
    const [fromUser] = await db.execute(
      'SELECT id FROM users WHERE fcm_token = ? LIMIT 1', [normalizedToken]
    );
    if (fromUser.length) return fromUser[0].id;
    const [fromDevices] = await db.execute(
      'SELECT user_id FROM user_device_tokens WHERE fcm_token = ? AND is_active = 1 LIMIT 1',
      [normalizedToken]
    );
    if (fromDevices.length) return fromDevices[0].user_id;
  } catch (e) {
    console.error('resolveUserIdForFcmToken failed:', e.message || e);
  }
  return null;
}

// ─── Firebase Validation ──────────────────────────────────────────────────────

/**
 * Validates an FCM token against Firebase (dry-run send).
 */
async function validateFcmTokenWithFirebase(token) {
  if (!firebaseAdmin) {
    return { success: false, code: 'firebase-not-initialized', error: 'Firebase Admin SDK not initialized' };
  }

  const normalized = normalizeFcmToken(token);
  if (!isValidFcmToken(normalized)) {
    return { success: false, code: 'invalid-format', error: 'Invalid FCM token format' };
  }

  if (process.env.TEST_MODE === 'true') {
    return { success: true };
  }

  try {
    await firebaseAdmin.messaging().send(
      { token: normalized, data: { healthtrack_validate: '1', ts: String(Date.now()) } },
      true // dry run
    );
    return { success: true };
  } catch (error) {
    return { success: false, code: error.code || 'unknown-error', error: error.message };
  }
}

// ─── Push Notification Helpers ────────────────────────────────────────────────

function buildAndroidConfig(icon, clickAction) {
  return {
    priority: 'high',
    notification: {
      channelId: 'healthtrack_fcm_channel',
      sound: 'default',
      priority: 'high',
      icon,
      clickAction,
    },
  };
}

function buildApnsConfig(title, body) {
  return {
    headers: { 'apns-priority': '10' },
    payload: {
      aps: {
        alert: { title, body },
        sound: 'default',
        badge: 1,
        'content-available': 1,
      },
    },
  };
}

function buildMessageData(payload, title, body, icon, clickAction, type, timestamp) {
  return {
    ...(payload.data || {}),
    title:            String(title),
    body:             String(body),
    timestamp,
    type,
    notificationType: type,
    icon,
    click_action:     clickAction,
  };
}

// ─── Send Single Push Notification ───────────────────────────────────────────

/**
 * Send a push notification to a single FCM device token.
 * @param {string}          deviceToken  FCM device token
 * @param {Object}          payload      { title, body, notificationType, data, ... }
 * @param {number|string|null} forUserId Optional userId to check push preference
 */
async function sendPushNotification(deviceToken, payload, forUserId = null) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  const isTestMode      = process.env.TEST_MODE === 'true';
  const normalizedToken = normalizeFcmToken(deviceToken);

  if (!isTestMode && !isValidFcmToken(normalizedToken)) {
    console.warn('FCM skipped: invalid/missing token format');
    return { success: false, error: 'Invalid or missing FCM token', code: 'invalid-argument' };
  }

  let effectiveUserId = Number.parseInt(String(forUserId ?? ''), 10);
  if (!Number.isFinite(effectiveUserId) || effectiveUserId <= 0) {
    effectiveUserId = await resolveUserIdForFcmToken(normalizedToken);
  }

  if (effectiveUserId && !(await isUserPushEnabled(effectiveUserId))) {
    console.log(`FCM skipped: push disabled for userId=${effectiveUserId}`);
    return { success: false, error: 'Push notifications disabled by user', code: 'push-disabled-by-user' };
  }

  if (isTestMode) {
    console.log('TEST MODE: simulated FCM send');
    return { success: true, messageId: 'test_message_id_' + Date.now() };
  }

  const title       = payload.title  || 'HealthTrack Notification';
  const body        = payload.body   || payload.message || 'You have a new notification';
  const icon        = String(payload.icon        || payload.data?.icon        || 'ic_launcher');
  const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
  const type        = String(payload.notificationType || payload.data?.type   || 'system');
  const timestamp   = String(payload.timestamp   || payload.data?.timestamp   || new Date().toISOString());

  const message = {
    token:        normalizedToken,
    notification: { title, body },
    data:         buildMessageData(payload, title, body, icon, clickAction, type, timestamp),
    android:      buildAndroidConfig(icon, clickAction),
    apns:         buildApnsConfig(title, body),
  };

  console.log(
    `FCM → userId=${effectiveUserId ?? 'unknown'} ` +
    `token=${maskFcmTokenForLog(normalizedToken)} ` +
    `title="${title}" body="${String(body).slice(0, 80)}"`
  );

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await firebaseAdmin.messaging().send(message);
      console.log(`FCM OK messageId=${response} attempt=${attempt}`);
      return { success: true, messageId: response };
    } catch (error) {
      console.error(`FCM ERR attempt=${attempt} code=${error.code} msg=${error.message}`);

      if (
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered'
      ) {
        await scrubInvalidFcmTokenEverywhere(normalizedToken);
        return { success: false, error: 'FCM token invalid or not registered', code: error.code };
      }
      if (error.code === 'messaging/invalid-argument') {
        return { success: false, error: 'Invalid argument in FCM message', code: error.code };
      }
      if (error.code === 'messaging/authentication-error') {
        console.error('Firebase auth error — check FIREBASE_* environment variables');
        return { success: false, error: 'Firebase authentication error', code: error.code };
      }

      if (RETRYABLE_FCM_CODES.has(error.code) && attempt < 3) {
        await new Promise(r => setTimeout(r, 500 * attempt));
        continue;
      }

      return { success: false, error: error.message, code: error.code || 'unknown-error' };
    }
  }

  return { success: false, error: 'FCM send exhausted retries', code: 'unknown-error' };
}

// ─── Send Multicast Push Notification ────────────────────────────────────────

/**
 * Send a push notification to multiple FCM device tokens.
 * @param {string[]} deviceTokens
 * @param {Object}   payload
 */
async function sendMulticastPushNotification(deviceTokens, payload) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) {
    throw new Error('Device tokens must be a non-empty array');
  }

  const validTokens = [...new Set(
    deviceTokens.map(normalizeFcmToken).filter(isValidFcmToken)
  )];

  if (validTokens.length === 0) {
    console.warn('FCM multicast: no valid tokens');
    return { success: false, error: 'No valid FCM tokens provided', code: 'invalid-argument' };
  }

  const title       = payload.title  || 'HealthTrack Notification';
  const body        = payload.body   || payload.message || 'You have a new notification';
  const icon        = String(payload.icon        || payload.data?.icon        || 'ic_launcher');
  const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
  const type        = String(payload.notificationType || payload.data?.type   || 'system');
  const timestamp   = String(payload.timestamp   || payload.data?.timestamp   || new Date().toISOString());

  const message = {
    tokens:       validTokens,
    notification: { title, body },
    data:         buildMessageData(payload, title, body, icon, clickAction, type, timestamp),
    android:      buildAndroidConfig(icon, clickAction),
    apns:         buildApnsConfig(title, body),
  };

  console.log(`FCM multicast tokens=${validTokens.length} first=${maskFcmTokenForLog(validTokens[0])}`);

  let response = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      response = await firebaseAdmin.messaging().sendEachForMulticast(message);
      break;
    } catch (error) {
      console.error(`FCM multicast ERR attempt=${attempt} code=${error.code} msg=${error.message}`);
      if (RETRYABLE_FCM_CODES.has(error.code) && attempt < 3) {
        await new Promise(r => setTimeout(r, 500 * attempt));
        continue;
      }
      return { success: false, error: error.message, code: error.code || 'unknown-error' };
    }
  }

  if (!response) {
    return { success: false, error: 'Multicast send failed', code: 'unknown-error' };
  }

  if (response.failureCount > 0) {
    for (let idx = 0; idx < response.responses.length; idx++) {
      const resp = response.responses[idx];
      if (!resp.success) {
        const err = resp.error;
        console.warn(`FCM multicast token[${idx}] failed: ${err?.message} (${err?.code})`);
        if (
          err?.code === 'messaging/invalid-registration-token' ||
          err?.code === 'messaging/registration-token-not-registered'
        ) {
          await scrubInvalidFcmTokenEverywhere(validTokens[idx]);
        }
      }
    }
  }

  return { success: response.successCount > 0, response };
}

// ─── Topic Subscriptions ──────────────────────────────────────────────────────

async function subscribeToTopic(deviceTokens, topic) {
  if (!firebaseAdmin) throw new Error('Firebase Admin SDK not initialized');
  const validTokens = deviceTokens.filter(isValidFcmToken);
  if (!validTokens.length) {
    return { success: false, error: 'No valid FCM tokens provided', code: 'invalid-argument' };
  }
  try {
    const response = await firebaseAdmin.messaging().subscribeToTopic(validTokens, topic);
    return { success: true, response };
  } catch (error) {
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

async function unsubscribeFromTopic(deviceTokens, topic) {
  if (!firebaseAdmin) throw new Error('Firebase Admin SDK not initialized');
  const validTokens = deviceTokens.filter(isValidFcmToken);
  if (!validTokens.length) {
    return { success: false, error: 'No valid FCM tokens provided', code: 'invalid-argument' };
  }
  try {
    const response = await firebaseAdmin.messaging().unsubscribeFromTopic(validTokens, topic);
    return { success: true, response };
  } catch (error) {
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

// ─── Topic Push ───────────────────────────────────────────────────────────────

async function sendTopicPushNotification(topic, payload) {
  if (!firebaseAdmin) throw new Error('Firebase Admin SDK not initialized');
  if (!topic || typeof topic !== 'string' || !topic.length) {
    throw new Error('Topic must be a non-empty string');
  }

  const title       = payload.title  || 'HealthTrack Notification';
  const body        = payload.body   || payload.message || 'You have a new notification';
  const icon        = String(payload.icon        || payload.data?.icon        || 'ic_launcher');
  const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
  const type        = String(payload.notificationType || payload.data?.type   || 'system');
  const timestamp   = String(payload.timestamp   || payload.data?.timestamp   || new Date().toISOString());

  try {
    const message = {
      topic,
      notification: { title, body },
      data:    buildMessageData(payload, title, body, icon, clickAction, type, timestamp),
      android: buildAndroidConfig(icon, clickAction),
      apns:    buildApnsConfig(title, body),
    };
    const response = await firebaseAdmin.messaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    if (error.code === 'messaging/authentication-error') {
      console.error('Firebase auth error — check FIREBASE_* environment variables');
    }
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

// ─── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
  sendPushNotification,
  sendMulticastPushNotification,
  subscribeToTopic,
  unsubscribeFromTopic,
  sendTopicPushNotification,
  isValidFcmToken,
  normalizeFcmToken,
  validateFcmTokenWithFirebase,
};
