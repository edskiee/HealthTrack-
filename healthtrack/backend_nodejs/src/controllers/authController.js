"use strict";

const jwt      = require("jsonwebtoken");
const bcrypt   = require("bcryptjs");
const db       = require("../config/db");
const {
  isValidFcmToken,
  normalizeFcmToken,
  validateFcmTokenWithFirebase,
  sendPushNotification,
} = require("../services/firebaseService");
const { createUserDeviceTokensTable } = require("../services/appointmentPushService");

// ─── Constants ────────────────────────────────────────────────────────────────
const BCRYPT_ROUNDS = 12;

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Hash a plain-text password with bcrypt.
 * @param {string} password
 * @returns {Promise<string>} bcrypt hash
 */
async function hashPassword(password) {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

/**
 * Compare a plain-text password against a stored hash.
 * Supports:
 *   - bcrypt hashes  (starts with $2a$, $2b$, $2y$)
 *   - legacy plaintext (migrated on next successful login)
 *
 * @param {string} plain     - Password from the request body
 * @param {string} stored    - Value stored in the DB
 * @returns {Promise<{match: boolean, needsRehash: boolean}>}
 */
async function verifyUserPassword(plain, stored) {
  const isBcrypt = /^\$2[aby]\$/.test(stored);
  if (isBcrypt) {
    const match = await bcrypt.compare(plain, stored);
    return { match, needsRehash: false };
  }
  // Legacy: plaintext stored — compare directly, flag for rehash
  const match = plain === stored;
  return { match, needsRehash: match }; // only rehash when credentials are correct
}

// ─── User Registration ────────────────────────────────────────────────────────

const userRegister = async (req, res) => {
  const connection = await db.getConnection();

  try {
    const {
      username,
      password,
      email,
      serviceType,
      motherName,
      dob,
      education,
      occupation,
      status,
      religion,
      address,
      contact,
      age,
      spouseName,
      spouseDob,
      spouseEducation,
      spouseOccupation,
      monthlyIncome,
      livingChildrenCount,
      birthPlan,
      birthAttendant,
      facilityType,
      childName,
      fatherName,
      placeOfBirth,
      birthWeight,
      birthHeight,
      sex,
      healthCenter,
      barangay,
      familyNumber,
      recordType,
      recordDescription,
    } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (serviceType === "maternal") {
      if (
        !username?.trim() || !password?.trim() || !motherName?.trim() ||
        !dob?.trim()      || !education?.trim() || !occupation?.trim() ||
        !address?.trim()  || !contact?.trim()   ||
        age === undefined || age === null || String(age).trim() === ""
      ) {
        return res.status(400).json({
          success: false,
          message: "Required maternal care fields are missing",
        });
      }
      if (status !== "Single") {
        if (
          !spouseName?.trim()     || !spouseDob?.trim()          ||
          !spouseEducation?.trim()|| !spouseOccupation?.trim()   ||
          monthlyIncome     === undefined || monthlyIncome     === null ||
          livingChildrenCount === undefined || livingChildrenCount === null ||
          !birthPlan?.trim()
        ) {
          return res.status(400).json({
            success: false,
            message: "Required maternal care fields for selected civil status are missing",
          });
        }
        if (birthPlan === "Home" && !birthAttendant?.trim()) {
          return res.status(400).json({
            success: false,
            message: "Birth attendant type is required when birth plan is Home",
          });
        }
      }
    } else {
      if (!username || !password || !childName || !motherName || !dob || !sex) {
        return res.status(400).json({
          success: false,
          message: "Username, password, child name, mother name, date of birth, and sex are required",
        });
      }
    }

    // ── Password strength ─────────────────────────────────────────────────────
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters long",
      });
    }

    const user_service_type = serviceType || "immunization";

    await connection.beginTransaction();

    // Check username uniqueness
    const [existingUser] = await connection.execute(
      "SELECT id FROM users WHERE username = ?",
      [username]
    );
    if (existingUser.length > 0) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: "Username already exists. Please choose a different username.",
      });
    }

    // ── Hash password with bcrypt ─────────────────────────────────────────────
    const hashedPassword = await hashPassword(password);

    const userEmail    = email     || `${username}@healthtrack.local`;
    const userFullName = motherName;
    const userPhone    = contact   || "";
    const userAddress  = address   || "";

    const [userInsertResult] = await connection.execute(
      `INSERT INTO users (username, email, password, full_name, phone, address, service_type)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [username, userEmail, hashedPassword, userFullName, userPhone, userAddress, user_service_type]
    );

    const newUserId = userInsertResult.insertId;
    console.log(`✅ Created user account ID=${newUserId} service_type=${user_service_type}`);

    // ── Patient record ────────────────────────────────────────────────────────
    let patientInsertQuery = "";
    let patientValues      = [];

    if (user_service_type === "maternal") {
      patientInsertQuery = `
        INSERT INTO patients (
          user_id, mother_fullname, father_fullname, child_fullname, dob,
          place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
          record_type, record_description,
          family_serial_number, contact_number, spouse_name, living_children_count,
          monthly_income, religion, city, province, age, education, occupation,
          birth_attendant, facility_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      let city = "", province = "";
      if (address?.includes(",")) {
        const parts = address.split(",");
        city     = parts.length > 1 ? parts[parts.length - 2].trim() : "";
        province = parts.length > 0 ? parts[parts.length - 1].trim() : "";
      }

      let spouseNameValue = "", spouseDobValue = "", spouseEducationValue = "";
      let spouseOccupationValue = "", monthlyIncomeValue = 0;
      let livingChildrenCountValue = 0, birthAttendantValue = "";

      if (status !== "Single") {
        spouseNameValue         = spouseName       || "";
        spouseDobValue          = spouseDob        || "";
        spouseEducationValue    = spouseEducation  || "";
        spouseOccupationValue   = spouseOccupation || "";
        monthlyIncomeValue      = parseFloat(monthlyIncome)     || 0;
        livingChildrenCountValue = parseInt(livingChildrenCount) || 0;
        birthAttendantValue     = birthAttendant   || "";
      }

      patientValues = [
        newUserId, motherName,
        fatherName || spouseNameValue,
        childName  || motherName,
        dob, placeOfBirth || "", birthWeight || "", birthHeight || "",
        sex || "Female", address || "", "active", user_service_type,
        recordType || "Maternal Care",
        recordDescription || "Maternal care patient record",
        "", contact || "", spouseNameValue, livingChildrenCountValue,
        monthlyIncomeValue, religion || "", city, province,
        parseInt(age) || 0, education || "", occupation || "",
        birthAttendantValue, facilityType || birthPlan || "",
      ];
    } else {
      patientInsertQuery = `
        INSERT INTO patients (
          user_id, mother_fullname, father_fullname, child_fullname, dob,
          place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
          health_center, barangay, family_number, record_type, record_description
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)
      `;
      patientValues = [
        newUserId, motherName, fatherName || "", childName, dob,
        placeOfBirth || "", birthWeight || "", birthHeight || "",
        sex, address || "", user_service_type,
        healthCenter || "", barangay || "", familyNumber || "",
        recordType || "Immunization",
        recordDescription || "Immunization patient record",
      ];
    }

    const [patientInsertResult] = await connection.execute(patientInsertQuery, patientValues);
    const newPatientId = patientInsertResult.insertId;
    console.log(`✅ Created patient record ID=${newPatientId}`);

    // ── Initial health record ─────────────────────────────────────────────────
    try {
      await connection.execute(
        `INSERT INTO health_records (user_id, patient_id, record_type, title, description, date_recorded)
         VALUES (?, ?, ?, ?, ?, CURDATE())`,
        [
          newUserId, newPatientId,
          user_service_type === "maternal" ? (recordType || "Maternal Care") : (recordType || "Immunization"),
          "Initial Health Record",
          recordDescription || (user_service_type === "maternal" ? "Maternal care patient record" : "Immunization patient record"),
        ]
      );

      const io = req.app.locals.io;
      if (io) {
        io.emit("patientRegistered", { patient_id: newPatientId, user_id: newUserId, service_type: user_service_type, timestamp: new Date().toISOString() });
        io.to("admins").emit("newPatientRegistration", { patient_id: newPatientId, user_id: newUserId, service_type: user_service_type, mother_name: motherName, timestamp: new Date().toISOString() });
        io.emit("healthRecordAdded", { patient_id: newPatientId, user_id: newUserId, timestamp: new Date().toISOString() });
        io.to("admins").emit("newHealthRecord", { patient_id: newPatientId, user_id: newUserId, timestamp: new Date().toISOString() });
      }
    } catch (healthErr) {
      console.error("❌ Health record creation error (non-fatal):", healthErr.message);
    }

    await connection.commit();

    // Send welcome push notification (non-blocking)
    sendWelcomeNotification(newUserId, user_service_type, motherName).catch(() => {});

    return res.status(201).json({
      success: true,
      message: "User registered successfully!",
      user: {
        id: newUserId, username, email: userEmail,
        full_name: userFullName, phone: userPhone,
        address: userAddress, service_type: user_service_type,
      },
      patient: {
        id: newPatientId, user_id: newUserId,
        mother_fullname: motherName,
        father_fullname: fatherName || (status !== "Single" ? spouseName : "") || "",
        child_fullname:  user_service_type === "maternal" ? (childName || motherName) : childName,
        dob, place_of_birth: placeOfBirth || "",
        birth_weight: birthWeight || "", birth_height: birthHeight || "",
        sex: user_service_type === "maternal" ? (sex || "Female") : sex,
        address: address || "", service_type: user_service_type,
        record_type: user_service_type === "maternal" ? (recordType || "Maternal Care") : (recordType || "Immunization"),
        civil_status: status,
      },
    });
  } catch (error) {
    await connection.rollback();
    console.error("❌ Error in userRegister:", error);
    return res.status(500).json({ success: false, message: "An error occurred during registration" });
  } finally {
    connection.release();
  }
};

// ─── Username / Email Availability ───────────────────────────────────────────

const checkUsername = async (req, res) => {
  try {
    const { username } = req.query;
    if (!username) {
      return res.status(400).json({ success: false, message: "Username is required" });
    }
    const [results] = await db.execute("SELECT id FROM users WHERE username = ?", [username]);
    return res.status(200).json({ success: true, exists: results.length > 0 });
  } catch (error) {
    console.error("❌ checkUsername:", error);
    return res.status(500).json({ success: false, message: "An error occurred while checking username" });
  }
};

const checkEmail = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required" });
    }
    const [results] = await db.execute("SELECT id FROM users WHERE email = ?", [email]);
    return res.status(200).json({ success: true, exists: results.length > 0 });
  } catch (error) {
    console.error("❌ checkEmail:", error);
    return res.status(500).json({ success: false, message: "An error occurred while checking email" });
  }
};

// ─── User Login ───────────────────────────────────────────────────────────────

const userLogin = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ success: false, message: "Username and password are required" });
    }

    // Fetch user by username only (never compare password in SQL)
    let userRow;
    try {
      const [rows] = await db.execute(
        `SELECT id, username, email, full_name, phone, address, service_type, password,
                COALESCE(push_notifications_enabled, 1) AS push_notifications_enabled
         FROM users WHERE username = ? LIMIT 1`,
        [username]
      );
      userRow = rows[0] || null;
    } catch (err) {
      if (err.code === "ER_BAD_FIELD_ERROR") {
        // push_notifications_enabled column doesn't exist yet — fall back
        const [rows] = await db.execute(
          "SELECT id, username, email, full_name, phone, address, service_type, password FROM users WHERE username = ? LIMIT 1",
          [username]
        );
        if (rows[0]) { rows[0].push_notifications_enabled = 1; }
        userRow = rows[0] || null;
      } else {
        throw err;
      }
    }

    if (!userRow) {
      // Use a constant-time response to prevent username enumeration
      await bcrypt.compare(password, "$2b$12$invalidhashpaddingtoconsistenttime000000000000000000000");
      return res.status(401).json({ success: false, message: "Invalid username or password" });
    }

    // ── Verify password (bcrypt or legacy plaintext) ───────────────────────
    const { match, needsRehash } = await verifyUserPassword(password, userRow.password);

    if (!match) {
      return res.status(401).json({ success: false, message: "Invalid username or password" });
    }

    // ── Transparent rehash: upgrade plaintext → bcrypt on next login ────────
    if (needsRehash) {
      try {
        const newHash = await hashPassword(password);
        await db.execute("UPDATE users SET password = ? WHERE id = ?", [newHash, userRow.id]);
        console.log(`🔐 Password rehashed to bcrypt for user ID=${userRow.id}`);
      } catch (rehashErr) {
        console.error("⚠️ Password rehash failed (non-fatal):", rehashErr.message);
      }
    }

    // Update last login timestamp
    await db.execute("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?", [userRow.id]);

    // Issue JWT
    const jwtSecret  = process.env.JWT_SECRET;
    const jwtExpires = process.env.JWT_EXPIRES_IN || "24h";
    let accessToken  = null;
    if (jwtSecret) {
      accessToken = jwt.sign(
        { id: userRow.id, username: userRow.username, email: userRow.email, serviceType: userRow.service_type },
        jwtSecret,
        { expiresIn: jwtExpires }
      );
    } else {
      console.warn("⚠️ JWT_SECRET not set — access_token not issued");
    }

    // Load associated patient record
    const [patientResults] = await db.execute("SELECT * FROM patients WHERE user_id = ? LIMIT 1", [userRow.id]);

    // Strip password from the response object
    const { password: _pw, ...safeUser } = userRow;

    const responseData = {
      success: true,
      message: "Login successful!",
      access_token: accessToken,
      user: safeUser,
    };
    if (patientResults.length > 0) {
      responseData.patient = patientResults[0];
    }

    console.log(`✅ User ${username} (ID=${userRow.id}) logged in`);
    return res.status(200).json(responseData);
  } catch (error) {
    console.error("❌ userLogin:", error);
    return res.status(500).json({ success: false, message: "An error occurred during login" });
  }
};

// ─── FCM Token Management ─────────────────────────────────────────────────────

const saveFcmToken = async (req, res) => {
  try {
    const { userId, fcmToken, deviceId, platform } = req.body;

    if (!userId || !fcmToken) {
      return res.status(400).json({ success: false, message: "User ID and FCM token are required" });
    }

    const parsedUserId = Number.parseInt(String(userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }

    const normalizedToken = normalizeFcmToken(fcmToken);
    if (!isValidFcmToken(normalizedToken)) {
      return res.status(400).json({ success: false, message: "Invalid FCM token format" });
    }

    const validation = await validateFcmTokenWithFirebase(normalizedToken);
    if (!validation.success) {
      try {
        await db.execute("UPDATE users SET fcm_token = NULL WHERE id = ?", [parsedUserId]);
      } catch (scrubErr) {
        console.warn("⚠️ Token scrub failed:", scrubErr?.message);
      }
      return res.status(400).json({ success: false, message: "FCM token rejected by Firebase", code: validation.code });
    }

    await createUserDeviceTokensTable();

    const [result] = await db.execute("UPDATE users SET fcm_token = ? WHERE id = ?", [normalizedToken, parsedUserId]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    const resolvedDeviceId =
      (typeof deviceId === "string" && deviceId.trim()) ||
      `${(typeof platform === "string" ? platform : "unknown").toLowerCase()}_${normalizedToken.slice(-24)}`;

    await db.execute(
      `INSERT INTO user_device_tokens (user_id, device_id, fcm_token, platform, is_active)
       VALUES (?, ?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         fcm_token  = VALUES(fcm_token),
         platform   = VALUES(platform),
         is_active  = 1,
         updated_at = CURRENT_TIMESTAMP`,
      [parsedUserId, resolvedDeviceId, normalizedToken, platform || null]
    );

    console.log(`✅ FCM token saved for user ${parsedUserId}`);
    return res.status(200).json({ success: true, message: "FCM token saved successfully" });
  } catch (error) {
    console.error("❌ saveFcmToken:", error);
    return res.status(500).json({ success: false, message: "An error occurred while saving FCM token" });
  }
};

const checkUserFcmToken = async (req, res) => {
  try {
    const parsedUserId = Number.parseInt(String(req.params.userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }

    const [userRows] = await db.execute("SELECT id FROM users WHERE id = ?", [parsedUserId]);
    if (!userRows.length) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    await createUserDeviceTokensTable();
    const [results] = await db.execute(
      `SELECT fcm_token FROM users WHERE id = ? AND fcm_token IS NOT NULL
       UNION
       SELECT fcm_token FROM user_device_tokens WHERE user_id = ? AND is_active = 1`,
      [parsedUserId, parsedUserId]
    );

    if (!results.length) {
      return res.status(200).json({ success: true, hasValidToken: false, message: "User does not have an FCM token", tokenCount: 0, validTokenCount: 0 });
    }

    const validCount = results.filter(r => isValidFcmToken(normalizeFcmToken(r.fcm_token))).length;
    return res.status(200).json({
      success: true,
      hasValidToken: validCount > 0,
      message: validCount > 0 ? "User has a valid FCM token" : "User has an invalid FCM token",
      tokenCount: results.length,
      validTokenCount: validCount,
    });
  } catch (error) {
    console.error("❌ checkUserFcmToken:", error);
    return res.status(500).json({ success: false, message: "An error occurred while checking user FCM token" });
  }
};

const getPushNotificationPreference = async (req, res) => {
  try {
    const parsedUserId = Number.parseInt(String(req.params.userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }
    const [rows] = await db.execute(
      "SELECT COALESCE(push_notifications_enabled, 1) AS en FROM users WHERE id = ?",
      [parsedUserId]
    );
    if (!rows.length) return res.status(404).json({ success: false, message: "User not found" });
    return res.status(200).json({ success: true, pushNotificationsEnabled: Number(rows[0].en) !== 0 });
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      return res.status(200).json({ success: true, pushNotificationsEnabled: true, migrationRequired: true });
    }
    console.error("❌ getPushNotificationPreference:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

const updatePushNotificationPreference = async (req, res) => {
  try {
    const { userId, pushNotificationsEnabled } = req.body;
    const parsedUserId = Number.parseInt(String(userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }
    const enabled =
      pushNotificationsEnabled === true  || pushNotificationsEnabled === 1 ||
      pushNotificationsEnabled === "1"   || pushNotificationsEnabled === "true";
    const [r] = await db.execute(
      "UPDATE users SET push_notifications_enabled = ? WHERE id = ?",
      [enabled ? 1 : 0, parsedUserId]
    );
    if (r.affectedRows === 0) return res.status(404).json({ success: false, message: "User not found" });
    return res.status(200).json({ success: true, message: "Preference updated", pushNotificationsEnabled: enabled });
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      return res.status(503).json({ success: false, message: "Database migration required: add push_notifications_enabled column", code: "MIGRATION_REQUIRED" });
    }
    console.error("❌ updatePushNotificationPreference:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

const removeInvalidFcmToken = async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: "User ID is required" });

    await createUserDeviceTokensTable();
    const [checkResults] = await db.execute("SELECT fcm_token FROM users WHERE id = ?", [userId]);
    if (!checkResults.length) return res.status(404).json({ success: false, message: "User not found" });

    const { fcm_token } = checkResults[0];
    if (!fcm_token) return res.status(200).json({ success: true, message: "User does not have an FCM token" });
    if (isValidFcmToken(fcm_token)) return res.status(200).json({ success: true, message: "User has a valid FCM token, not removed", tokenLength: fcm_token.length });

    const [result] = await db.execute("UPDATE users SET fcm_token = NULL WHERE id = ?", [userId]);
    const [deviceRows] = await db.execute("SELECT id, fcm_token FROM user_device_tokens WHERE user_id = ? AND is_active = 1", [userId]);
    for (const row of deviceRows) {
      if (!isValidFcmToken(normalizeFcmToken(row.fcm_token))) {
        await db.execute("UPDATE user_device_tokens SET is_active = 0 WHERE id = ?", [row.id]);
      }
    }

    if (result.affectedRows === 0) return res.status(404).json({ success: false, message: "User not found" });
    console.log(`✅ Invalid FCM token removed for user ${userId}`);
    return res.status(200).json({ success: true, message: "Invalid FCM token removed successfully" });
  } catch (error) {
    console.error("❌ removeInvalidFcmToken:", error);
    return res.status(500).json({ success: false, message: "An error occurred while removing invalid FCM token" });
  }
};

// ─── Welcome Notification ─────────────────────────────────────────────────────

async function sendWelcomeNotification(userId, serviceType, userName) {
  try {
    const serviceTypeName = serviceType === "maternal" ? "Maternal Care" : "Immunization";
    const welcomeMessage  = `Welcome to HealthTrack, ${userName}! Your ${serviceTypeName} account has been successfully created.`;

    // Always write to the notifications table so the welcome message appears in the
    // Notifications tab even if the user doesn't have an FCM token yet.
    try {
      await db.execute(
        `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
         VALUES (?, NULL, 'system', 'Welcome to HealthTrack!', ?, 0)`,
        [userId, welcomeMessage]
      );
      // Legacy table kept for backward compat
      await db.execute(
        `INSERT INTO appointment_notifications (appointment_id, user_id, notification_type, message, is_read, created_at)
         VALUES (NULL, ?, 'new_appointment', ?, 0, CURRENT_TIMESTAMP)`,
        [userId, welcomeMessage]
      );
      console.log(`✅ Welcome notification stored in DB for user ${userId}`);
    } catch (dbErr) {
      console.error("❌ Failed to store welcome notification in DB:", dbErr.message);
    }

    // Attempt FCM push — non-blocking, failure is acceptable since token may not exist yet.
    const [userResults] = await db.execute("SELECT fcm_token FROM users WHERE id = ?", [userId]);
    if (!userResults.length || !userResults[0].fcm_token) {
      return { success: true, message: "Welcome notification stored; no FCM token yet" };
    }

    const fcmToken   = userResults[0].fcm_token;
    const isTestMode = process.env.TEST_MODE === "true";
    if (!isTestMode && !isValidFcmToken(fcmToken)) {
      return { success: true, message: "Welcome notification stored; FCM token invalid" };
    }

    const result = await sendPushNotification(
      fcmToken,
      { title: "Welcome to HealthTrack!", body: welcomeMessage, notificationType: "system", data: { type: "system", userId: String(userId), serviceType, timestamp: new Date().toISOString() } },
      userId
    );

    if (!result.success) {
      console.warn(`⚠️ Welcome FCM push failed for user ${userId}: ${result.error}`);
    }

    return { success: true };
  } catch (error) {
    console.error("❌ sendWelcomeNotification:", error.message);
    return { success: false, error: error.message };
  }
}

// ─── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
  userRegister,
  checkUsername,
  checkEmail,
  userLogin,
  saveFcmToken,
  checkUserFcmToken,
  removeInvalidFcmToken,
  getPushNotificationPreference,
  updatePushNotificationPreference,
  sendWelcomeNotification,
};
