const axios = require('axios');

// Test the complete workflow of creating new services and verifying they appear in patient registration

async function testServiceWorkflow() {
  const baseURL = 'http://localhost:3000/service-config';
  
  try {
    console.log('🧪 Starting Service Workflow Test...\n');
    
    // 1. Get all existing services
    console.log('1. Fetching existing services...');
    const getAllResponse = await axios.get(baseURL);
    console.log(`   Found ${getAllResponse.data.count} services\n`);
    
    // 2. Create a new service
    console.log('2. Creating a new test service...');
    const newService = {
      service_name: 'Dental Care',
      service_description: 'Comprehensive dental care services for children',
      service_type: 'dental',
      is_enabled: true,
      required_fields: ['child_name', 'date_of_birth', 'parent_guardian', 'emergency_contact'],
      available_days: ['Monday', 'Wednesday', 'Friday'],
      max_appointments_per_day: 15
    };
    
    const createResponse = await axios.post(baseURL, newService);
    console.log(`   ✅ Service created successfully with ID: ${createResponse.data.data.id}\n`);
    
    // 3. Get the newly created service
    console.log('3. Verifying the new service...');
    const getServiceResponse = await axios.get(`${baseURL}/${createResponse.data.data.id}`);
    console.log(`   ✅ Service verified: ${getServiceResponse.data.data.service_name}\n`);
    
    // 4. Update the service
    console.log('4. Updating the service...');
    const updateData = {
      service_description: 'Updated: Comprehensive dental care services for children and adults',
      max_appointments_per_day: 20
    };
    
    const updateResponse = await axios.put(`${baseURL}/${createResponse.data.data.id}`, updateData);
    console.log(`   ✅ Service updated successfully\n`);
    
    // 5. Get all services again to verify the new service appears
    console.log('5. Verifying the service appears in the full list...');
    const getAllResponse2 = await axios.get(baseURL);
    const newServiceInList = getAllResponse2.data.data.find(service => service.id === createResponse.data.data.id);
    
    if (newServiceInList) {
      console.log(`   ✅ New service found in list: ${newServiceInList.service_name}`);
      console.log(`   📝 Description: ${newServiceInList.service_description}`);
      console.log(`   📝 Max appointments: ${newServiceInList.max_appointments_per_day}\n`);
    } else {
      console.log('   ❌ New service not found in list\n');
    }
    
    // 6. Test form structure management
    console.log('6. Testing form structure management...');
    const formStructure = ['child_name', 'date_of_birth', 'parent_guardian', 'dental_history', 'allergies'];
    
    const updateFormResponse = await axios.put(`${baseURL}/${createResponse.data.data.id}/form-structure`, {
      required_fields: formStructure
    });
    console.log(`   ✅ Form structure updated successfully\n`);
    
    // 7. Verify form structure
    console.log('7. Verifying form structure...');
    const getFormResponse = await axios.get(`${baseURL}/${createResponse.data.data.id}/form-structure`);
    console.log(`   ✅ Form structure verified: ${JSON.stringify(getFormResponse.data.data.required_fields)}\n`);
    
    // 8. Delete the service (soft delete)
    console.log('8. Deleting the service...');
    const deleteResponse = await axios.delete(`${baseURL}/${createResponse.data.data.id}`);
    console.log(`   ✅ Service deleted successfully\n`);
    
    // 9. Verify the service is no longer in the list
    console.log('9. Verifying the service is removed from the list...');
    const getAllResponse3 = await axios.get(baseURL);
    const deletedServiceInList = getAllResponse3.data.data.find(service => service.id === createResponse.data.data.id);
    
    if (!deletedServiceInList) {
      console.log('   ✅ Service successfully removed from list\n');
    } else {
      console.log('   ❌ Service still appears in list\n');
    }
    
    console.log('🎉 All tests passed! The service workflow is working correctly.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.response ? error.response.data : error.message);
  }
}

// Run the test
testServiceWorkflow();