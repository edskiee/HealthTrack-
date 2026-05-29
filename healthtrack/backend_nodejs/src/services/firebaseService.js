const admin = require('firebase-admin');
const db = require("../config/db");
const { isUserPushEnabled, maskFcmTokenForLog, RETRYABLE_FCM_CODES } = require("./pushNotificationPolicy");
const serviceAccount = require('../../healthtrack-d20c2-4ada6cfc53f1.json');

// Initialize Firebase Admin SDK
let firebaseAdmin = null;

try {
  firebaseAdmin = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('Error initializing Firebase Admin SDK:', error);
}

/**
 * Validate if a string is a proper FCM token format (more permissive to accept real tokens)
 * @param {string} token - FCM token to validate
 * @returns {boolean} - Whether the token is valid
 */
function isValidFcmToken(token) {
  // FCM tokens are typically long strings (usually 100+ characters)
  // They should not be null, undefined, or empty
  if (!token || typeof token !== 'string') {
    console.log(`FCM token validation failed: Token is null, undefined, or not a string. Received: ${typeof token}`);
    return false;
  }
  
  // Additional validation: FCM tokens don't contain spaces
  if (token.includes(' ')) {
    console.log('FCM token validation failed: Token contains spaces');
    return false;
  }
  
  // FCM tokens are usually quite long (100+ characters)
  if (token.length < 50) {
    console.log(`FCM token validation failed: Token too short (${token.length} characters). Minimum required: 50 characters`);
    // Very short tokens are likely fake/test tokens
    return false;
  }
  
  // More permissive regex that accepts real FCM token characters
  // Real FCM tokens can contain: alphanumeric, colons, dashes, underscores, and periods
  const fcmTokenRegex = /^[a-zA-Z0-9:_\-.]+$/;
  const isValidFormat = fcmTokenRegex.test(token);
  
  if (!isValidFormat) {
    console.log('FCM token validation failed: Token contains invalid characters');
  }
  
  return isValidFormat;
}

/**
 * Normalize an incoming token string.
 * - trims whitespace
 * - strips surrounding quotes (common when clients accidentally JSON-stringify twice)
 */
function normalizeFcmToken(token) {
  if (typeof token !== 'string') return token;
  let t = token.trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    t = t.slice(1, -1).trim();
  }
  return t;
}

/**
 * Validate an FCM token with Firebase (dry-run send).
 * Catches tokens that match regex but are not real/registered tokens.
 *
 * @param {string} token
 * @returns {Promise<{success:boolean, code?:string, error?:string}>}
 */
async function scrubInvalidFcmTokenEverywhere(normalizedToken) {
  if (!normalizedToken) return;
  try {
    await db.execute('UPDATE users SET fcm_token = NULL WHERE fcm_token = ?', [normalizedToken]);
    await db.execute(
      'UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?',
      [normalizedToken]
    );
  } catch (dbError) {
    console.error('// DEBUG FCM scrub token DB error:', dbError.message || dbError);
  }
}

async function resolveUserIdForFcmToken(normalizedToken) {
  if (!normalizedToken) return null;
  try {
    const [fromUser] = await db.execute(
      'SELECT id FROM users WHERE fcm_token = ? LIMIT 1',
      [normalizedToken]
    );
    if (fromUser.length) return fromUser[0].id;
    const [fromDevices] = await db.execute(
      'SELECT user_id FROM user_device_tokens WHERE fcm_token = ? AND is_active = 1 LIMIT 1',
      [normalizedToken]
    );
    if (fromDevices.length) return fromDevices[0].user_id;
  } catch (e) {
    console.error('// DEBUG resolveUserIdForFcmToken failed:', e.message || e);
  }
  return null;
}

async function validateFcmTokenWithFirebase(token) {
  if (!firebaseAdmin) {
    return { success: false, code: 'firebase-not-initialized', error: 'Firebase Admin SDK not initialized' };
  }

  const normalized = normalizeFcmToken(token);
  if (!isValidFcmToken(normalized)) {
    return { success: false, code: 'invalid-format', error: 'Invalid FCM token format' };
  }

  // TEST MODE: skip Firebase validation
  if (process.env.TEST_MODE === 'true') {
    return { success: true };
  }

  try {
    await firebaseAdmin.messaging().send(
      {
        token: normalized,
        data: { healthtrack_validate: '1', ts: String(Date.now()) },
      },
      true
    );
    return { success: true };
  } catch (error) {
    return { success: false, code: error.code || 'unknown-error', error: error.message };
  }
}

/**
 * Send FCM push notification to a specific device with MINIMAL, VALID payload structure
 * @param {string} deviceToken - FCM device token
 * @param {Object} payload - Notification payload with both notification and data fields
 * @param {number|string|null} [forUserId] - User id for server-side push preference (avoids wrong-user token lookup)
 * @returns {Promise<Object>} - Result of the notification send operation
 */
async function sendPushNotification(deviceToken, payload, forUserId = null) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  const isTestMode = process.env.TEST_MODE === 'true';
  const normalizedToken = normalizeFcmToken(deviceToken);

  if (!isTestMode) {
    if (!isValidFcmToken(normalizedToken)) {
      console.warn('// DEBUG FCM skipped: invalid or missing token format');
      return {
        success: false,
        error: 'Invalid or missing FCM token',
        code: 'invalid-argument'
      };
    }
  }

  let effectiveUserId = forUserId != null ? Number.parseInt(String(forUserId), 10) : NaN;
  if (!Number.isFinite(effectiveUserId) || effectiveUserId <= 0) {
    effectiveUserId = await resolveUserIdForFcmToken(normalizedToken);
  }

  if (effectiveUserId && !(await isUserPushEnabled(effectiveUserId))) {
    console.log(
      `// DEBUG FCM skipped: push disabled for userId=${effectiveUserId} token=${maskFcmTokenForLog(normalizedToken)}`
    );
    return {
      success: false,
      error: 'Push notifications disabled by user',
      code: 'push-disabled-by-user'
    };
  }

  if (isTestMode) {
    console.log('// DEBUG TEST MODE: simulated FCM send');
    return { success: true, messageId: 'test_message_id_' + Date.now() };
  }

  const notificationTitle = payload.title || 'HealthTrack Notification';
  const notificationBody = payload.body || payload.message || 'You have a new notification';
  const normalizedIcon = String(payload.icon || payload.data?.icon || 'ic_launcher');
  const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
  const type = String(payload.notificationType || payload.data?.type || 'system');
  const timestamp = String(payload.timestamp || payload.data?.timestamp || new Date().toISOString());

  const message = {
    token: normalizedToken,
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    data: {
      ...(payload.data || {}),
      title: String(notificationTitle),
      body: String(notificationBody),
      timestamp,
      type,
      notificationType: type,
      icon: normalizedIcon,
      click_action: clickAction,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'healthtrack_fcm_channel',
        sound: 'default',
        priority: 'high',
        icon: normalizedIcon,
        clickAction,
      }
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          alert: {
            title: notificationTitle,
            body: notificationBody
          },
          sound: 'default',
          badge: 1,
          'content-available': 1,
        }
      }
    }
  };

  const bodyStr = String(notificationBody);
  console.log(
    `// DEBUG FCM payload outgoing userId=${effectiveUserId ?? 'unknown'} token=${maskFcmTokenForLog(normalizedToken)} title="${notificationTitle}" body="${bodyStr.slice(0, 80)}${bodyStr.length > 80 ? '…' : ''}"`
  );

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await firebaseAdmin.messaging().send(message);
      console.log(`// DEBUG FCM response OK messageId=${response} attempt=${attempt}`);
      return { success: true, messageId: response };
    } catch (error) {
      console.error(`// DEBUG FCM response ERR attempt=${attempt} code=${error.code} msg=${error.message}`);

      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        await scrubInvalidFcmTokenEverywhere(normalizedToken);
        return {
          success: false,
          error: 'FCM token is invalid or not registered',
          code: error.code
        };
      }

      if (error.code === 'messaging/invalid-argument') {
        return {
          success: false,
          error: 'Invalid argument in FCM message',
          code: error.code
        };
      }

      if (error.code === 'messaging/authentication-error') {
        console.error('Firebase authentication error - check service account credentials');
        return {
          success: false,
          error: 'Firebase authentication error',
          code: error.code
        };
      }

      const retryable = RETRYABLE_FCM_CODES.has(error.code);
      if (retryable && attempt < 3) {
        await new Promise((r) => setTimeout(r, 500 * attempt));
        continue;
      }

      return { success: false, error: error.message, code: error.code || 'unknown-error' };
    }
  }

  return { success: false, error: 'FCM send exhausted retries', code: 'unknown-error' };
}

/**
 * Send FCM push notification to multiple devices with MINIMAL, VALID payload
 * @param {Array<string>} deviceTokens - Array of FCM device tokens
 * @param {Object} payload - Notification payload
 * @returns {Promise<Object>} - Result of the notification send operation
 */
async function sendMulticastPushNotification(deviceTokens, payload) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) {
    throw new Error('Device tokens must be a non-empty array');
  }

  const validTokens = [...new Set(
    deviceTokens
      .map((t) => normalizeFcmToken(t))
      .filter((t) => isValidFcmToken(t))
  )];

  if (validTokens.length === 0) {
    console.warn('No valid FCM tokens provided, skipping multicast notification');
    return { 
      success: false, 
      error: 'No valid FCM tokens provided',
      code: 'invalid-argument'
    };
  }

  try {
    // MINIMAL, VALID FCM multicast message structure
    const notificationTitle = payload.title || 'HealthTrack Notification';
    const notificationBody = payload.body || payload.message || 'You have a new notification';
    const normalizedIcon = String(payload.icon || payload.data?.icon || 'ic_launcher');
    const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
    const type = String(payload.notificationType || payload.data?.type || 'system');
    const timestamp = String(payload.timestamp || payload.data?.timestamp || new Date().toISOString());
    const message = {
      tokens: validTokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        ...(payload.data || {}),
        title: String(notificationTitle),
        body: String(notificationBody),
        timestamp,
        type,
        notificationType: type,
        icon: normalizedIcon,
        click_action: clickAction,
      },
      // Minimal Android configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'healthtrack_fcm_channel',
          sound: 'default',
          priority: 'high',
          icon: normalizedIcon,
          clickAction,
        }
      },
      // Minimal iOS configuration
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: notificationTitle,
              body: notificationBody
            },
            sound: 'default',
            badge: 1,
            'content-available': 1,
          }
        }
      }
    };

    console.log(`// DEBUG FCM multicast tokens=${validTokens.length} first=${maskFcmTokenForLog(validTokens[0])}`);

    let response = null;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        response = await firebaseAdmin.messaging().sendEachForMulticast(message);
        break;
      } catch (error) {
        console.error(`// DEBUG FCM multicast error attempt=${attempt} code=${error.code} msg=${error.message}`);
        if (RETRYABLE_FCM_CODES.has(error.code) && attempt < 3) {
          await new Promise((r) => setTimeout(r, 500 * attempt));
          continue;
        }
        return { success: false, error: error.message, code: error.code || 'unknown-error' };
      }
    }

    if (!response) {
      return { success: false, error: 'Multicast send failed', code: 'unknown-error' };
    }

    console.log(`// DEBUG FCM multicast result success=${response.successCount} failure=${response.failureCount}`);

    if (response.failureCount > 0) {
      for (let idx = 0; idx < response.responses.length; idx += 1) {
        const resp = response.responses[idx];
        if (!resp.success) {
          const err = resp.error;
          console.warn(
            `// DEBUG FCM multicast token[${idx}] failed: ${err?.message || err} (${err?.code || 'no-code'}) token=${maskFcmTokenForLog(validTokens[idx])}`
          );
          if (err?.code === 'messaging/invalid-registration-token' ||
              err?.code === 'messaging/registration-token-not-registered') {
            await scrubInvalidFcmTokenEverywhere(validTokens[idx]);
          }
        }
      }
    }

    return { success: response.successCount > 0, response };
  } catch (error) {
    console.error('Error sending multicast push notification:', error);
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

/**
 * Subscribe devices to a topic
 * @param {Array<string>} deviceTokens - Array of FCM device tokens
 * @param {string} topic - Topic name to subscribe to
 * @returns {Promise<Object>} - Result of the subscription operation
 */
async function subscribeToTopic(deviceTokens, topic) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  // Filter out invalid tokens
  const validTokens = deviceTokens.filter(token => isValidFcmToken(token));
  
  if (validTokens.length === 0) {
    console.warn('No valid FCM tokens provided, skipping topic subscription');
    return { 
      success: false, 
      error: 'No valid FCM tokens provided',
      code: 'invalid-argument'
    };
  }

  try {
    const response = await firebaseAdmin.messaging().subscribeToTopic(validTokens, topic);
    console.log(`Subscribed devices to topic "${topic}". Success: ${response.successCount}, Failure: ${response.failureCount}`);
    
    // Log any failed tokens for debugging
    if (response.failureCount > 0) {
      response.errors.forEach((error, idx) => {
        console.warn(`Failed to subscribe token ${idx} to topic "${topic}": ${error.error.message}`);
      });
    }
    
    return { success: true, response };
  } catch (error) {
    console.error('Error subscribing to topic:', error);
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

/**
 * Unsubscribe devices from a topic
 * @param {Array<string>} deviceTokens - Array of FCM device tokens
 * @param {string} topic - Topic name to unsubscribe from
 * @returns {Promise<Object>} - Result of the unsubscription operation
 */
async function unsubscribeFromTopic(deviceTokens, topic) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  // Filter out invalid tokens
  const validTokens = deviceTokens.filter(token => isValidFcmToken(token));
  
  if (validTokens.length === 0) {
    console.warn('No valid FCM tokens provided, skipping topic unsubscription');
    return { 
      success: false, 
      error: 'No valid FCM tokens provided',
      code: 'invalid-argument'
    };
  }

  try {
    const response = await firebaseAdmin.messaging().unsubscribeFromTopic(validTokens, topic);
    console.log(`Unsubscribed devices from topic "${topic}". Success: ${response.successCount}, Failure: ${response.failureCount}`);
    
    // Log any failed tokens for debugging
    if (response.failureCount > 0) {
      response.errors.forEach((error, idx) => {
        console.warn(`Failed to unsubscribe token ${idx} from topic "${topic}": ${error.error.message}`);
      });
    }
    
    return { success: true, response };
  } catch (error) {
    console.error('Error unsubscribing from topic:', error);
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

/**
 * Send FCM push notification to a topic with MINIMAL, VALID payload
 * @param {string} topic - Topic name to send notification to
 * @param {Object} payload - Notification payload
 * @returns {Promise<Object>} - Result of the notification send operation
 */
async function sendTopicPushNotification(topic, payload) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  // Validate topic format
  if (!topic || typeof topic !== 'string' || topic.length === 0) {
    throw new Error('Topic must be a non-empty string');
  }

  try {
    // MINIMAL, VALID FCM topic message structure
    const notificationTitle = payload.title || 'HealthTrack Notification';
    const notificationBody = payload.body || payload.message || 'You have a new notification';
    const normalizedIcon = String(payload.icon || payload.data?.icon || 'ic_launcher');
    const clickAction = String(payload.click_action || payload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK');
    const type = String(payload.notificationType || payload.data?.type || 'system');
    const timestamp = String(payload.timestamp || payload.data?.timestamp || new Date().toISOString());
    const message = {
      topic: topic,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        ...(payload.data || {}),
        title: String(notificationTitle),
        body: String(notificationBody),
        timestamp,
        type,
        notificationType: type,
        icon: normalizedIcon,
        click_action: clickAction,
      },
      // Minimal Android configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'healthtrack_fcm_channel',
          sound: 'default',
          priority: 'high',
          icon: normalizedIcon,
          clickAction,
        }
      },
      // Minimal iOS configuration
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: notificationTitle,
              body: notificationBody
            },
            sound: 'default',
            badge: 1,
            'content-available': 1,
          }
        }
      }
    };

    const response = await firebaseAdmin.messaging().send(message);
    console.log('Topic push notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending topic push notification:', error);
    
    // Handle authentication errors
    if (error.code === 'messaging/authentication-error') {
      console.error('Firebase authentication error - check service account credentials');
      return { 
        success: false, 
        error: 'Firebase authentication error',
        code: error.code
      };
    }
    
    return { success: false, error: error.message, code: error.code || 'unknown-error' };
  }
}

module.exports = {
  sendPushNotification,
  sendMulticastPushNotification,
  subscribeToTopic,
  unsubscribeFromTopic,
  sendTopicPushNotification,
  isValidFcmToken,
  normalizeFcmToken,
  validateFcmTokenWithFirebase
};
