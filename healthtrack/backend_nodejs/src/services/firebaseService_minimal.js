const admin = require('firebase-admin');
const db = require("../config/db");
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
 * Send FCM push notification to a specific device with MINIMAL, VALID payload structure
 * @param {string} deviceToken - FCM device token
 * @param {Object} payload - Notification payload with both notification and data fields
 * @returns {Promise<Object>} - Result of the notification send operation
 */
async function sendPushNotification(deviceToken, payload) {
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin SDK not initialized');
  }

  // SPECIAL TEST MODE: Skip FCM validation and sending if in test mode
  const isTestMode = process.env.TEST_MODE === 'true';
  if (!isTestMode) {
    // Validate the FCM token before sending (only in non-test mode)
    if (!isValidFcmToken(deviceToken)) {
      console.warn('Invalid or missing FCM token, skipping notification send');
      return { 
        success: false, 
        error: 'Invalid or missing FCM token',
        code: 'invalid-argument'
      };
    }
  }

  try {
    // In TEST mode, simulate successful notification send
    if (isTestMode) {
      console.log('TEST MODE: Simulating successful FCM notification send');
      return { success: true, messageId: 'test_message_id_' + Date.now() };
    }

    // MINIMAL, VALID FCM message structure - only supported fields
    const message = {
      token: deviceToken,
      notification: {
        title: payload.title || 'HealthTrack Notification',
        body: payload.body || payload.message || 'You have a new notification',
      },
      data: {
        ...(payload.data || {}),
        title: String(payload.title || 'HealthTrack Notification'),
        body: String(payload.body || payload.message || 'You have a new notification'),
        timestamp: String(new Date().toISOString()),
        notificationType: String(payload.notificationType || 'system')
      },
      // Minimal Android configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'healthtrack_fcm_channel',
          sound: 'default',
          priority: 'high'
        }
      },
      // Minimal iOS configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: payload.title || 'HealthTrack Notification',
              body: payload.body || payload.message || 'You have a new notification'
            },
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    const response = await firebaseAdmin.messaging().send(message);
    console.log('Push notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending push notification:', error);
    
    // Handle specific FCM errors
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      console.warn('FCM token is invalid or not registered, notification not sent');
      
      // Auto-remove invalid token from DB
      try {
        await db.execute('UPDATE users SET fcm_token = NULL WHERE fcm_token = ?', [deviceToken]);
        if (deviceToken) console.log(`Automatically removed invalid FCM token from database: ${deviceToken.substring(0, 20)}...`);
      } catch (dbError) {
        console.error('Error handling invalid FCM token removal:', dbError);
      }

      return { 
        success: false, 
        error: 'FCM token is invalid or not registered',
        code: error.code
      };
    }
    
    // Handle other common FCM errors
    if (error.code === 'messaging/invalid-argument') {
      console.warn('Invalid argument in FCM message, notification not sent');
      return { 
        success: false, 
        error: 'Invalid argument in FCM message',
        code: error.code
      };
    }
    
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

  // Filter out invalid tokens
  const validTokens = deviceTokens.filter(token => isValidFcmToken(token));
  
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
    const message = {
      tokens: validTokens,
      notification: {
        title: payload.title || 'HealthTrack Notification',
        body: payload.body || payload.message || 'You have a new notification',
      },
      data: {
        ...(payload.data || {}),
        title: String(payload.title || 'HealthTrack Notification'),
        body: String(payload.body || payload.message || 'You have a new notification'),
        timestamp: String(new Date().toISOString()),
        notificationType: String(payload.notificationType || 'system')
      },
      // Minimal Android configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'healthtrack_fcm_channel',
          sound: 'default',
          priority: 'high'
        }
      },
      // Minimal iOS configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: payload.title || 'HealthTrack Notification',
              body: payload.body || payload.message || 'You have a new notification'
            },
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    const response = await firebaseAdmin.messaging().sendMulticast(message);
    console.log(`Multicast push notification sent. Success: ${response.successCount}, Failure: ${response.failureCount}`);
    
    // Log any failed tokens for debugging
    if (response.failureCount > 0) {
      for (let idx = 0; idx < response.responses.length; idx++) {
        const resp = response.responses[idx];
        if (!resp.success) {
          console.warn(`Failed to send to token ${idx}: ${resp.error.message} (${resp.error.code})`);
          if (resp.error.code === 'messaging/invalid-registration-token' || resp.error.code === 'messaging/registration-token-not-registered') {
            const failedToken = validTokens[idx];
            try {
              await db.execute('UPDATE users SET fcm_token = NULL WHERE fcm_token = ?', [failedToken]);
              if (failedToken) console.log(`Scrubbed invalid multicast FCM token from database: ${failedToken.substring(0, 20)}...`);
            } catch (dbError) {
              console.error('Error scrubbing invalid multicast FCM token:', dbError);
            }
          }
        }
      }
    }
    
    return { success: true, response };
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
    const message = {
      topic: topic,
      notification: {
        title: payload.title || 'HealthTrack Notification',
        body: payload.body || payload.message || 'You have a new notification',
      },
      data: {
        ...(payload.data || {}),
        title: String(payload.title || 'HealthTrack Notification'),
        body: String(payload.body || payload.message || 'You have a new notification'),
        timestamp: String(new Date().toISOString()),
        notificationType: String(payload.notificationType || 'system')
      },
      // Minimal Android configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'healthtrack_fcm_channel',
          sound: 'default',
          priority: 'high'
        }
      },
      // Minimal iOS configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: payload.title || 'HealthTrack Notification',
              body: payload.body || payload.message || 'You have a new notification'
            },
            sound: 'default',
            badge: 1
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
  isValidFcmToken
};
