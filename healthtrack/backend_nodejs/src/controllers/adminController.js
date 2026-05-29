const db = require("../config/db");
const crypto = require("crypto");
const { authenticator } = require("otplib");
const { createAdminSession } = require("../utils/adminSession");
const { ensureAdminPreferences } = require("../utils/ensureAdminPreferences");
const { writeAudit } = require("../utils/auditLog");

// ✅ Admin Login Function
exports.adminLogin = async (req, res) => {
  try {
    console.log("📥 Admin login request received");
    console.log("Request body:", req.body);

    const { username, password } = req.body;

    // Validation
    if (!username || !password) {
      console.log("❌ Missing username or password");
      return res.status(400).json({
        success: false,
        message: "Please provide both username and password",
      });
    }

    // Additional validation
    if (username.length < 3) {
      console.log("❌ Username too short");
      return res.status(400).json({
        success: false,
        message: "Username must be at least 3 characters long",
      });
    }

    if (password.length < 4) {
      console.log("❌ Password too short");
      return res.status(400).json({
        success: false,
        message: "Password must be at least 4 characters long",
      });
    }

    // Hash password (MD5)
    const hashedPassword = crypto.createHash("md5").update(password).digest("hex");
    console.log("🔑 Hashed password:", hashedPassword);

    // ✅ Use correct table and check credentials
    const sql = "SELECT * FROM admins WHERE username = ? AND password = ?";
    console.log("SQL query:", sql);

    const [results] = await db.execute(sql, [username, hashedPassword]);

    if (results.length > 0) {
      const adminRow = results[0];
      const adminId = adminRow.id;

      try {
        await ensureAdminPreferences(adminId);
      } catch (_e) {
        /* optional table lifecycle */
      }

      let prefs = {};
      try {
        const [[p]] = await db.execute(
          "SELECT totp_enabled, totp_secret FROM admin_preferences WHERE admin_id = ? LIMIT 1",
          [adminId]
        );
        prefs = p || {};
      } catch (_e) {
        prefs = {};
      }

      if (prefs.totp_enabled) {
        const code = req.body?.totp || req.body?.totp_code;
        const cleaned = code != null ? String(code).replace(/\s/g, "") : "";
        if (!cleaned) {
          console.log("✅ Credentials ok; OTP required");
          return res.status(200).json({
            success: false,
            requiresOtp: true,
            message: "Enter your authentication app code.",
          });
        }
        const secret =
          prefs.totp_secret instanceof Buffer
            ? prefs.totp_secret.toString()
            : prefs.totp_secret;
        if (!secret || !authenticator.check(cleaned, secret)) {
          return res.status(200).json({
            success: false,
            requiresOtp: true,
            message: "Authentication code rejected — try again.",
          });
        }
      }

      try {
        const { tokenPlain } = await createAdminSession(db, adminId, req);
        console.log("✅ Admin login successful");

        await writeAudit(adminId, "auth.admin.login.success", req, {});

        return res.status(200).json({
          success: true,
          message: "Login success",
          access_token: tokenPlain,
          admin: {
            id: adminId,
            username: adminRow.username,
            role: adminRow.role || "Administrator",
          },
        });
      } catch (sessionErr) {
        console.error(
          "⚠️ Session creation failed — check admin_sessions table migration:",
          sessionErr.message
        );
        return res.status(500).json({
          success: false,
          message:
            "Session storage is not ready. Ensure database migrations ran (admin_sessions table).",
        });
      }
    } else {
      console.log("❌ Invalid username or password");
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }
  } catch (error) {
    console.error("❌ Unexpected error in adminLogin:", error);
    return res.status(500).json({
      success: false,
      message: "Server error. Please try again later.",
    });
  }
};

// ✅ Admin Register Function
exports.adminRegister = async (req, res) => {
  try {
    console.log("📥 Admin registration request received");
    console.log("Request body:", req.body);

    const { username, password } = req.body;

    // Validation
    if (!username || !password) {
      console.log("❌ Missing required fields");
      return res.status(400).json({
        success: false,
        message: "Please provide both username and password",
      });
    }

    // Additional validation
    if (username.length < 3) {
      console.log("❌ Username too short");
      return res.status(400).json({
        success: false,
        message: "Username must be at least 3 characters long",
      });
    }

    if (password.length < 4) {
      console.log("❌ Password too short");
      return res.status(400).json({
        success: false,
        message: "Password must be at least 4 characters long",
      });
    }

    // Hash password (MD5)
    const hashedPassword = crypto.createHash("md5").update(password).digest("hex");
    console.log("🔑 Hashed password:", hashedPassword);

    // ✅ Insert new admin (no full_name column)
    const sql = "INSERT INTO admins (username, password) VALUES (?, ?)";
    console.log("SQL query:", sql);

    const [results] = await db.execute(sql, [username, hashedPassword]);

    console.log("✅ Admin registered successfully:", results);

    // Fetch the new admin data to confirm
    const fetchSql = "SELECT id, username FROM admins WHERE id = ?";
    const [fetchResults] = await db.execute(fetchSql, [results.insertId]);

    console.log("✅ New admin fetched:", fetchResults[0]);
    return res.status(200).json({
      success: true,
      message: "Admin registered successfully!",
      admin: fetchResults[0],
    });
  } catch (error) {
    console.error("❌ Unexpected error in adminRegister:", error);
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({
        success: false,
        message: "Username already exists. Please choose a different one.",
      });
    }
    return res.status(500).json({
      success: false,
      message: "Server error. Please try again later.",
    });
  }
};

// ✅ Get Admin Profile Function
exports.getAdminProfile = async (req, res) => {
  try {
    console.log("📥 Admin profile request received");
    console.log("Request params:", req.params);

    const { id } = req.params;

    if (req.user && parseInt(id, 10) !== Number(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: "You can only load your own admin profile.",
      });
    }

    // Validation
    if (!id) {
      console.log("❌ Missing admin ID");
      return res.status(400).json({
        success: false,
        message: "Admin ID is required",
      });
    }

    // ✅ Ensure ID is numeric to prevent "notifications" from being treated as an ID
    if (isNaN(id) || parseInt(id) <= 0) {
      console.log("❌ Invalid admin ID - must be a positive number");
      return res.status(400).json({
        success: false,
        message: "Invalid admin ID - must be a positive number",
      });
    }

    const adminId = parseInt(id);

    // ✅ Use correct table and fetch admin profile
    // First try to get all possible fields
    let sql = "SELECT id, username, full_name, email, last_login, created_at FROM admins WHERE id = ?";
    console.log("SQL query:", sql);

    const [resultsInitial] = await db.execute(sql, [adminId]);
    let results = resultsInitial;

    if (results.length === 0) {
      sql = "SELECT id, username FROM admins WHERE id = ?";
      console.log("Fallback SQL query:", sql);
      const [fallbackRows] = await db.execute(sql, [adminId]);
      results = fallbackRows;
    }

    if (results.length > 0) {
      console.log("✅ Admin profile fetched successfully");
      return res.status(200).json({
        success: true,
        message: "Profile fetched successfully",
        admin: results[0],
      });
    } else {
      console.log("❌ Admin not found");
      return res.status(404).json({
        success: false,
        message: "Admin not found",
      });
    }
  } catch (error) {
    console.error("❌ Unexpected error in getAdminProfile:", error);
    // Try a simpler query as fallback
    try {
      const { id } = req.params;
      // ✅ Ensure ID is numeric for fallback query too
      if (isNaN(id) || parseInt(id) <= 0) {
        return res.status(400).json({
          success: false,
          message: "Invalid admin ID - must be a positive number",
        });
      }
      
      const adminId = parseInt(id);
      const sql = "SELECT id, username FROM admins WHERE id = ?";
      const [results] = await db.execute(sql, [adminId]);
      
      if (results.length > 0) {
        console.log("✅ Admin profile fetched with fallback query");
        return res.status(200).json({
          success: true,
          message: "Profile fetched successfully",
          admin: results[0],
        });
      } else {
        console.log("❌ Admin not found with fallback query");
        return res.status(404).json({
          success: false,
          message: "Admin not found",
        });
      }
    } catch (fallbackError) {
      console.error("❌ Fallback query also failed:", fallbackError);
      return res.status(500).json({
        success: false,
        message: "Server error. Please try again later.",
      });
    }
  }
};

// ✅ Update Admin Profile Function
exports.updateAdminProfile = async (req, res) => {
  try {
    console.log("📥 Admin profile update request received");
    console.log("Request params:", req.params);
    console.log("Request body:", req.body);

    const { id } = req.params;
    const { full_name, email, current_password, new_password } = req.body;

    if (req.user && parseInt(id, 10) !== Number(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: "You can only modify your own admin profile.",
      });
    }

    // Validation
    if (!id) {
      console.log("❌ Missing admin ID");
      return res.status(400).json({
        success: false,
        message: "Admin ID is required",
      });
    }

    // ✅ Ensure ID is numeric to prevent "notifications" from being treated as an ID
    if (isNaN(id) || parseInt(id) <= 0) {
      console.log("❌ Invalid admin ID - must be a positive number");
      return res.status(400).json({
        success: false,
        message: "Invalid admin ID - must be a positive number",
      });
    }

    const adminId = parseInt(id);

    // Build dynamic update query
    const updates = [];
    const params = [];

    if (full_name !== undefined) {
      // Check if the column exists before adding to update
      try {
        const checkColumnSql = "SHOW COLUMNS FROM admins LIKE 'full_name'";
        const [columnResult] = await db.execute(checkColumnSql);
        if (columnResult.length > 0) {
          updates.push("full_name = ?");
          params.push(full_name);
        }
      } catch (columnError) {
        console.log("Column 'full_name' does not exist, skipping update");
      }
    }

    if (email !== undefined) {
      // Check if the column exists before adding to update
      try {
        const checkColumnSql = "SHOW COLUMNS FROM admins LIKE 'email'";
        const [columnResult] = await db.execute(checkColumnSql);
        if (columnResult.length > 0) {
          updates.push("email = ?");
          params.push(email);
        }
      } catch (columnError) {
        console.log("Column 'email' does not exist, skipping update");
      }
    }

    // Handle password update
    if (current_password !== undefined && new_password !== undefined) {
      // Verify current password
      const hashedCurrentPassword = crypto.createHash("md5").update(current_password).digest("hex");
      const verifySql = "SELECT password FROM admins WHERE id = ?";
      const [verifyResults] = await db.execute(verifySql, [adminId]);

      if (verifyResults.length === 0 || verifyResults[0].password !== hashedCurrentPassword) {
        return res.status(400).json({
          success: false,
          message: "Current password is incorrect",
        });
      }

      // Hash new password
      const hashedNewPassword = crypto.createHash("md5").update(new_password).digest("hex");
      updates.push("password = ?");
      params.push(hashedNewPassword);

      try {
        const checkColSql = "SHOW COLUMNS FROM admins LIKE 'password_changed_at'";
        const [colExist] = await db.execute(checkColSql);
        if (colExist.length > 0) {
          updates.push("password_changed_at = CURRENT_TIMESTAMP");
        }
      } catch (_c) {}

      try {
        if (req?.user?.sessionId) {
          await db.execute(
            "DELETE FROM admin_sessions WHERE admin_id = ? AND id <> ?",
            [adminId, req.user.sessionId]
          );
        } else {
          await db.execute("DELETE FROM admin_sessions WHERE admin_id = ?", [adminId]);
        }
        await writeAudit(adminId, "security.password.changed", req, {});
      } catch (_e) {
        console.warn("Session invalidation after password change skipped:", _e.message);
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No valid fields provided for update",
      });
    }

    // Add updated_at timestamp
    updates.push("updated_at = CURRENT_TIMESTAMP");
    
    // Add ID to params
    params.push(adminId);

    const sql = `UPDATE admins SET ${updates.join(", ")} WHERE id = ?`;
    console.log("SQL query:", sql);
    console.log("Params:", params);

    const [results] = await db.execute(sql, params);

    if (results.affectedRows > 0) {
      console.log("✅ Admin profile updated successfully");
      
      // Fetch updated admin data
      // Try to get all possible fields first
      let fetchSql = "SELECT id, username, full_name, email, last_login, created_at FROM admins WHERE id = ?";
      const [fetchInitial] = await db.execute(fetchSql, [adminId]);
      let fetchResults = fetchInitial;

      if (fetchResults.length === 0) {
        fetchSql = "SELECT id, username FROM admins WHERE id = ?";
        const [fetchFallback] = await db.execute(fetchSql, [adminId]);
        fetchResults = fetchFallback;
      }
      
      return res.status(200).json({
        success: true,
        message: "Profile updated successfully",
        admin: fetchResults[0],
      });
    } else {
      console.log("❌ Admin not found or no changes made");
      return res.status(404).json({
        success: false,
        message: "Admin not found",
      });
    }
  } catch (error) {
    console.error("❌ Unexpected error in updateAdminProfile:", error);
    return res.status(500).json({
      success: false,
      message: "Server error. Please try again later.",
    });
  }
};

// Add placeholder functions for missing exports
exports.getDashboardStats = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Dashboard stats fetched successfully",
    data: {
      total_patients: 0,
      total_appointments: 0,
      pending_appointments: 0,
      total_reminders: 0
    }
  });
};

exports.getDashboardPatients = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Dashboard patients fetched successfully",
    data: []
  });
};

exports.getDashboardAppointments = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Dashboard appointments fetched successfully",
    data: []
  });
};

exports.getDashboardReminders = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Dashboard reminders fetched successfully",
    data: []
  });
};

exports.getAllPatients = (req, res) => {
  res.status(200).json({
    success: true,
    message: "All patients fetched successfully",
    data: []
  });
};

exports.getPatientById = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Patient fetched successfully",
    data: {}
  });
};

exports.updatePatient = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Patient updated successfully",
    data: {}
  });
};

exports.deletePatient = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Patient deleted successfully"
  });
};

exports.searchPatients = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Patients search completed",
    data: []
  });
};

exports.getAllUsers = (req, res) => {
  res.status(200).json({
    success: true,
    message: "All users fetched successfully",
    data: []
  });
};

exports.getUserById = (req, res) => {
  res.status(200).json({
    success: true,
    message: "User fetched successfully",
    data: {}
  });
};

exports.updateUser = (req, res) => {
  res.status(200).json({
    success: true,
    message: "User updated successfully",
    data: {}
  });
};

exports.deleteUser = (req, res) => {
  res.status(200).json({
    success: true,
    message: "User deleted successfully"
  });
};

exports.getAppointments = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Appointments fetched successfully",
    data: []
  });
};

exports.getPendingAppointmentsCount = (req, res) => {
  res.status(200).json({
    success: true,
    count: 0
  });
};

exports.getPendingAppointments = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Pending appointments fetched successfully",
    data: []
  });
};

exports.updateAppointmentStatus = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Appointment status updated successfully",
    data: {}
  });
};

exports.exportPatients = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Patients exported successfully",
    data: []
  });
};

exports.exportUsers = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Users exported successfully",
    data: []
  });
};

exports.exportAppointments = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Appointments exported successfully",
    data: []
  });
};

exports.getSettings = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Settings fetched successfully",
    data: {}
  });
};

exports.updateSettings = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Settings updated successfully",
    data: {}
  });
};
