const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const adminMeController = require('../controllers/adminMeController');
const authMiddleware = require('../middleware/auth');

// Public routes
router.post('/login', adminController.adminLogin);
router.post('/register', adminController.adminRegister);

// Protected routes (require authentication)
router.use(authMiddleware.authenticateAdmin);

// Settings & platform (scoped before "/:id" routes)
router.get('/meta/system', adminMeController.getSystemMeta);
router.get('/audit-logs', adminMeController.listAuditLogs);
router.get('/me/preferences', adminMeController.getMyPreferences);
router.patch('/me/preferences', adminMeController.patchMyPreferences);
router.get('/me/sessions', adminMeController.listSessions);
router.delete('/me/sessions/:sessionId', adminMeController.revokeSession);
router.delete('/me/session', adminMeController.revokeMySessionLogout);
router.post(
  '/me/avatar',
  (req, res, next) =>
    adminMeController.uploadAvatarMiddleware.single('avatar')(req, res, (err) => {
      if (err) {
        return res.status(400).json({
          success: false,
          message:
            typeof err.message === 'string'
              ? err.message
              : 'Invalid avatar upload.',
        });
      }
      next();
    }),
  adminMeController.postAvatarUpload
);
router.post('/me/security/2fa/start', adminMeController.twoFactorSetupStart);
router.post('/me/security/2fa/confirm', adminMeController.twoFactorConfirm);
router.post('/me/security/2fa/disable', adminMeController.twoFactorDisable);

// Dashboard routes
router.get('/dashboard/stats', adminController.getDashboardStats);
router.get('/dashboard/patients', adminController.getDashboardPatients);
router.get('/dashboard/appointments', adminController.getDashboardAppointments);
router.get('/dashboard/reminders', adminController.getDashboardReminders);

// Patient management routes
router.get('/patients', adminController.getAllPatients);
router.get('/patients/:id', adminController.getPatientById);
router.put('/patients/:id', adminController.updatePatient);
router.delete('/patients/:id', adminController.deletePatient);
router.get('/patients/search/:query', adminController.searchPatients);

// User management routes
router.get('/users', adminController.getAllUsers);
router.get('/users/:id', adminController.getUserById);
router.put('/users/:id', adminController.updateUser);
router.delete('/users/:id', adminController.deleteUser);

// Appointment management routes
router.get('/appointments', adminController.getAppointments);
router.get('/appointments/pending-count', adminController.getPendingAppointmentsCount);
router.get('/appointments/pending', adminController.getPendingAppointments);
router.put('/appointments/:id/status', adminController.updateAppointmentStatus);

// Export routes
router.get('/exports/patients', adminController.exportPatients);
router.get('/exports/users', adminController.exportUsers);
router.get('/exports/appointments', adminController.exportAppointments);

// Profile routes
router.get('/:id', adminController.getAdminProfile);
router.put('/:id', adminController.updateAdminProfile);

// Settings routes
router.get('/settings', adminController.getSettings);
router.put('/settings', adminController.updateSettings);

module.exports = router;