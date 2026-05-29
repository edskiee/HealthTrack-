const express = require("express");
const cors = require("cors");
const adminRoutes = require("./routes/admin");
const dashboardRoutes = require("./routes/dashboard");
const patientsRoutes = require("./routes/patients");
const authRoutes = require("./routes/auth");
const healthRecordsRoutes = require("./routes/healthRecords");
const path = require("path");
const dbPool = require("./config/db");
const initAdminTables = require("./utils/initAdminTables");

const appointmentsRoutes = require("./routes/appointments");
const appointmentSlotsRoutes = require("./routes/appointmentSlots");
const serviceConfigRoutes = require("./routes/serviceConfig");
const notificationsRoutes = require("./routes/notifications");
const healthTipsRoutes = require("./routes/healthTips");
const remindersRoutes = require("./routes/reminders");
const fcmNotificationsRoutes = require("./routes/fcmNotifications");
const appointmentRemindersRoutes = require("./routes/appointmentReminders");
const systemSettingsRoutes = require("./routes/systemSettings");
const referralsRoutes = require("./routes/referrals");
const testNotificationsRoutes = require("./routes/testNotifications");
// Removed healthWorkersRoutes
const http = require('http');
const socketIo = require('socket.io');
const { createScheduledNotificationsTable, sendDueNotifications } = require('./services/scheduledNotificationService');
const { checkAndSendDueReminders } = require('./services/appointmentReminderService');
const { createUserDeviceTokensTable } = require('./services/appointmentPushService');
const { createAppointmentRemindersTable } = require('./setup/appointmentReminderSetup');
const { startNotificationScheduler } = require('./services/notificationScheduler');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow all origins for Socket.IO
    methods: ["GET", "POST"],
    credentials: true
  }
});

const PORT = 3000;
const pkgManifest = require(path.join(__dirname, "../package.json"));

// Store io instance in app locals for access in controllers
app.locals.io = io;
app.locals.serverHealthLabel = "Operational";

app.set("trust proxy", 1);

app.use(
  "/uploads",
  express.static(path.join(__dirname, "../public"))
);

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : '*',
  credentials: true
}));

// ✅ Handle preflight requests for all routes
app.options('*', cors());

// ✅ Parse JSON with increased limit for larger payloads
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ✅ Routes
app.use("/admin", adminRoutes);
app.use("/dashboard", dashboardRoutes);
app.use("/patients", patientsRoutes);
app.use("/auth", authRoutes);
app.use("/health-records", healthRecordsRoutes);
app.use("/appointments", appointmentsRoutes);
app.use("/appointment-slots", appointmentSlotsRoutes);
app.use("/service-config", serviceConfigRoutes);
app.use("/notifications", notificationsRoutes);
app.use("/health-tips", healthTipsRoutes);
app.use("/reminders", remindersRoutes);
app.use("/fcm-notifications", fcmNotificationsRoutes);
app.use("/appointment-reminders", appointmentRemindersRoutes);
app.use("/system-settings", systemSettingsRoutes);
app.use("/referrals", referralsRoutes);
app.use("/test", testNotificationsRoutes);
// Removed health-workers routes

// Add a root endpoint for health checks
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'HealthTrack API is running',
    timestamp: new Date().toISOString()
  });
});

let previousHealthLabel;

async function probeServerHealth(ioInstance) {
  let ok = true;
  try {
    await dbPool.query("SELECT 1");
    ok = true;
  } catch {
    ok = false;
  }
  const label = ok ? "Operational" : "Degraded";
  app.locals.serverHealthLabel = label;
  const stablePrev =
    typeof previousHealthLabel === "string" ? previousHealthLabel : null;
  const changed = stablePrev !== null && stablePrev !== label;
  previousHealthLabel = label;

  if (!ioInstance) {
    return;
  }

  ioInstance.emit("serverHealthChanged", {
    status: label,
    at: Date.now(),
  });

  if (changed) {
    ioInstance.to("admins").emit("systemAlert", {
      severity: ok ? "recover" : "critical",
      message: ok
        ? "All platform checks passed again."
        : "Database heartbeat failed — platform may be unavailable.",
      at: Date.now(),
    });
  }
}

(async () => {
  await probeServerHealth(null);
})();

setInterval(() => probeServerHealth(io), 60000).unref?.();

app.get('/health', (req, res) => {
  const ok = app.locals.serverHealthLabel === "Operational";
  res.status(ok ? 200 : 503).json({
    success: ok,
    message: ok ? 'Server is healthy' : 'Server is degraded',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: pkgManifest.version || '1.0.0',
    build: process.env.BUILD_NUMBER || 'local'
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('📱 Client connected:', socket.id);
  
  // Handle user joining a room
  socket.on('joinUserRoom', (userId) => {
    socket.join(`user_${userId}`);
    console.log(`📱 User ${userId} joined room user_${userId}`);
  });
  
  // Handle user leaving a room
  socket.on('leaveUserRoom', (userId) => {
    socket.leave(`user_${userId}`);
    console.log(`📱 User ${userId} left room user_${userId}`);
  });
  
  // Handle admin joining the admins room
  socket.on('joinAdminsRoom', () => {
    socket.join('admins');
    socket.emit('serverHealthChanged', {
      status: app.locals.serverHealthLabel || 'Operational',
      at: Date.now(),
      immediate: true
    });
    console.log(`📱 Admin joined admins room`);
  });

  socket.on('joinAdminRoom', (adminId) => {
    if (adminId == null) return;
    const roomId = String(adminId);
    socket.join(`admin_${roomId}`);
    console.log(`📱 Admin scoped socket joined admin_${roomId}`);
  });

  // Handle admin leaving the admins room
  socket.on('leaveAdminsRoom', () => {
    socket.leave('admins');
    console.log(`📱 Admin left admins room`);
  });
  
  socket.on('disconnect', () => {
    console.log('📱 Client disconnected:', socket.id);
  });
});

// Initialize scheduled notifications table and start periodic check
async function initializeScheduledNotifications() {
  try {
    // Create the appointment reminders table if it doesn't exist
    console.log('🔧 Setting up appointment reminders system...');
    await createAppointmentRemindersTable();
    
    // Create the scheduled notifications table if it doesn't exist
    await createScheduledNotificationsTable();
    await createUserDeviceTokensTable();
    
    // Start the enhanced notification scheduler
    console.log('🚀 Starting enhanced notification scheduler...');
    const schedulerResult = await startNotificationScheduler();
    
    if (schedulerResult.success) {
      console.log('✅ Enhanced notification scheduler started successfully');
    } else {
      console.warn('⚠️ Failed to start enhanced scheduler, falling back to manual intervals:', schedulerResult.message);
      
      // Fallback to manual intervals if scheduler fails
      setInterval(async () => {
        try {
          await sendDueNotifications();
        } catch (error) {
          console.error('Error in periodic scheduled notifications check:', error);
        }
      }, 60000); // Check every minute
      
      setInterval(async () => {
        try {
          await checkAndSendDueReminders();
        } catch (error) {
          console.error('Error in periodic appointment reminders check:', error);
        }
      }, 60000); // Check every minute
    }
    
    console.log('✅ Scheduled notifications system initialized');
  } catch (error) {
    console.error('❌ Error initializing scheduled notifications system:', error);
  }
}

async function bootstrap() {
  try {
    await initAdminTables();
  } catch {
    // Error already logged in initAdminTables; continue startup so health checks still run.
  }

  // Initialize scheduled notifications when the server starts
  initializeScheduledNotifications();

  // ✅ Start Server on all interfaces with error handling
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running at http://0.0.0.0:${PORT}`);
    console.log(`📡 Socket.IO server running on ws://0.0.0.0:${PORT}`);
    console.log(`📱 Use your machine's IP address to access from mobile devices`);
  }).on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.log(`⚠️  Port ${PORT} is already in use. Please kill the process or use a different port.`);
      console.log(`💡 To kill the process on Windows, run: taskkill /f /im node.exe`);
      process.exit(1);
    } else {
      console.error("❌ Server error:", err);
    }
  });
}

bootstrap();