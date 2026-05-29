# HealthTrack - Pediatric Healthcare Management System

A comprehensive Flutter application for managing pediatric healthcare records, appointments, and patient information.

## Features

- **User Authentication**: Secure login and registration system
- **Service Type Selection**: Choose between Immunization and Maternal Care services
- **Patient Registration**: Multi-step form for registering children with complete medical information
- **Health Records**: Comprehensive health record management
- **Appointment Management**: Schedule and track medical appointments
- **Cross-Platform**: Works on Android, iOS, and Web

## Tech Stack

- **Frontend**: Flutter/Dart
- **Backend**: Node.js with Express
- **Database**: MySQL
- **Architecture**: Client-Server with RESTful API

## Project Structure

```
healthtrack/
├── lib/                    # Flutter frontend code
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   └── models/            # Data models
├── backend_nodejs/         # Node.js backend
│   ├── src/
│   │   ├── controllers/   # API controllers
│   │   ├── routes/        # API routes
│   │   └── config/        # Database configuration
│   └── server.js          # Main server file
└── database/              # Database scripts
    ├── healthtrack_mysql_schema.sql
    └── setup scripts
```

## Setup Instructions

1. **Database Setup**:
   - Install MySQL
   - Run the schema script: `database/healthtrack_mysql_schema.sql`
   - Configure database connection in `backend_nodejs/src/config/db.js`

2. **Database Update for Service Type** (if updating existing database):
   - Windows: Run `update_database_service_type.bat`
   - PowerShell: Run `update_database_service_type.ps1`
   - Or manually execute: `database/update_users_service_type.sql`

3. **Database Update for Admin Dashboard** (if updating existing database):
   - Windows: Run `update_dashboard_schema.bat`
   - PowerShell: Run `update_dashboard_schema.ps1`
   - Or manually execute: `database/update_dashboard_schema.sql`

4. **Backend Setup**:
   ```bash
   cd backend_nodejs
   npm install
   npm start
   ```

5. **Frontend Setup**:
   ```bash
   flutter pub get
   flutter run
   ```

## New Service Type Feature

HealthTrack now supports two distinct service types:
- **Immunization**: For pediatric vaccination and immunization tracking
- **Maternal Care**: For prenatal and maternal healthcare services

Users can select their preferred service type during registration, and the system will store this information for personalized dashboard experiences.

## Key Components

- **Login Screen**: Secure authentication with proper error handling
- **User Type Selection Screen**: Choose between Immunization and Maternal Care
- **Service-Specific Registration Screens**: Tailored registration forms for each service type
- **Dashboard**: Main interface for healthcare management
- **Health Records**: Complete patient health information management

## File Cleanup

Unnecessary test, debug, and duplicate files have been removed to improve project maintainability. See `REMOVED_FILES_SUMMARY.md` for details.

## Status

✅ All major issues resolved and system is fully functional