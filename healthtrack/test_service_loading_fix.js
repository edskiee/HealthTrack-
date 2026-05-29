// Test script to verify the service loading fix
// This script tests that boolean fields are properly converted

const express = require('express');
const app = express();
const port = 3001;

// Mock data simulating what MySQL might return (with booleans as integers)
const mockServices = [
  {
    id: 1,
    service_name: 'Maternal Care',
    service_description: 'Prenatal and postnatal care services for mothers',
    service_type: 'maternal',
    is_enabled: 1, // Integer instead of boolean
    required_fields: '["mother_name", "expected_delivery_date", "contact_number", "address"]',
    available_days: '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
    max_appointments_per_day: 20,
    created_at: '2023-01-01 10:00:00',
    updated_at: '2023-01-01 10:00:00'
  },
  {
    id: 2,
    service_name: 'Immunization',
    service_description: 'Child immunization and vaccination services',
    service_type: 'immunization',
    is_enabled: 1, // Integer instead of boolean
    required_fields: '["child_name", "vaccine_type", "date_of_birth", "parent_guardian"]',
    available_days: '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]',
    max_appointments_per_day: 30,
    created_at: '2023-01-01 10:00:00',
    updated_at: '2023-01-01 10:00:00'
  }
];

// Mock endpoint that simulates the old behavior (returning integers for booleans)
app.get('/old-behavior/service-config', (req, res) => {
  res.json({
    success: true,
    data: mockServices,
    count: mockServices.length
  });
});

// Mock endpoint that simulates the fixed behavior (returning proper booleans)
app.get('/fixed-behavior/service-config', (req, res) => {
  const fixedServices = mockServices.map(service => ({
    ...service,
    is_enabled: service.is_enabled === 1, // Convert to proper boolean
    required_fields: JSON.parse(service.required_fields),
    available_days: JSON.parse(service.available_days)
  }));
  
  res.json({
    success: true,
    data: fixedServices,
    count: fixedServices.length
  });
});

app.listen(port, () => {
  console.log(`Test server running at http://localhost:${port}`);
  console.log('\nTo test the fix:');
  console.log('1. Update your ApiConfig to point to http://localhost:3001/fixed-behavior');
  console.log('2. Run the HealthTrack app and check if services load without errors');
  console.log('3. To simulate the old error, point to http://localhost:3001/old-behavior\n');
});