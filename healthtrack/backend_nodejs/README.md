# HealthTrack Backend API

## Project Structure
```
backend_nodejs/
├── src/
│   ├── config/
│   │   └── db.js
│   ├── controllers/
│   │   ├── adminController.js
│   │   ├── adminNotificationController.js
│   │   └── ... (other controllers)
│   ├── routes/
│   │   ├── admin.js
│   │   └── ... (other route files)
│   ├── services/
│   └── server.js (Main entry point)
├── package.json
└── README.md (This file)
```

## Available Endpoints

### Admin Routes
- POST `/admin/login` - Admin login
- POST `/admin/register` - Admin registration
- GET `/admin/notifications` - Get admin notifications
- GET `/admin/notifications/user/:userId` - Get user notifications
- GET `/admin/notifications/user/:userId/unread-count` - Get unread notifications count
- GET `/admin/appointments/pending-count` - Get pending appointments count
- GET `/admin/appointments/pending` - Get pending appointments
- PUT `/admin/notifications/:notificationId/read` - Mark notification as read
- PUT `/admin/notifications/mark-all-read` - Mark all notifications as read
- DELETE `/admin/notifications/:notificationId` - Delete notification
- POST `/admin/notifications/send` - Send custom notification

### Other Routes
- `/dashboard` - Dashboard related endpoints
- `/patients` - Patient management endpoints
- `/auth` - Authentication endpoints
- `/health-records` - Health records endpoints
- `/appointments` - Appointment management endpoints
- `/notifications` - General notification endpoints
- `/health-tips` - Health tips endpoints
- `/reminders` - Reminder management endpoints
- `/reminder-notifications` - Reminder notification endpoints

## How to Run the Server

1. Navigate to the backend directory:
   ```bash
   cd backend_nodejs
   ```

2. Install dependencies (if not already installed):
   ```bash
   npm install
   ```

3. Start the server:
   ```bash
   npm start
   ```
   
   Or for development with auto-restart:
   ```bash
   npm run dev
   ```

4. The server will start on port 3000. You can access it at:
   - http://localhost:3000
   - http://your-machine-ip:3000 (for mobile access)

## Testing Endpoints

To test the admin login endpoint, make a POST request to:
```
http://localhost:3000/admin/login
```

With a JSON body like:
```json
{
  "username": "admin",
  "password": "password123"
}
```

## Troubleshooting

If you're getting "Cannot GET /api/admin/login", make sure you're using the correct path:
- ❌ Wrong: http://localhost:3000/api/admin/login
- ✅ Correct: http://localhost:3000/admin/login

The routes are mounted directly under `/admin`, not `/api/admin`.
