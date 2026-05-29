# HealthTrack Backend Server Routing Solution

## Problem Analysis

The issue was a misunderstanding of the URL structure. The user was trying to access:
```
http://localhost:3000/api/admin/login
```

But the correct URL is:
```
http://localhost:3000/admin/login
```

## Root Cause

In the [server.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/server.js) file, the routes are mounted directly without the `/api` prefix:

```javascript
app.use("/admin", adminRoutes);
app.use("/dashboard", dashboardRoutes);
app.use("/patients", patientsRoutes);
// ... other routes
```

This means:
- ✅ Correct: http://localhost:3000/admin/login
- ❌ Incorrect: http://localhost:3000/api/admin/login

## Complete Solution

### 1. Folder Structure
```
backend_nodejs/
├── src/
│   ├── config/
│   │   └── db.js (MySQL connection pool)
│   ├── controllers/
│   │   ├── adminController.js (Login & register functions)
│   │   ├── adminNotificationController.js
│   │   └── ... (other controllers)
│   ├── routes/
│   │   ├── admin.js (Admin routes)
│   │   └── ... (other route files)
│   ├── services/
│   └── server.js (Main entry point)
├── package.json
└── README.md
```

### 2. Route Configuration in server.js

```javascript
// Import routes
const adminRoutes = require("./routes/admin");
const dashboardRoutes = require("./routes/dashboard");
// ... other route imports

// Mount routes (without /api prefix)
app.use("/admin", adminRoutes);
app.use("/dashboard", dashboardRoutes);
app.use("/patients", patientsRoutes);
// ... other route mounts
```

### 3. Admin Routes in admin.js

```javascript
const express = require("express");
const { adminLogin, adminRegister } = require("../controllers/adminController");
// ... other controller imports

const router = express.Router();

// Define routes
router.post("/login", adminLogin);
router.post("/register", adminRegister);
// ... other admin routes

module.exports = router;
```

### 4. Controller Implementation

The [adminController.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/controllers/adminController.js) properly handles:
- Request validation
- Password hashing with MD5
- Database queries
- Error handling
- Proper response formatting

## How to Run the Server

1. Navigate to the backend directory:
   ```bash
   cd backend_nodejs
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the server:
   ```bash
   npm start
   ```

4. Access endpoints:
   - Root: http://localhost:3000
   - Admin login: http://localhost:3000/admin/login
   - Admin register: http://localhost:3000/admin/register

## Testing Endpoints

### Using curl
```bash
# Test root endpoint
curl http://localhost:3000

# Test admin login (will return validation error without data)
curl -X POST http://localhost:3000/admin/login

# Test admin login with data
curl -X POST http://localhost:3000/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password123"}'
```

### Using the test script
```bash
npm run test-server
```

## Key Points to Remember

1. **No `/api` prefix**: Routes are mounted directly (e.g., `/admin`, not `/api/admin`)
2. **Proper error handling**: Controllers return appropriate HTTP status codes
3. **Database integration**: Uses MySQL connection pool for efficient database access
4. **CORS enabled**: Allows cross-origin requests for frontend integration
5. **Socket.IO support**: Real-time communication capabilities

## Common Mistakes to Avoid

1. ❌ Using `/api/admin/login` instead of `/admin/login`
2. ❌ Forgetting to start the server before testing
3. ❌ Not installing dependencies with `npm install`
4. ❌ Using wrong database credentials in [db.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/config/db.js)
5. ❌ Sending malformed JSON in POST requests

## Verification

All endpoints have been tested and verified to work correctly:
- ✅ Root endpoint returns server status
- ✅ Admin login endpoint validates input and returns proper errors
- ✅ Admin register endpoint validates input and returns proper errors
- ✅ Incorrect paths return 404 errors
- ✅ Server connects to MySQL database successfully
- ✅ Server starts Socket.IO for real-time communication

The routing system is now fully functional and ready for use with your frontend applications.