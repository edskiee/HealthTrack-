# Service Management Implementation

## Overview
This document describes the implementation of the Administrative Tools module for dynamic service management in the HealthTrack system. The implementation allows administrators to create, update, and manage healthcare services dynamically, which then appear in the patient registration form.

## Features Implemented

### 1. Backend API Endpoints
Created new RESTful API endpoints for service management:

- `GET /service-config` - Get all active services
- `GET /service-config/:id` - Get a specific service by ID
- `POST /service-config` - Create a new service
- `PUT /service-config/:id` - Update an existing service
- `DELETE /service-config/:id` - Soft delete a service
- `GET /service-config/:id/form-structure` - Get service form structure
- `PUT /service-config/:id/form-structure` - Update service form structure

### 2. Database Schema
Extended the existing `services_config` table with additional functionality:

- Service name and description
- Service type categorization
- Enabled/disabled status
- Required fields configuration (JSON)
- Available days configuration (JSON)
- Maximum appointments per day

### 3. Administrative Tools UI
Enhanced the Admin Settings page with a new Administrative Tools module:

- Service listing with detailed information
- Add, edit, and delete functionality
- Form for creating new services with customizable fields
- Visual indicators for service status

### 4. Dynamic Patient Registration
Updated the patient registration form to dynamically load available services:

- Services loaded from backend API
- Automatic dropdown population
- Service-specific icons and colors
- Error handling for service loading failures

## Technical Implementation Details

### Backend Components
- **Controller**: `serviceConfigController.js` handles all service-related business logic
- **Routes**: `serviceConfig.js` defines the API endpoints
- **Database**: Uses existing `services_config` table with enhanced functionality

### Frontend Components
- **Admin Service**: `ServiceConfigService` in the admin module for backend communication
- **Public Service**: `ServiceConfigService` in the public services module for patient registration
- **UI Widget**: `AdministrativeToolsWidget` for the admin interface
- **Registration Form**: Updated `UnifiedRegisterScreen` to use dynamic services

## Testing
A comprehensive test script (`test_service_workflow.js`) verifies the complete workflow:

1. Fetch existing services
2. Create new service
3. Verify service creation
4. Update service details
5. Verify service appears in list
6. Manage form structure
7. Verify form structure updates
8. Delete service
9. Verify service removal

## Integration Points

### With Existing System
- Works with existing authentication and authorization
- Integrates with current database schema
- Maintains backward compatibility with existing services
- Uses existing API configuration and error handling patterns

### Data Flow
1. Admin creates/modifies services via Administrative Tools
2. Services stored in database with JSON configurations
3. Patient registration form fetches active services from API
4. Form displays services with appropriate icons and labels
5. Registration data includes selected service type

## Future Enhancements
- Service-specific form field customization
- Service scheduling and availability management
- Service analytics and reporting
- Multi-language support for service names and descriptions

## Usage Instructions

### For Administrators
1. Navigate to Admin Settings → Administrative Tools
2. View existing services in the list
3. Click "Add New Service" to create a new service
4. Edit services using the edit icon
5. Delete services using the delete icon (soft delete)

### For Patients
1. Open registration form
2. Select from available services in the dropdown
3. Complete service-specific registration fields
4. Submit registration

## API Documentation

### Get All Services
```
GET /service-config
Response: {
  success: true,
  data: [...],
  count: number
}
```

### Create Service
```
POST /service-config
Body: {
  service_name: string,
  service_description: string,
  service_type: string,
  is_enabled: boolean,
  required_fields: string[],
  available_days: string[],
  max_appointments_per_day: number
}
Response: {
  success: true,
  message: "Service created successfully",
  data: {id, service_name, ...}
}
```

### Update Service
```
PUT /service-config/:id
Body: {
  [field]: value // Any updatable field
}
Response: {
  success: true,
  message: "Service updated successfully",
  data: {id, service_name, ...}
}
```

### Delete Service
```
DELETE /service-config/:id
Response: {
  success: true,
  message: "Service deleted successfully"
}
```