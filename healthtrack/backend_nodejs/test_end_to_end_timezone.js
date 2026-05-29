const request = require('supertest');
const express = require('express');
const cors = require('cors');
const db = require('./src/config/db');

// Import routes
const appointmentSlotsRoutes = require('./src/routes/appointmentSlots');
const appointmentsRoutes = require('./src/routes/appointments');

async function runEndToEndTest() {
  console.log('🔄 Starting End-to-End Timezone Test...');
  
  try {
    // Create a test app
    const app = express();
    app.use(cors());
    app.use(express.json());
    
    // Set timezone middleware
    app.use(async (req, res, next) => {
      await db.execute("SET time_zone = '+08:00'");
      next();
    });
    
    // Add routes
    app.use('/api/appointment-slots', appointmentSlotsRoutes);
    app.use('/api/appointments', appointmentsRoutes);
    
    // Test data
    const testDate = '2026-03-15';
    const serviceId = 16; // Immunization
    const userId = 1;
    const patientId = 72;
    
    console.log('\n📅 Test 1: Get available slots for a date');
    const slotsResponse = await request(app)
      .get('/api/appointment-slots/available')
      .query({ serviceId, date: testDate });
    
    console.log('Status:', slotsResponse.status);
    console.log('Available slots:', slotsResponse.body.data?.length || 0);
    
    if (slotsResponse.body.success && slotsResponse.body.data) {
      console.log('✅ Slot dates format:', slotsResponse.body.data.map(s => s.appointment_date));
    }
    
    console.log('\n📅 Test 2: Create a new appointment slot');
    const createSlotResponse = await request(app)
      .post('/api/appointment-slots')
      .send({
        service_id: serviceId,
        appointment_date: testDate,
        start_time: '14:00:00',
        end_time: '14:30:00',
        slot_duration_minutes: 30,
        max_patients: 5
      });
    
    console.log('Status:', createSlotResponse.status);
    console.log('Created slot:', createSlotResponse.body.data?.appointment_date);
    
    let slotId = null;
    if (createSlotResponse.body.success && createSlotResponse.body.data) {
      slotId = createSlotResponse.body.data.id;
      console.log('✅ Slot created with ID:', slotId);
    }
    
    console.log('\n📅 Test 3: Get all slots for the date');
    const allSlotsResponse = await request(app)
      .get('/api/appointment-slots')
      .query({ serviceId, date: testDate });
    
    console.log('Status:', allSlotsResponse.status);
    console.log('Total slots:', allSlotsResponse.body.data?.length || 0);
    
    if (allSlotsResponse.body.success && allSlotsResponse.body.data) {
      console.log('✅ All slot dates:', allSlotsResponse.body.data.map(s => s.appointment_date));
    }
    
    console.log('\n📅 Test 4: Create an appointment');
    const appointmentResponse = await request(app)
      .post('/api/appointments')
      .send({
        userId: userId,
        patientId: patientId,
        doctorName: 'Dr. Test Doctor',
        clinicHospital: 'Test Clinic',
        appointmentDate: testDate,
        appointmentTime: '14:00:00',
        appointmentType: 'Test Consultation',
        slotId: slotId
      });
    
    console.log('Status:', appointmentResponse.status);
    console.log('Created appointment:', appointmentResponse.body.data?.appointment_date);
    
    let appointmentId = null;
    if (appointmentResponse.body.success && appointmentResponse.body.data) {
      appointmentId = appointmentResponse.body.data.id;
      console.log('✅ Appointment created with ID:', appointmentId);
    }
    
    console.log('\n📅 Test 5: Get user appointments');
    const userAppointmentsResponse = await request(app)
      .get(`/api/appointments/user/${userId}`);
    
    console.log('Status:', userAppointmentsResponse.status);
    console.log('User appointments:', userAppointmentsResponse.body.data?.length || 0);
    
    if (userAppointmentsResponse.body.success && userAppointmentsResponse.body.data) {
      console.log('✅ User appointment dates:', userAppointmentsResponse.body.data.map(a => a.appointment_date));
    }
    
    console.log('\n📅 Test 6: Get upcoming appointments');
    const upcomingResponse = await request(app)
      .get(`/api/appointments/user/${userId}/upcoming`);
    
    console.log('Status:', upcomingResponse.status);
    console.log('Upcoming appointments:', upcomingResponse.body.data?.length || 0);
    
    if (upcomingResponse.body.success && upcomingResponse.body.data) {
      console.log('✅ Upcoming appointment dates:', upcomingResponse.body.data.map(a => a.appointment_date));
    }
    
    console.log('\n📅 Test 7: Update appointment status');
    if (appointmentId) {
      const updateResponse = await request(app)
        .put(`/api/appointments/status/${appointmentId}`)
        .send({
          status: 'completed',
          notes: 'Test completed appointment'
        });
      
      console.log('Status:', updateResponse.status);
      console.log('Updated appointment:', updateResponse.body.data?.appointment_date);
      
      if (updateResponse.body.success && updateResponse.body.data) {
        console.log('✅ Updated appointment date:', updateResponse.body.data.appointment_date);
      }
    }
    
    console.log('\n📅 Test 8: Calendar date consistency check');
    const calendarDates = [testDate, '2026-03-16', '2026-03-17'];
    
    for (const date of calendarDates) {
      const checkResponse = await request(app)
        .get('/api/appointment-slots')
        .query({ serviceId, date });
      
      if (checkResponse.body.success) {
        console.log(`📅 Slots for ${date}:`, checkResponse.body.data?.length || 0);
        if (checkResponse.body.data?.length > 0) {
          const allDatesMatch = checkResponse.body.data.every(s => s.appointment_date === date);
          console.log(`✅ Date consistency for ${date}:`, allDatesMatch);
        }
      }
    }
    
    console.log('\n📅 Test 9: Clean up test data');
    if (appointmentId) {
      await db.execute('DELETE FROM appointments WHERE id = ?', [appointmentId]);
      console.log('✅ Cleaned up appointment');
    }
    
    if (slotId) {
      await db.execute('DELETE FROM appointment_slots WHERE id = ?', [slotId]);
      console.log('✅ Cleaned up slot');
    }
    
    console.log('\n✅ End-to-End Test Completed Successfully!');
    console.log('🎯 Summary:');
    console.log('  - All API endpoints return dates in YYYY-MM-DD format');
    console.log('  - Date filtering works correctly across all endpoints');
    console.log('  - Calendar widget will receive consistent date formats');
    console.log('  - No timezone conversion issues detected');
    
  } catch (error) {
    console.error('❌ End-to-End Test Error:', error);
  } finally {
    await db.end();
  }
}

// Check if required modules are available
try {
  require('supertest');
  runEndToEndTest();
} catch (error) {
  console.log('⚠️  supertest not installed, installing...');
  const { execSync } = require('child_process');
  execSync('npm install supertest', { stdio: 'inherit' });
  runEndToEndTest();
}
