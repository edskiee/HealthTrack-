# Running the HealthTrack Backend Server

## Prerequisites

1. Node.js installed (version 14 or higher recommended)
2. MySQL database running with the HealthTrack database created
3. Proper database credentials configured in [src/config/db.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/config/db.js)

## Installation Steps

1. Navigate to the backend directory:
   ```bash
   cd backend_nodejs
   ```

2. Install all dependencies:
   ```bash
   npm install
   ```

## Starting the Server

### Production Mode
```bash
npm start
```

### Development Mode (with auto-restart on file changes)
```bash
npm run dev
```

## Accessing Endpoints

Once the server is running, it will be available at:
- Local access: http://localhost:3000
- Network access: http://your-machine-ip:3000

### Available Routes

The server uses a clean route structure without the `/api` prefix:

#### Admin Routes
- POST `/admin/login` - Admin login
- POST `/admin/register` - Admin registration
- GET `/admin/notifications` - Get admin notifications
- GET `/admin/appointments/pending` - Get pending appointments
- And more...

#### Other Routes
- `/dashboard` - Dashboard endpoints
- `/patients` - Patient management
- `/auth` - Authentication
- `/health-records` - Health records
- `/appointments` - Appointments
- `/notifications` - Notifications
- `/health-tips` - Health tips
- `/reminders` - Reminders

## Common Issues and Solutions

### 1. "Cannot GET /api/admin/login" Error

**Problem**: You're trying to access the endpoint with an incorrect path.

**Solution**: 
- ❌ Wrong: http://localhost:3000/api/admin/login
- ✅ Correct: http://localhost:3000/admin/login

The routes are mounted directly under their names (e.g., `/admin`), not under `/api`.

### 2. "EADDRINUSE" Error

**Problem**: Port 3000 is already in use by another application.

**Solution**: 
1. Kill the process using port 3000:
   ```bash
   taskkill /f /im node.exe
   ```
   
2. Or change the PORT in [src/server.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/server.js) to a different number.

### 3. Database Connection Failed

**Problem**: The server can't connect to the MySQL database.

**Solution**:
1. Verify MySQL is running
2. Check credentials in [src/config/db.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/config/db.js)
3. Ensure the `healthtrack` database exists

## Testing the Server

### Manual Testing with Browser or Postman

1. Start the server: `npm start`
2. Open your browser or Postman
3. Test the root endpoint: GET http://localhost:3000
4. Test admin login: POST http://localhost:3000/admin/login

### Automated Testing

Run the included test script:
```bash
npm run test-server
```

This will verify that the server is running and endpoints are accessible.

## Example Requests

### Admin Login
```bash
curl -X POST http://localhost:3000/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password123"}'
```

### Get Pending Appointments (requires authentication)
```bash
curl -X GET http://localhost:3000/admin/appointments/pending \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Stopping the Server

Press `Ctrl + C` in the terminal where the server is running.