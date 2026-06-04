/**
 * Authentication Middleware
 *
 * authenticateAdmin  — validates Bearer tokens stored in admin_sessions table (SHA-256 hash).
 * authenticateUser   — validates Bearer JWT tokens issued at user login.
 */

const crypto = require("crypto");
const jwt    = require("jsonwebtoken");
const db     = require("../config/db");
const { ADMIN_ROLES } = require("../constants/adminRoles");

// ─── Admin Auth ───────────────────────────────────────────────────────────────

async function authenticateAdmin(req, res, next) {
  try {
    const raw = req.headers.authorization || "";
    if (!raw.startsWith("Bearer ")) {
      return res.status(401).json({ success: false, message: "Authentication required." });
    }

    const token = raw.slice(7).trim();
    if (!token) {
      return res.status(401).json({ success: false, message: "Authentication required." });
    }

    const tokenHash = crypto.createHash("sha256").update(token, "utf8").digest("hex");

    const [rows] = await db.execute(
      `SELECT s.id AS session_id, s.admin_id, a.username, a.role
       FROM admin_sessions s
       INNER JOIN admins a ON a.id = s.admin_id
       WHERE s.token_hash = ?
       LIMIT 1`,
      [tokenHash]
    );

    if (!rows.length) {
      return res.status(401).json({ success: false, message: "Invalid or revoked session." });
    }

    const roleNormalized = String(rows[0].role || "").trim().toLowerCase();
    if (!ADMIN_ROLES.includes(roleNormalized)) {
      return res.status(403).json({ success: false, message: "Administrator role required." });
    }

    req.user = {
      id:        rows[0].admin_id,
      username:  rows[0].username,
      role:      rows[0].role,
      sessionId: rows[0].session_id,
    };

    await db.execute(
      "UPDATE admin_sessions SET last_active_at = CURRENT_TIMESTAMP WHERE id = ?",
      [req.user.sessionId]
    );

    next();
  } catch (error) {
    console.error("❌ authenticateAdmin:", error.message);
    return res.status(500).json({ success: false, message: "Authentication error." });
  }
}

// ─── User Auth ────────────────────────────────────────────────────────────────

/**
 * Validates a JWT token issued to a regular (patient/user) account.
 *
 * Token must be passed in the Authorization header as:
 *   Bearer <jwt>
 *
 * Sets req.user = { id, username, email, serviceType }
 */
function authenticateUser(req, res, next) {
  try {
    const raw = req.headers.authorization || "";
    if (!raw.startsWith("Bearer ")) {
      return res.status(401).json({ success: false, message: "Authentication required." });
    }

    const token = raw.slice(7).trim();
    if (!token) {
      return res.status(401).json({ success: false, message: "Authentication required." });
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error("❌ JWT_SECRET environment variable is not set.");
      return res.status(500).json({ success: false, message: "Server configuration error." });
    }

    const decoded = jwt.verify(token, secret);

    req.user = {
      id:          decoded.id          || decoded.userId || null,
      username:    decoded.username    || null,
      email:       decoded.email       || null,
      serviceType: decoded.serviceType || null,
    };

    next();
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({ success: false, message: "Session expired. Please log in again." });
    }
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ success: false, message: "Invalid authentication token." });
    }
    console.error("❌ authenticateUser:", error.message);
    return res.status(500).json({ success: false, message: "Authentication error." });
  }
}

// ─── Optional User Auth ───────────────────────────────────────────────────────

/**
 * Like authenticateUser but does NOT reject unauthenticated requests.
 * Sets req.user if a valid token is present, otherwise sets req.user = null.
 * Use on routes that serve both authenticated and unauthenticated clients.
 */
function optionalAuthUser(req, res, next) {
  const raw = req.headers.authorization || "";
  if (!raw.startsWith("Bearer ")) {
    req.user = null;
    return next();
  }

  const token = raw.slice(7).trim();
  if (!token) {
    req.user = null;
    return next();
  }

  try {
    const secret = process.env.JWT_SECRET;
    if (!secret) { req.user = null; return next(); }

    const decoded = jwt.verify(token, secret);
    req.user = {
      id:          decoded.id          || decoded.userId || null,
      username:    decoded.username    || null,
      email:       decoded.email       || null,
      serviceType: decoded.serviceType || null,
    };
  } catch {
    req.user = null;
  }
  next();
}

module.exports = {
  authenticateAdmin,
  authenticateUser,
  optionalAuthUser,
};
