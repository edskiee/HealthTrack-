const axios = require('axios');

const API_URL = 'http://localhost:3000';

async function runTest() {
  try {
    // 1. Fetch user-viewable slots (should return { success: true, data: [...] })
    console.log('Fetching user-viewable slots...');
    const userViewResponse = await axios.get(`${API_URL}/appointment-slots/user-view?serviceId=16`);
    if (userViewResponse.data.success && Array.isArray(userViewResponse.data.data)) {
      console.log(`✅ Success: getUserViewableSlots returned ${userViewResponse.data.data.length} slots in the correct format.`);
    } else {
      console.error('❌ Error: getUserViewableSlots returned invalid format:', userViewResponse.data);
    }

    // 2. Fetch available slots (should return { success: true, data: [...] })
    console.log('Fetching available slots for a specific date...');
    const availableSlotsResponse = await axios.get(`${API_URL}/appointment-slots/available?serviceId=16&date=2026-10-20`);
    if (availableSlotsResponse.data.success && Array.isArray(availableSlotsResponse.data.data)) {
      console.log(`✅ Success: getAvailableSlots returned ${availableSlotsResponse.data.data.length} slots in the correct format.`);
    } else {
      console.error('❌ Error: getAvailableSlots returned invalid format:', availableSlotsResponse.data);
    }

    // 3. Create a new slot (should return { success: true, ... })
    console.log('Creating a new slot...');
    const newSlotResponse = await axios.post(`${API_URL}/appointment-slots`, {
      service_id: 16,
      appointment_date: '2026-10-21',
      start_time: '11:00:00',
      end_time: '12:00:00',
      max_patients: 1,
    });
    if (newSlotResponse.data.success) {
      console.log('✅ Success: createSlot returned correct format:', newSlotResponse.data.message);
    } else {
      console.error('❌ Error: createSlot returned invalid format:', newSlotResponse.data);
    }

  } catch (error) {
    console.error('Test failed:', error.response ? error.response.data : error.message);
  }
}

runTest();
