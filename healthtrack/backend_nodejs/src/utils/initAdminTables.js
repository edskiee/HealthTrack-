/**
 * Ensures admin-related tables exist on a single pooled connection when possible,
 * uses beginTransaction()/commit()/rollback() for transactional intent, and always
 * releases the connection from the pool (finally block).
 *
 * Note: InnoDB DDL (CREATE TABLE, ALTER TABLE, CREATE INDEX) implicit-commits open
 * transactions in MySQL. Rollback will not undo successful DDL steps; pairing DML-like
 * role normalization runs in the same flow and connection sequencing stays consistent.
 */

const pool = require("../config/db");

async function execSchema(conn, label, executor) {
  try {
    await executor();
    return true;
  } catch (e) {
    console.warn(`⚠️ Failed ${label}: ${e.message}`);
    return false;
  }
}

async function logAndExecSchema(conn, beforeMsg, label, executor) {
  console.log(beforeMsg);
  return execSchema(conn, label, executor);
}

async function columnExists(conn, tableName, columnName) {
  try {
    const [rows] = await conn.execute(
      `
      SELECT COUNT(*) AS cnt
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND COLUMN_NAME = ?
      `,
      [tableName, columnName]
    );
    return Number(rows[0].cnt) > 0;
  } catch (e) {
    console.warn(`⚠️ columnExists(${tableName}.${columnName}): ${e.message}`);
    return false;
  }
}

async function auditLogsMetadataType(conn) {
  try {
    const [rows] = await conn.execute(
      `
      SELECT DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'audit_logs'
        AND COLUMN_NAME = 'metadata'
      LIMIT 1
      `
    );
    if (!rows.length) return null;
    return String(rows[0].DATA_TYPE || "").toLowerCase();
  } catch {
    return null;
  }
}

async function indexExists(conn, tableName, indexName) {
  try {
    const [rows] = await conn.execute(
      `
      SELECT COUNT(*) AS cnt
      FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND INDEX_NAME = ?
      `,
      [tableName, indexName]
    );
    return Number(rows[0].cnt) > 0;
  } catch (e) {
    console.warn(`⚠️ indexExists(${tableName}.${indexName}): ${e.message}`);
    return false;
  }
}

/**
 * Upgrades legacy audit_logs: CREATE IF NOT EXISTS does not add columns to existing rows.
 * Preserves TEXT metadata columns; adds JSON metadata only when the column is missing.
 */
async function ensureAuditLogsColumns(conn) {
  const table = "audit_logs";

  if (!(await columnExists(conn, table, "ip_address"))) {
    await logAndExecSchema(
      conn,
      "🔧 Adding column audit_logs.ip_address...",
      "add audit_logs.ip_address",
      () =>
        conn.execute(`
          ALTER TABLE audit_logs
            ADD COLUMN ip_address VARCHAR(45) NULL DEFAULT NULL
        `)
    );
  }

  if (!(await columnExists(conn, table, "user_agent"))) {
    await logAndExecSchema(
      conn,
      "🔧 Adding column audit_logs.user_agent...",
      "add audit_logs.user_agent",
      () =>
        conn.execute(`
          ALTER TABLE audit_logs
            ADD COLUMN user_agent TEXT NULL
        `)
    );
  }

  const metaType = await auditLogsMetadataType(conn);
  const hasMetaCol = metaType !== null;
  const isTextLike =
    metaType === "tinytext" ||
    metaType === "text" ||
    metaType === "mediumtext" ||
    metaType === "longtext" ||
    metaType === "varchar" ||
    metaType === "char";

  if (!hasMetaCol) {
    console.log("🔧 Adding column audit_logs.metadata (JSON)...");
    try {
      await conn.execute(`
        ALTER TABLE audit_logs
          ADD COLUMN metadata JSON NULL
      `);
    } catch (e1) {
      console.warn(
        `⚠️ Failed to add audit_logs.metadata as JSON (${e1.message}); attempting TEXT fallback.`
      );
      await execSchema(
        conn,
        "add audit_logs.metadata (TEXT fallback)",
        () =>
          conn.execute(`
            ALTER TABLE audit_logs
              ADD COLUMN metadata TEXT NULL
          `)
      );
    }
  } else if (!isTextLike && metaType !== "json") {
    console.warn(
      `⚠️ audit_logs.metadata exists with unexpected type "${metaType}" — leaving unchanged.`
    );
  }
}

async function ensureAdminsRoleColumn(conn) {
  if (await columnExists(conn, "admins", "role")) {
    return;
  }
  await logAndExecSchema(
    conn,
    "🔧 Adding column admins.role...",
    "add admins.role",
    () =>
      conn.execute(`
        ALTER TABLE admins
          ADD COLUMN role VARCHAR(64) NOT NULL DEFAULT 'admin'
      `)
  );
}

async function normalizeEmptyAdminRoles(conn) {
  await logAndExecSchema(
    conn,
    "🔧 Normalizing empty admin roles...",
    "normalize admins.role",
    () =>
      conn.execute(`
        UPDATE admins
        SET role = 'admin'
        WHERE role IS NULL OR TRIM(role) = ''
      `)
  );
}

async function ensureAdminSessionsTokenHashIndex(conn) {
  if (!(await columnExists(conn, "admin_sessions", "token_hash"))) {
    console.warn(
      "⚠️ admin_sessions.token_hash missing — skipping idx_admin_sessions_token_hash"
    );
    return;
  }
  if (await indexExists(conn, "admin_sessions", "idx_admin_sessions_token_hash")) {
    return;
  }
  await logAndExecSchema(
    conn,
    "🔧 Creating index idx_admin_sessions_token_hash...",
    "create idx_admin_sessions_token_hash",
    () =>
      conn.execute(`
        CREATE INDEX idx_admin_sessions_token_hash ON admin_sessions (token_hash)
      `)
  );
}

/**
 * Deletes audit log rows older than `days`. Not invoked by init; callers can cron this.
 *
 * @param {number} [days=90]
 * @returns {Promise<{ affectedRows: number }>}
 */
async function cleanupOldAuditLogs(days = 90) {
  const d = Number(days);
  const safeDays = Number.isFinite(d) && d > 0 ? Math.floor(d) : 90;
  const conn = await pool.getConnection();
  try {
    const [result] = await conn.execute(
      `DELETE FROM audit_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)`,
      [safeDays]
    );
    return { affectedRows: result.affectedRows };
  } catch (e) {
    console.warn(`⚠️ cleanupOldAuditLogs failed: ${e.message}`);
    throw e;
  } finally {
    conn.release();
  }
}

/**
 * Ensures the two required service records (Immunization & Maternal Care) exist.
 * Uses INSERT IGNORE so it is safe to run on every startup.
 */
async function ensureServicesConfig(conn) {
  await logAndExecSchema(
    conn,
    "🔧 Ensuring services_config table exists...",
    "CREATE TABLE services_config",
    () =>
      conn.execute(`
        CREATE TABLE IF NOT EXISTS services_config (
          id                       INT          PRIMARY KEY AUTO_INCREMENT,
          service_name             VARCHAR(100) NOT NULL UNIQUE,
          service_description      TEXT,
          service_type             ENUM('immunization','maternal','dental','epi','checkup','general','other') NOT NULL DEFAULT 'general',
          description              TEXT,
          is_active                TINYINT(1)   NOT NULL DEFAULT 1,
          is_enabled               TINYINT(1)   NOT NULL DEFAULT 1,
          duration_minutes         INT          NOT NULL DEFAULT 30,
          required_fields          JSON,
          available_days           JSON,
          max_appointments_per_day INT          NOT NULL DEFAULT 50,
          created_at               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_service_type (service_type),
          INDEX idx_is_active    (is_active),
          INDEX idx_is_enabled   (is_enabled)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `)
  );

  // Add is_enabled column to existing tables that only have is_active
  if (!(await columnExists(conn, "services_config", "is_enabled"))) {
    await logAndExecSchema(
      conn,
      "🔧 Adding is_enabled column to services_config...",
      "add services_config.is_enabled",
      () =>
        conn.execute(`
          ALTER TABLE services_config
            ADD COLUMN is_enabled TINYINT(1) NOT NULL DEFAULT 1
        `)
    );
    // Sync is_enabled with is_active for any existing rows
    await conn.execute(
      `UPDATE services_config SET is_enabled = is_active`
    );
  }

  // ── Deduplicate services_config — keep lowest id per service_name ──────────
  // This fixes any duplicates that were inserted before the UNIQUE constraint
  // was enforced, or before this dedup step existed.
  console.log("🧹 Deduplicating services_config...");
  try {
    // Find all service names that have more than one row
    const [dupes] = await conn.execute(`
      SELECT service_name, MIN(id) AS keep_id
      FROM services_config
      GROUP BY service_name
      HAVING COUNT(*) > 1
    `);

    for (const { service_name, keep_id } of dupes) {
      await conn.execute(
        `DELETE FROM services_config WHERE service_name = ? AND id != ?`,
        [service_name, keep_id]
      );
      console.log(`  ✔ Kept id=${keep_id} for "${service_name}", removed duplicates`);
    }

    if (dupes.length === 0) {
      console.log("  ✔ No duplicates found");
    }
  } catch (dedupErr) {
    console.warn("⚠️  Dedup step failed (non-fatal):", dedupErr.message);
  }

  // ── Add UNIQUE constraint on service_name if it doesn't exist yet ─────────
  try {
    const [indexes] = await conn.execute(`
      SELECT INDEX_NAME FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'services_config'
        AND INDEX_NAME = 'uq_service_name'
    `);
    if (indexes.length === 0) {
      // Also try to drop the old non-unique index on service_name if present
      try {
        await conn.execute(`ALTER TABLE services_config DROP INDEX service_name`);
      } catch (_) { /* ignore if not present */ }
      await conn.execute(`ALTER TABLE services_config ADD UNIQUE INDEX uq_service_name (service_name)`);
      console.log("  ✔ Added UNIQUE constraint on services_config.service_name");
    }
  } catch (idxErr) {
    console.warn("⚠️  Could not add UNIQUE constraint (non-fatal):", idxErr.message);
  }

  // ── Keep only Immunization and Maternal Care active ───────────────────────
  try {
    await conn.execute(`
      UPDATE services_config
      SET is_active = 0, is_enabled = 0
      WHERE service_name NOT IN ('Immunization', 'Maternal Care')
    `);
    // Make sure the two required ones are active
    await conn.execute(`
      UPDATE services_config
      SET is_active = 1, is_enabled = 1
      WHERE service_name IN ('Immunization', 'Maternal Care')
    `);
  } catch (e) {
    console.warn("⚠️  Could not disable extra services:", e.message);
  }

  // Seed the two required services using INSERT IGNORE (idempotent)
  await logAndExecSchema(
    conn,
    "🌱 Seeding default services (Immunization & Maternal Care)...",
    "INSERT IGNORE services_config defaults",
    () =>
      conn.execute(`
        INSERT IGNORE INTO services_config
            (service_name, service_description, service_type, is_active, is_enabled,
             duration_minutes, required_fields, available_days, max_appointments_per_day)
        VALUES
        (
          'Immunization',
          'Child immunization and vaccination services',
          'immunization', 1, 1, 30,
          '["child_name", "vaccine_type", "date_of_birth", "parent_guardian"]',
          '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
          30
        ),
        (
          'Maternal Care',
          'Prenatal and postnatal care services for mothers',
          'maternal', 1, 1, 30,
          '["mother_name", "expected_delivery_date", "contact_number", "address"]',
          '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
          20
        )
      `)
  );

  console.log("✅ services_config seeded (Immunization & Maternal Care)");
}

async function initAdminTables() {
  let conn = null;
  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();

    await logAndExecSchema(
      conn,
      "🔧 Ensuring audit_logs table...",
      "CREATE TABLE audit_logs",
      () =>
        conn.execute(`
          CREATE TABLE IF NOT EXISTS audit_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            admin_id INT NULL,
            action VARCHAR(255) NOT NULL,
            description TEXT NULL,
            ip_address VARCHAR(45) NULL DEFAULT NULL,
            user_agent TEXT NULL,
            metadata JSON NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            KEY idx_audit_logs_admin_id (admin_id),
            KEY idx_audit_logs_created_at (created_at)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `)
    );
    console.log("✅ audit_logs table verified");

    await ensureAuditLogsColumns(conn);
    console.log("✅ audit_logs columns verified");

    await ensureAdminsRoleColumn(conn);
    await normalizeEmptyAdminRoles(conn);
    console.log("✅ admins table schema verified");

    await logAndExecSchema(
      conn,
      "🔧 Ensuring admin_preferences table...",
      "CREATE TABLE admin_preferences",
      () =>
        conn.execute(`
          CREATE TABLE IF NOT EXISTS admin_preferences (
            id INT AUTO_INCREMENT PRIMARY KEY,
            admin_id INT NOT NULL UNIQUE,
            theme_mode VARCHAR(16) NOT NULL DEFAULT 'system',
            phone VARCHAR(64) NULL DEFAULT NULL,
            avatar_url VARCHAR(512) NULL DEFAULT NULL,
            auto_logout_enabled TINYINT(1) NOT NULL DEFAULT 0,
            analytics_enabled TINYINT(1) NOT NULL DEFAULT 0,
            data_sharing_enabled TINYINT(1) NOT NULL DEFAULT 0,
            appointment_reminders_enabled TINYINT(1) NOT NULL DEFAULT 0,
            appointment_notify_email TINYINT(1) NOT NULL DEFAULT 0,
            appointment_notify_push TINYINT(1) NOT NULL DEFAULT 0,
            appointment_notify_sms TINYINT(1) NOT NULL DEFAULT 0,
            system_alerts_enabled TINYINT(1) NOT NULL DEFAULT 0,
            system_alert_email TINYINT(1) NOT NULL DEFAULT 0,
            system_alert_push TINYINT(1) NOT NULL DEFAULT 0,
            system_alert_sms TINYINT(1) NOT NULL DEFAULT 0,
            totp_enabled TINYINT(1) NOT NULL DEFAULT 0,
            totp_secret VARBINARY(512) NULL DEFAULT NULL,
            totp_pending_secret VARBINARY(512) NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `)
    );

    await logAndExecSchema(
      conn,
      "🔧 Ensuring admin_sessions table...",
      "CREATE TABLE admin_sessions",
      () =>
        conn.execute(`
          CREATE TABLE IF NOT EXISTS admin_sessions (
            id VARCHAR(36) NOT NULL PRIMARY KEY,
            admin_id INT NOT NULL,
            token_hash VARCHAR(64) NOT NULL,
            user_agent TEXT NULL,
            ip_address VARCHAR(45) NULL DEFAULT NULL,
            device_label VARCHAR(128) NULL DEFAULT NULL,
            browser_label VARCHAR(160) NULL DEFAULT NULL,
            last_active_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NULL DEFAULT NULL,
            KEY idx_admin_sessions_token_hash (token_hash),
            KEY idx_admin_sessions_admin_id (admin_id)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `)
    );

    await ensureAdminSessionsTokenHashIndex(conn);
    console.log("✅ admin_sessions index verified");

    await ensureServicesConfig(conn);

    await conn.commit();

    console.log("Admin tables initialized successfully");
  } catch (err) {
    console.error("❌ Admin schema initialization error:", err.message);
    if (conn) {
      try {
        await conn.rollback();
      } catch (rbErr) {
        console.warn("⚠️ Rollback skipped or failed:", rbErr.message);
      }
    }
  } finally {
    if (conn) {
      conn.release();
    }
  }
}

module.exports = initAdminTables;
module.exports.cleanupOldAuditLogs = cleanupOldAuditLogs;
module.exports.ensureServicesConfig = ensureServicesConfig;
