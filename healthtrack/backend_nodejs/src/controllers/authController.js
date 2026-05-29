const mysql = require("mysql2/promise");
const crypto = require("crypto");
const db = require("../config/db");
const { isValidFcmToken, normalizeFcmToken, validateFcmTokenWithFirebase, sendPushNotification } = require("../services/firebaseService");
const { createUserDeviceTokensTable } = require("../services/appointmentPushService");

// User registration function - Creates both user and patient records
const userRegister = async (req, res) => {
  const connection = await db.getConnection();
  
  try {
    const {
      // User account info
      username,
      password,
      email,
      serviceType,
      
      // Maternal Care specific info
      motherName,
      dob,
      education,
      occupation,
      status, // Civil status
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
      
      // Child/Patient info (for compatibility with existing system)
      childName,
      fatherName,
      placeOfBirth,
      birthWeight,
      birthHeight,
      sex,
      
      // Additional health info
      healthCenter,
      barangay,
      familyNumber,
      recordType,
      recordDescription
    } = req.body;

    // Validate required fields for maternal care based on civil status
    if (serviceType === 'maternal') {
      // Always required fields for maternal care
      // Note: We need to check for empty strings as well since frontend sends empty strings for unfilled fields
      if (!username || username.trim() === '' || 
          !password || password.trim() === '' || 
          !motherName || motherName.trim() === '' || 
          !dob || dob.trim() === '' || 
          !education || education.trim() === '' || 
          !occupation || occupation.trim() === '' || 
          !address || address.trim() === '' || 
          !contact || contact.trim() === '' || 
          age === undefined || age === null || age.toString().trim() === '') {
        return res.status(400).json({
          success: false,
          message: "Required maternal care fields are missing"
        });
      }
      
      // For non-single civil status, additional fields are required
      if (status !== "Single") {
        // Check if required fields are missing or empty (excluding null/undefined checks)
        if (!spouseName || spouseName.trim() === '' || 
            !spouseDob || spouseDob.trim() === '' || 
            !spouseEducation || spouseEducation.trim() === '' || 
            !spouseOccupation || spouseOccupation.trim() === '' || 
            monthlyIncome === undefined || monthlyIncome === null || monthlyIncome.toString().trim() === '' || 
            livingChildrenCount === undefined || livingChildrenCount === null || livingChildrenCount.toString().trim() === '' || 
            !birthPlan || birthPlan.trim() === '') {
          return res.status(400).json({
            success: false,
            message: "Required maternal care fields for selected civil status are missing"
          });
        }
        
        // Birth attendant is only required if "Home" is selected as birth plan
        if (birthPlan === "Home" && (!birthAttendant || birthAttendant.trim() === '')) {
          return res.status(400).json({
            success: false,
            message: "Birth attendant type is required when birth plan is Home"
          });
        }
      }
    } else {
      // Validate required fields for immunization (existing validation)
      if (!username || !password || !childName || !motherName || !dob || !sex) {
        return res.status(400).json({
          success: false,
          message: "Username, password, child name, mother name, date of birth, and sex are required"
        });
      }
    }

    // Set default service type if not provided
    const user_service_type = serviceType || 'immunization';

    await connection.beginTransaction();

    // Check if username already exists
    const checkUserQuery = "SELECT id FROM users WHERE username = ?";
    const [userResults] = await connection.execute(checkUserQuery, [username]);
    
    if (userResults.length > 0) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: "Username already exists. Please choose a different username."
      });
    }

    // Create user account first
    const userInsertQuery = `
      INSERT INTO users (
        username, email, password, full_name, phone, address, service_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `;

    const userEmail = email || `${username}@healthtrack.local`;
    const userFullName = motherName; // Parent's name as full name
    const userPhone = contact || '';
    const userAddress = address || '';

    const [userInsertResult] = await connection.execute(userInsertQuery, [
      username,
      userEmail,
      password, // In production, hash this password
      userFullName,
      userPhone,
      userAddress,
      user_service_type
    ]);

    const newUserId = userInsertResult.insertId;
    console.log(`✅ Created user account with ID: ${newUserId} and service type: ${user_service_type}`);

    // Create patient record linked to the user
    let patientInsertQuery = '';
    let patientValues = [];

    if (user_service_type === 'maternal') {
      // For maternal care, use maternal-specific fields
      patientInsertQuery = `
        INSERT INTO patients (
          user_id, mother_fullname, father_fullname, child_fullname, dob,
          place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
          record_type, record_description,
          family_serial_number, contact_number, spouse_name, living_children_count, 
          monthly_income, religion, city, province, age, education, occupation, 
          birth_attendant, facility_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      
      // Extract city and province from address if possible
      let city = '';
      let province = '';
      if (address && address.includes(',')) {
        const addressParts = address.split(',');
        city = addressParts.length > 1 ? addressParts[addressParts.length - 2].trim() : '';
        province = addressParts.length > 0 ? addressParts[addressParts.length - 1].trim() : '';
      }
      
      // Conditional fields based on civil status
      let spouseNameValue = '';
      let spouseDobValue = '';
      let spouseEducationValue = '';
      let spouseOccupationValue = '';
      let monthlyIncomeValue = 0;
      let livingChildrenCountValue = 0;
      let birthAttendantValue = '';
      
      // Only populate these fields if civil status is not "Single"
      if (status !== "Single") {
        spouseNameValue = spouseName || '';
        spouseDobValue = spouseDob || '';
        spouseEducationValue = spouseEducation || '';
        spouseOccupationValue = spouseOccupation || '';
        monthlyIncomeValue = parseFloat(monthlyIncome) || 0;
        livingChildrenCountValue = parseInt(livingChildrenCount) || 0;
        birthAttendantValue = birthAttendant || '';
      }
      
      patientValues = [
        newUserId, // Link patient to user
        motherName,
        fatherName || spouseNameValue, // Use spouse name as father name if provided
        childName || motherName, // Use mother's name as child name for maternal care
        dob,
        placeOfBirth || '',
        birthWeight || '',
        birthHeight || '',
        sex || 'Female', // Default to Female for maternal care
        address || '',
        'active', // Status value
        user_service_type, // Set patient service type to match user service type
        recordType || 'Maternal Care',
        recordDescription || 'Maternal care patient record',
        '', // family_serial_number
        contact || '',
        spouseNameValue,
        livingChildrenCountValue,
        monthlyIncomeValue,
        religion || '',
        city,
        province,
        parseInt(age) || 0,
        education || '',
        occupation || '',
        birthAttendantValue,
        facilityType || birthPlan || ''
      ];
    } else {
      // For immunization, use existing fields
      patientInsertQuery = `
        INSERT INTO patients (
          user_id, mother_fullname, father_fullname, child_fullname, dob,
          place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
          health_center, barangay, family_number, record_type, record_description
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)
      `;
      
      patientValues = [
        newUserId, // Link patient to user
        motherName,
        fatherName || '',
        childName,
        dob,
        placeOfBirth || '',
        birthWeight || '',
        birthHeight || '',
        sex,
        address || '',
        user_service_type, // Set patient service type to match user service type
        healthCenter || '',
        barangay || '',
        familyNumber || '',
        recordType || 'Immunization',
        recordDescription || 'Immunization patient record'
      ];
    }

    const [patientInsertResult] = await connection.execute(patientInsertQuery, patientValues);
    const newPatientId = patientInsertResult.insertId;
    console.log(`✅ Created patient record with ID: ${newPatientId}`);

    // Create initial health record for the patient
    const healthRecordSql = `
      INSERT INTO health_records (
        user_id, patient_id, record_type, title, description, date_recorded
      ) VALUES (?, ?, ?, ?, ?, CURDATE())
    `;

    const healthRecordValues = [
      newUserId,
      newPatientId,
      user_service_type === 'maternal' ? (recordType || 'Maternal Care') : (recordType || 'Immunization'),
      'Initial Health Record',
      recordDescription || (user_service_type === 'maternal' ? 'Maternal care patient record' : 'Immunization patient record')
    ];

    try {
      await connection.execute(healthRecordSql, healthRecordValues);
      console.log("✅ Health record created successfully for patient ID:", newPatientId);
      
      // Emit real-time update for dashboard refresh
      if (req.app.locals.io) {
        // Emit event for new patient registration
        req.app.locals.io.emit('patientRegistered', { 
          patient_id: newPatientId, 
          user_id: newUserId,
          service_type: user_service_type,
          timestamp: new Date().toISOString()
        });
        
        // Emit to specific admin rooms
        req.app.locals.io.to('admins').emit('newPatientRegistration', {
          patient_id: newPatientId,
          user_id: newUserId,
          service_type: user_service_type,
          mother_name: motherName,
          timestamp: new Date().toISOString()
        });
        
        // Also emit health record event
        req.app.locals.io.emit('healthRecordAdded', { 
          patient_id: newPatientId, 
          user_id: newUserId,
          timestamp: new Date().toISOString()
        });
        
        // Emit to specific admin rooms for health record
        req.app.locals.io.to('admins').emit('newHealthRecord', {
          patient_id: newPatientId,
          user_id: newUserId,
          timestamp: new Date().toISOString()
        });
      }
    } catch (healthErr) {
      console.error("❌ Database error creating health record:", healthErr);
      // Continue even if health record creation fails
    }

    // Commit transaction
    await connection.commit();

    // Send welcome notification to the new user
    await sendWelcomeNotification(newUserId, user_service_type, motherName);

    // Return success response with user and patient data
    res.status(200).json({
      success: true,
      message: "User registered successfully!",
      user: {
        id: newUserId,
        username: username,
        email: userEmail,
        full_name: userFullName,
        phone: userPhone,
        address: userAddress,
        service_type: user_service_type
      },
      patient: {
        id: newPatientId,
        user_id: newUserId,
        mother_fullname: motherName,
        father_fullname: fatherName || (status !== "Single" ? spouseName : '') || '',
        child_fullname: user_service_type === 'maternal' ? (childName || motherName) : childName,
        dob: dob,
        place_of_birth: placeOfBirth || '',
        birth_weight: birthWeight || '',
        birth_height: birthHeight || '',
        sex: user_service_type === 'maternal' ? (sex || 'Female') : sex,
        address: address || '',
        service_type: user_service_type,
        record_type: user_service_type === 'maternal' ? (recordType || 'Maternal Care') : (recordType || 'Immunization'),
        civil_status: status // Include civil status in response
      }
    });
  } catch (error) {
    await connection.rollback();
    console.error("❌ Error in userRegister:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred during registration"
    });
  } finally {
    connection.release();
  }
};

// Check if username exists
const checkUsername = async (req, res) => {
  try {
    const { username } = req.query;
    
    if (!username) {
      return res.status(400).json({
        success: false,
        message: "Username is required"
      });
    }
    
    const query = "SELECT id FROM users WHERE username = ?";
    const [results] = await db.execute(query, [username]);
    
    res.status(200).json({
      success: true,
      exists: results.length > 0
    });
  } catch (error) {
    console.error("❌ Error in checkUsername:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred while checking username"
    });
  }
};

// Check if email exists
const checkEmail = async (req, res) => {
  try {
    const { email } = req.query;
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required"
      });
    }
    
    const query = "SELECT id FROM users WHERE email = ?";
    const [results] = await db.execute(query, [email]);
    
    res.status(200).json({
      success: true,
      exists: results.length > 0
    });
  } catch (error) {
    console.error("❌ Error in checkEmail:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred while checking email"
    });
  }
};

// User login function
const userLogin = async (req, res) => {
  try {
    const { username, password } = req.body;
    
    // Validate input
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required"
      });
    }
    
    // Check if user exists and password matches
    // Note: In production, you should hash passwords
    const queryWithPush =
      "SELECT id, username, email, full_name, phone, address, service_type, COALESCE(push_notifications_enabled, 1) AS push_notifications_enabled FROM users WHERE username = ? AND password = ?";
    const queryLegacy =
      "SELECT id, username, email, full_name, phone, address, service_type FROM users WHERE username = ? AND password = ?";

    let results;
    try {
      [results] = await db.execute(queryWithPush, [username, password]);
    } catch (error) {
      if (error.code === "ER_BAD_FIELD_ERROR") {
        [results] = await db.execute(queryLegacy, [username, password]);
        if (results.length > 0) {
          results[0].push_notifications_enabled = 1;
        }
      } else {
        throw error;
      }
    }
    
    if (results.length > 0) {
      console.log(`✅ User ${username} logged in successfully`);
      
      // Update last login timestamp
      const updateQuery = "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?";
      await db.execute(updateQuery, [results[0].id]);
      
      // Get associated patient data
      const patientQuery = "SELECT * FROM patients WHERE user_id = ?";
      const [patientResults] = await db.execute(patientQuery, [results[0].id]);
      
      // Prepare response with both user and patient data
      const responseData = {
        success: true,
        message: "Login successful!",
        user: results[0]
      };
      
      // Add patient data if exists
      if (patientResults.length > 0) {
        responseData.patient = patientResults[0];
      }
      
      res.status(200).json(responseData);
    } else {
      console.log(`❌ Login failed for user ${username}`);
      res.status(401).json({
        success: false,
        message: "Invalid username or password"
      });
    }
  } catch (error) {
    console.error("❌ Error in userLogin:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred during login"
    });
  }
};

// Save FCM token for a user
const saveFcmToken = async (req, res) => {
  try {
    const { userId, fcmToken, deviceId, platform } = req.body;

    // Validate input
    if (!userId || !fcmToken) {
      return res.status(400).json({
        success: false,
        message: "User ID and FCM token are required"
      });
    }

    // Coerce/validate userId early (prevents accidental writes to wrong user)
    const parsedUserId = Number.parseInt(String(userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID"
      });
    }

    // Normalize token (trim + strip accidental surrounding quotes)
    const normalizedToken = normalizeFcmToken(fcmToken);

    // Validate FCM token format using the shared validation function
    if (!isValidFcmToken(normalizedToken)) {
      return res.status(400).json({
        success: false,
        message: "Invalid FCM token format"
      });
    }

    // Validate token with Firebase (dry-run) to prevent storing tokens that look valid but are rejected by FCM
    const validation = await validateFcmTokenWithFirebase(normalizedToken);
    if (!validation.success) {
      // If this user already has a bad token saved, scrub it (best-effort)
      try {
        await db.execute("UPDATE users SET fcm_token = NULL WHERE id = ?", [parsedUserId]);
      } catch (scrubErr) {
        // don't fail the request because scrubbing failed
        console.warn("⚠️ Failed to scrub token after failed Firebase validation:", scrubErr?.message || scrubErr);
      }

      return res.status(400).json({
        success: false,
        message: "FCM token rejected by Firebase",
        code: validation.code
      });
    }

    await createUserDeviceTokensTable();

    // Update user record with latest FCM token (backward compatibility)
    const query = "UPDATE users SET fcm_token = ? WHERE id = ?";
    const [result] = await db.execute(query, [normalizedToken, parsedUserId]);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    const resolvedDeviceId =
      (typeof deviceId === "string" && deviceId.trim()) ||
      `${(typeof platform === "string" ? platform : "unknown").toLowerCase()}_${normalizedToken.slice(-24)}`;

    await db.execute(
      `INSERT INTO user_device_tokens (user_id, device_id, fcm_token, platform, is_active)
       VALUES (?, ?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         fcm_token = VALUES(fcm_token),
         platform = VALUES(platform),
         is_active = 1,
         updated_at = CURRENT_TIMESTAMP`,
      [parsedUserId, resolvedDeviceId, normalizedToken, platform || null]
    );

    console.log(`✅ FCM token saved for user ${parsedUserId} (${resolvedDeviceId})`);
    
    res.status(200).json({
      success: true,
      message: "FCM token saved successfully"
    });
  } catch (error) {
    console.error("❌ Error saving FCM token:", error);
    return res.status(500).json({
      success: false,
      message: "An error occurred while saving FCM token"
    });
  }
};

// Check if user has valid FCM token
const checkUserFcmToken = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required"
      });
    }

    const parsedUserId = Number.parseInt(String(userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID"
      });
    }

    const [userRows] = await db.execute("SELECT id FROM users WHERE id = ?", [parsedUserId]);
    if (userRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    await createUserDeviceTokensTable();
    const query = `
      SELECT fcm_token FROM users WHERE id = ? AND fcm_token IS NOT NULL
      UNION
      SELECT fcm_token FROM user_device_tokens WHERE user_id = ? AND is_active = 1
    `;
    const [results] = await db.execute(query, [parsedUserId, parsedUserId]);

    if (results.length === 0) {
      return res.status(200).json({
        success: true,
        hasValidToken: false,
        message: "User does not have an FCM token",
        tokenCount: 0,
        validTokenCount: 0
      });
    }

    const validCount = results.filter((row) => isValidFcmToken(normalizeFcmToken(row.fcm_token))).length;
    const isValid = validCount > 0;

    res.status(200).json({
      success: true,
      hasValidToken: isValid,
      message: isValid ? "User has a valid FCM token" : "User has an invalid FCM token",
      tokenCount: results.length,
      validTokenCount: validCount
    });
  } catch (error) {
    console.error("❌ Error checking user FCM token:", error);
    return res.status(500).json({
      success: false,
      message: "An error occurred while checking user FCM token"
    });
  }
};

const getPushNotificationPreference = async (req, res) => {
  try {
    const { userId } = req.params;
    const parsedUserId = Number.parseInt(String(userId), 10);
    if (!Number.isFinite(parsedUserId) || parsedUserId <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }
    const [rows] = await db.execute(
      "SELECT COALESCE(push_notifications_enabled, 1) AS en FROM users WHERE id = ?",
      [parsedUserId]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "User not found" });
    }
    res.status(200).json({
      success: true,
      pushNotificationsEnabled: Number(rows[0].en) !== 0
    });
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      return res.status(200).json({
        success: true,
        pushNotificationsEnabled: true,
        migrationRequired: true
      });
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
      pushNotificationsEnabled === true ||
      pushNotificationsEnabled === 1 ||
      pushNotificationsEnabled === "1" ||
      pushNotificationsEnabled === "true";
    const [r] = await db.execute(
      "UPDATE users SET push_notifications_enabled = ? WHERE id = ?",
      [enabled ? 1 : 0, parsedUserId]
    );
    if (r.affectedRows === 0) {
      return res.status(404).json({ success: false, message: "User not found" });
    }
    res.status(200).json({
      success: true,
      message: "Preference updated",
      pushNotificationsEnabled: enabled
    });
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      return res.status(503).json({
        success: false,
        message: "Database migration required: add push_notifications_enabled to users table",
        code: "MIGRATION_REQUIRED"
      });
    }
    console.error("❌ updatePushNotificationPreference:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

// Remove invalid FCM token for a user
const removeInvalidFcmToken = async (req, res) => {
  try {
    const { userId } = req.body;

    // Validate input
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required"
      });
    }

    await createUserDeviceTokensTable();
    const checkQuery = "SELECT fcm_token FROM users WHERE id = ?";
    const [checkResults] = await db.execute(checkQuery, [userId]);

    if (checkResults.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    const user = checkResults[0];
    
    // If no token exists, nothing to remove
    if (!user.fcm_token) {
      return res.status(200).json({
        success: true,
        message: "User does not have an FCM token"
      });
    }

    // Validate current token
    const isValid = isValidFcmToken(user.fcm_token);
    
    // If token is valid, don't remove it
    if (isValid) {
      return res.status(200).json({
        success: true,
        message: "User has a valid FCM token, not removed",
        tokenLength: user.fcm_token.length
      });
    }

    // Remove invalid legacy token
    const updateQuery = "UPDATE users SET fcm_token = NULL WHERE id = ?";
    const [result] = await db.execute(updateQuery, [userId]);

    // Remove only invalid tokens from multi-device table
    const [deviceRows] = await db.execute(
      "SELECT id, fcm_token FROM user_device_tokens WHERE user_id = ? AND is_active = 1",
      [userId]
    );
    for (const row of deviceRows) {
      if (!isValidFcmToken(normalizeFcmToken(row.fcm_token))) {
        await db.execute(
          "UPDATE user_device_tokens SET is_active = 0 WHERE id = ?",
          [row.id]
        );
      }
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    console.log(`✅ Invalid FCM token removed for user ${userId}`);
    
    res.status(200).json({
      success: true,
      message: "Invalid FCM token removed successfully"
    });
  } catch (error) {
    console.error("❌ Error removing invalid FCM token:", error);
    return res.status(500).json({
      success: false,
      message: "An error occurred while removing invalid FCM token"
    });
  }
};

// Function to send welcome notification to newly registered users
async function sendWelcomeNotification(userId, serviceType, userName) {
  try {
    // Get user's FCM token
    const getUserQuery = "SELECT fcm_token FROM users WHERE id = ?";
    const [userResults] = await db.execute(getUserQuery, [userId]);

    if (userResults.length === 0 || !userResults[0].fcm_token) {
      console.log(`ℹ️ User ${userId} does not have an FCM token. Skipping welcome notification.`);
      return { success: true, message: "User does not have FCM token" };
    }

    const fcmToken = userResults[0].fcm_token;
    
    // SPECIAL TEST MODE: Skip FCM token validation if in test mode
    const isTestMode = process.env.TEST_MODE === 'true';
    if (!isTestMode && !isValidFcmToken(fcmToken)) {
      console.log(`⚠️ User ${userId} has an invalid FCM token. Skipping welcome notification.`);
      return { success: false, message: "Invalid FCM token" };
    }

    // Determine service type display name
    const serviceTypeName = serviceType === 'maternal' ? 'Maternal Care' : 'Immunization';
    
    // Create welcome message
    const welcomeMessage = `Welcome to HealthTrack, ${userName}! Your ${serviceTypeName} account has been successfully created.`;
    
    // Prepare notification payload
    const payload = {
      title: "Welcome to HealthTrack!",
      body: welcomeMessage,
      notificationType: "general", // Changed to a more appropriate type
      data: {
        type: "general", // Changed to match notification_type enum
        userId: userId.toString(),
        serviceType: serviceType,
        timestamp: new Date().toISOString()
      }
    };

    // Send the welcome notification
    const result = await sendPushNotification(fcmToken, payload, userId);
    
    if (result.success) {
      console.log(`✅ Welcome notification sent successfully to user ${userId}`);
      
      // Log the notification in the database with a valid notification_type
      const insertNotificationSql = `
        INSERT INTO appointment_notifications 
        (appointment_id, user_id, notification_type, message, is_read, created_at)
        VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
      `;
      
      await db.execute(insertNotificationSql, [
        null, // appointment_id (null for welcome notifications)
        userId,
        "new_appointment", // Changed to a valid enum value
        welcomeMessage
      ]);
      
      return { success: true, message: "Welcome notification sent successfully" };
    } else {
      console.log(`❌ Failed to send welcome notification to user ${userId}:`, result.error);
      return { success: false, message: "Failed to send welcome notification", error: result.error };
    }
  } catch (error) {
    console.error("❌ Error sending welcome notification:", error);
    return { success: false, message: "Error sending welcome notification", error: error.message };
  }
}

// Export all functions
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
  sendWelcomeNotification // Export the new function
};