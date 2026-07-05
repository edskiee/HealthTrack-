/**
 * HealthTrack API — Production Entry Point
 * Last updated: 2026-07-05 — reports UI + export fixes deployed
 *
 * Render deployment:
 *   Build:  npm install
 *   Start:  npm start   (node src/server.js)
 *   Port:   process.env.PORT  (Render injects this automatically)
 *   Bind:   0.0.0.0
 */

"use strict";

require("dotenv").config();

const express      = require("express");
const cors         = require("cors");
const helmet       = require("helmet");
const morgan       = require("morgan");
const http         = require("http");
const path         = require("path");
const rateLimit    = require("express-rate-limit");
const socketIo     = require("socket.io");

// ─── Route Imports ────────────────────────────────────────────────────────────
const adminRoutes               = require("./routes/admin");
const dashboardRoutes           = require("./routes/dashboard");
const patientsRoutes            = require("./routes/patients");
const authRoutes                = require("./routes/auth");
const healthRecordsRoutes       = require("./routes/healthRecords");
const appointmentsRoutes        = require("./routes/appointments");
const appointmentSlotsRoutes    = require("./routes/appointmentSlots");
const serviceConfigRoutes       = require("./routes/serviceConfig");
const notificationsRoutes       = require("./routes/notifications");
const healthTipsRoutes          = require("./routes/healthTips");
const remindersRoutes           = require("./routes/reminders");
const fcmNotificationsRoutes    = require("./routes/fcmNotifications");
const appointmentRemindersRoutes = require("./routes/appointmentReminders");
const systemSettingsRoutes      = require("./routes/systemSettings");
const referralsRoutes           = require("./routes/referrals");
const testNotificationsRoutes   = require("./routes/testNotifications");
const vaccineRoutes             = require("./routes/vaccines");
const childrenRoutes            = require("./routes/children");

// ─── Service / Setup Imports ──────────────────────────────────────────────────
const dbPool                = require("./config/db");
const initAdminTables       = require("./utils/initAdminTables");
const { createScheduledNotificationsTable, sendDueNotifications } = require("./services/scheduledNotificationService");
const { checkAndSendDueReminders }   = require("./services/appointmentReminderService");
const { createUserDeviceTokensTable } = require("./services/appointmentPushService");
const { createAppointmentRemindersTable } = require("./setup/appointmentReminderSetup");
const { startNotificationScheduler }  = require("./services/notificationScheduler");
const { migrateNotificationsTable, migrateAppointmentSlotsCapacity } = require("./setup/migrateNotificationsTable");
const { setupVaccineTables } = require("./setup/vaccineTableSetup");
const { migrateDobVerification } = require("./setup/migrateDobVerification");
const { migrateChildSortOrder } = require("./setup/migrateChildSortOrder");
const { backfillVaccineRecords } = require("./setup/backfillVaccineRecords");
const { migrateVaccineAppointmentLink } = require("./setup/migrateVaccineAppointmentLink");

/**
 * Update reminder system_settings to include same-day reminders (days_before=0).
 * Runs once at startup — safe to run multiple times.
 */
async function migrateReminderSettings() {
  try {
    const updates = [
      { key: 'reminder_days_before', value: '[2, 1, 0]' },
      { key: 'reminder_times',       value: '["08:00", "17:00"]' },
      { key: 'reminders_per_day',    value: '2' },
    ];
    for (const { key, value } of updates) {
      const [rows] = await dbPool.execute(
        'SELECT setting_value FROM system_settings WHERE setting_key = ?', [key]
      );
      if (rows.length > 0 && rows[0].setting_value !== value) {
        await dbPool.execute(
          'UPDATE system_settings SET setting_value = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?',
          [value, key]
        );
        console.log(`✅ system_settings updated: ${key} = ${value}`);
      }
    }
  } catch (err) {
    // system_settings table may not exist yet — not fatal
    console.warn('⚠️ migrateReminderSettings (non-fatal):', err.message);
  }
}

// ─── App Setup ────────────────────────────────────────────────────────────────
const app    = express();
const server = http.createServer(app);
const PORT   = process.env.PORT || 3000;

// Trust Render's proxy (required for correct req.ip / rate-limit behaviour)
app.set("trust proxy", 1);

// ─── Security Headers ─────────────────────────────────────────────────────────
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }, // allow /uploads to be served cross-origin
}));

// ─── CORS ─────────────────────────────────────────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map(o => o.trim()).filter(Boolean)
  : [];

const corsOptions = {
  origin: (origin, callback) => {
    // Allow server-to-server calls (no origin) and explicitly listed origins
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`CORS: origin ${origin} not allowed`));
  },
  credentials: true,
  allowedHeaders: ["Content-Type", "Accept", "Authorization"],
};

app.use(cors(corsOptions));
app.options("*", cors(corsOptions)); // preflight

// ─── Request Logging ──────────────────────────────────────────────────────────
const morganFormat = process.env.NODE_ENV === "production" ? "combined" : "dev";
app.use(morgan(morganFormat));

// ─── Body Parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// ─── Static Files ─────────────────────────────────────────────────────────────
// NOTE: On Render's ephemeral filesystem, uploaded files are lost on redeploy.
// Migrate avatar uploads to Cloudinary or S3 before going to production.
app.use("/uploads", express.static(path.join(__dirname, "../public")));

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const authLimiter = rateLimit({
  windowMs:       15 * 60 * 1000, // 15 minutes
  max:            20,              // max 20 auth attempts per window per IP
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, message: "Too many requests. Please try again later." },
});

const generalLimiter = rateLimit({
  windowMs:       15 * 60 * 1000,
  max:            300,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, message: "Too many requests. Please try again later." },
});

// Apply strict limiter to authentication endpoints
app.use("/auth/login",      authLimiter);
app.use("/auth/register",   authLimiter);
app.use("/admin/login",     authLimiter);
app.use("/admin/register",  authLimiter);

// General limiter for all other routes
app.use(generalLimiter);

// ─── Socket.IO ────────────────────────────────────────────────────────────────
const io = socketIo(server, {
  cors: corsOptions,
});

app.locals.io               = io;
app.locals.serverHealthLabel = "Operational";

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use("/admin",                adminRoutes);
app.use("/dashboard",            dashboardRoutes);
app.use("/patients",             patientsRoutes);
app.use("/auth",                 authRoutes);
app.use("/health-records",       healthRecordsRoutes);
app.use("/appointments",         appointmentsRoutes);
app.use("/appointment-slots",    appointmentSlotsRoutes);
app.use("/service-config",       serviceConfigRoutes);
app.use("/notifications",        notificationsRoutes);
app.use("/health-tips",          healthTipsRoutes);
app.use("/reminders",            remindersRoutes);
app.use("/fcm-notifications",    fcmNotificationsRoutes);
app.use("/appointment-reminders", appointmentRemindersRoutes);
app.use("/system-settings",      systemSettingsRoutes);
app.use("/referrals",            referralsRoutes);
app.use("/vaccines",             vaccineRoutes);
app.use("/children",             childrenRoutes);
app.use("/test",                 testNotificationsRoutes); // disabled in production

// ─── Health Check Endpoints ───────────────────────────────────────────────────
app.get("/", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "HealthTrack API is running",
    timestamp: new Date().toISOString(),
  });
});

const pkgManifest = (() => {
  try { return require(path.join(__dirname, "../package.json")); }
  catch { return { version: "1.0.0" }; }
})();

let previousHealthLabel;

async function probeServerHealth(ioInstance) {
  let ok = true;
  try {
    await dbPool.query("SELECT 1");
  } catch {
    ok = false;
  }

  const label = ok ? "Operational" : "Degraded";
  app.locals.serverHealthLabel = label;

  const changed = previousHealthLabel !== null &&
                  previousHealthLabel !== undefined &&
                  previousHealthLabel !== label;
  previousHealthLabel = label;

  if (!ioInstance) return;

  ioInstance.emit("serverHealthChanged", { status: label, at: Date.now() });

  if (changed) {
    ioInstance.to("admins").emit("systemAlert", {
      severity: ok ? "recover" : "critical",
      message:  ok
        ? "All platform checks passed again."
        : "Database heartbeat failed — platform may be unavailable.",
      at: Date.now(),
    });
  }
}

(async () => { await probeServerHealth(null); })();
setInterval(() => probeServerHealth(io), 60_000).unref?.();

app.get("/health", (_req, res) => {
  const ok = app.locals.serverHealthLabel === "Operational";
  res.status(ok ? 200 : 503).json({
    success:   ok,
    message:   ok ? "Server is healthy" : "Server is degraded",
    timestamp: new Date().toISOString(),
    uptime:    process.uptime(),
    version:   pkgManifest.version || "1.0.0",
    build:     process.env.BUILD_NUMBER || "local",
  });
});

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ success: false, message: "Route not found." });
});

// ─── Global Error Handler ─────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error("❌ Unhandled error:", err.message || err);
  res.status(500).json({ success: false, message: "Internal server error." });
});

// ─── Socket.IO Events ─────────────────────────────────────────────────────────
io.on("connection", (socket) => {
  console.log(`📱 Client connected: ${socket.id}`);

  socket.on("joinUserRoom", (userId) => {
    socket.join(`user_${userId}`);
  });

  socket.on("leaveUserRoom", (userId) => {
    socket.leave(`user_${userId}`);
  });

  socket.on("joinAdminsRoom", () => {
    socket.join("admins");
    socket.emit("serverHealthChanged", {
      status:    app.locals.serverHealthLabel || "Operational",
      at:        Date.now(),
      immediate: true,
    });
  });

  socket.on("joinAdminRoom", (adminId) => {
    if (adminId == null) return;
    socket.join(`admin_${String(adminId)}`);
  });

  socket.on("leaveAdminsRoom", () => {
    socket.leave("admins");
  });

  socket.on("disconnect", () => {
    console.log(`📱 Client disconnected: ${socket.id}`);
  });
});

// ─── Scheduled Notifications Initializer ─────────────────────────────────────
async function initializeScheduledNotifications() {
  try {
    console.log("🔧 Setting up appointment reminders system...");
    await createAppointmentRemindersTable();
    await createScheduledNotificationsTable();
    await createUserDeviceTokensTable();

    console.log("🚀 Starting enhanced notification scheduler...");
    // Pass the Socket.IO instance so the missed-appointment sweep can emit
    // real-time notifications to connected patients.
    const schedulerResult = await startNotificationScheduler(io);

    if (schedulerResult.success) {
      console.log("✅ Enhanced notification scheduler started successfully");
    } else {
      console.warn("⚠️ Falling back to manual intervals:", schedulerResult.message);

      setInterval(async () => {
        try { await sendDueNotifications(); }
        catch (error) { console.error("Scheduled notifications error:", error); }
      }, 60_000);

      setInterval(async () => {
        try { await checkAndSendDueReminders(); }
        catch (error) { console.error("Appointment reminders error:", error); }
      }, 60_000);

      // Fallback missed-appointment sweep every 5 minutes
      const { markMissedAppointments } = require("./services/missedAppointmentService");
      setInterval(async () => {
        try { await markMissedAppointments(io); }
        catch (error) { console.error("Missed appointment sweep error:", error); }
      }, 5 * 60_000);
    }

    console.log("✅ Scheduled notifications system initialized");
  } catch (error) {
    console.error("❌ Error initializing scheduled notifications:", error);
  }
}

/**
 * Seed clinic_name and clinic_address into system_settings if not yet present.
 * These are used by the Flutter PDF vaccine card generator.
 */
async function seedClinicSettings() {
  try {
    const seeds = [
      {
        key: 'clinic_name',
        value: 'HealthTrack Health Center',
        type: 'string',
        desc: 'Clinic or health facility name shown on the vaccine card PDF',
      },
      {
        key: 'clinic_address',
        value: 'Pagadian City, Zamboanga del Sur',
        type: 'string',
        desc: 'Clinic address shown on the vaccine card PDF',
      },
    ];
    for (const s of seeds) {
      const [rows] = await dbPool.execute(
        'SELECT id FROM system_settings WHERE setting_key = ?', [s.key]
      );
      if (rows.length === 0) {
        await dbPool.execute(
          `INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_active)
           VALUES (?, ?, ?, ?, 1)`,
          [s.key, s.value, s.type, s.desc]
        );
        console.log(`✅ system_settings seeded: ${s.key}`);
      }
    }
  } catch (err) {
    console.warn('⚠️ seedClinicSettings (non-fatal):', err.message);
  }
}


// ── Per-migration timeout (ms) ─────────────────────────────────────────────
// Render's port-scan window is 60 s total. We budget 10 s per migration so
// all migrations combined fit well inside that window. If any individual
// migration times out its DDL is deferred to the next restart — the column
// will simply be missing until then, which is fine for optional columns.
const MIGRATION_TIMEOUT_MS = 10_000;

/**
 * runMigration — runs `fn` with a timeout. Never throws; always resolves.
 * Logs a warning if the migration exceeds MIGRATION_TIMEOUT_MS.
 */
async function runMigration(name, fn) {
  try {
    await Promise.race([
      fn(),
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error(`startup migration "${name}" timed out after ${MIGRATION_TIMEOUT_MS}ms`)),
          MIGRATION_TIMEOUT_MS
        )
      ),
    ]);
  } catch (err) {
    // All migration errors are non-fatal — log and continue to server.listen()
    console.warn(`⚠️  ${err.message || err} — server will continue`);
  }
}

async function bootstrap() {
  // ── Firebase credential check ────────────────────────────────────────────────
  const fbProjectId   = process.env.FIREBASE_PROJECT_ID;
  const fbPrivateKey  = process.env.FIREBASE_PRIVATE_KEY;
  const fbClientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const fbPlaceholders = [
    'YOUR_NEW_PRIVATE_KEY_HERE',
    'CHANGE_ME',
    'your-railway-mysql-host',
  ];
  const fbKeyIsPlaceholder = !fbPrivateKey || fbPlaceholders.some(p => fbPrivateKey.includes(p));
  if (!fbProjectId || fbKeyIsPlaceholder || !fbClientEmail) {
    console.warn('');
    console.warn('╔════════════════════════════════════════════════════════════════╗');
    console.warn('║  ⚠️  FIREBASE CREDENTIALS NOT CONFIGURED                       ║');
    console.warn('║                                                                ║');
    console.warn('║  Push notifications (FCM) will be DISABLED until you set:     ║');
    console.warn('║    FIREBASE_PROJECT_ID                                         ║');
    console.warn('║    FIREBASE_PRIVATE_KEY  (from Firebase Console Service Acct) ║');
    console.warn('║    FIREBASE_CLIENT_EMAIL                                       ║');
    console.warn('║                                                                ║');
    console.warn('║  In-app notifications will still work normally.               ║');
    console.warn('╚════════════════════════════════════════════════════════════════╝');
    console.warn('');
  } else {
    console.log('✅ Firebase credentials detected — push notifications enabled');
  }

  try {
    await initAdminTables();
  } catch (err) {
    console.error("⚠️ Admin table init error (continuing):", err.message);
  }

  // Run DB migrations before anything else.
  // Each is wrapped in runMigration() so a hung DDL (e.g. table lock under
  // heavy load) never prevents server.listen() from being reached.
  await runMigration("migrateNotificationsTable",      () => migrateNotificationsTable());
  await runMigration("migrateAppointmentSlotsCapacity",() => migrateAppointmentSlotsCapacity());
  await runMigration("migrateReminderSettings",        () => migrateReminderSettings());
  await runMigration("seedClinicSettings",             () => seedClinicSettings());
  await runMigration("setupVaccineTables",             () => setupVaccineTables());
  await runMigration("migrateDobVerification",         () => migrateDobVerification());
  await runMigration("migrateChildSortOrder",          () => migrateChildSortOrder());
  await runMigration("migrateVaccineAppointmentLink",  () => migrateVaccineAppointmentLink());
  // ⚠️ backfillVaccineRecords is intentionally NOT awaited here.
  // It runs after the server is already listening so it never blocks port binding.

  initializeScheduledNotifications();

  server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running at http://0.0.0.0:${PORT}`);
    console.log(`📡 Socket.IO running on ws://0.0.0.0:${PORT}`);
    console.log(`🌐 Environment: ${process.env.NODE_ENV || "development"}`);

    // Run backfill in the background — does not block port binding or incoming requests
    backfillVaccineRecords().catch(err =>
      console.error("❌ Background backfillVaccineRecords error:", err.message)
    );
  }).on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.error(`❌ Port ${PORT} is already in use.`);
    } else {
      console.error("❌ Server error:", err);
    }
    process.exit(1);
  });
}

bootstrap();
