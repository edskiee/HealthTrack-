/**
 * Delete All Appointment Slots Script
 * 
 * This script deletes ALL previously generated appointment slots from the database.
 * It preserves the slot generation functionality - administrators can still generate
 * new slots after running this script.
 * 
 * IMPORTANT: This only deletes slot RECORDS/DATA, not the slot generation logic or code.
 */

const http = require('http');
const https = require('https');

// Configuration - Update these if needed
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'testadmin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'testpass123';

// Utility function to make HTTP requests
function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const lib = BASE_URL.startsWith('https') ? https : http;
    
    const req = lib.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data
          });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Login as admin to get admin credentials (note: admin login doesn't return token)
async function loginAsAdmin() {
  console.log('🔐 Logging in as administrator...');
  
  const postData = JSON.stringify({
    username: ADMIN_USERNAME,
    password: ADMIN_PASSWORD
  });
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/admin/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  
  try {
    const response = await makeRequest(options, postData);
    
    console.log(`   Login response status: ${response.statusCode}`);
    console.log(`   Login response body:`, JSON.stringify(response.body, null, 2));
    
    if (response.statusCode === 200 && response.body && response.body.success) {
      console.log('✅ Admin login successful');
      // Admin login doesn't return a token, so we'll return null
      // and proceed without authentication for the delete operation
      return null;
    } else {
      throw new Error(response.body?.message || 'Login failed');
    }
  } catch (error) {
    throw new Error(`Admin login error: ${error.message}`);
  }
}

// Get current slot count before deletion
async function getCurrentSlotCount() {
  console.log('\n📊 Checking current slot count...');
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots/user-viewable',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      const count = response.body.data.length;
      console.log(`   Found ${count} existing appointment slots`);
      return count;
    } else {
      console.log(`   ⚠️  Warning: Could not retrieve slot count`);
      return null;
    }
  } catch (error) {
    console.log(`   ⚠️  Warning: Error checking slot count: ${error.message}`);
    return null;
  }
}

// Delete ALL appointment slots
async function deleteAllSlots() {
  console.log('\n🗑️  Deleting ALL appointment slots...\n');
  
  // DELETE request to /appointment-slots without any filters
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots',
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      const deletedCount = response.body.data.deletedCount;
      console.log(`   ✅ Successfully deleted ${deletedCount} appointment slot(s)`);
      
      if (response.body.data.deletedSlots && response.body.data.deletedSlots.length > 0) {
        console.log(`\n   Deleted slots summary:`);
        response.body.data.deletedSlots.forEach((slot, index) => {
          console.log(`   - Slot ${index + 1}: ID=${slot.id}, Service=${slot.service_id}, Date=${slot.appointment_date}`);
        });
      }
      
      return {
        success: true,
        deletedCount: deletedCount,
        message: response.body.message
      };
    } else {
      const errorMsg = response.body.message || `HTTP ${response.statusCode}`;
      console.log(`   ❌ Failed to delete slots: ${errorMsg}`);
      return {
        success: false,
        message: errorMsg
      };
    }
  } catch (error) {
    console.log(`   ❌ Error deleting slots: ${error.message}`);
    return {
      success: false,
      error: error.message
    };
  }
}

// Verify deletion was successful
async function verifyDeletion() {
  console.log('\n✅ Verifying deletion...\n');
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots/user-viewable',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      const remainingCount = response.body.data.length;
      
      if (remainingCount === 0) {
        console.log(`   ✅ Verification successful: No appointment slots remaining`);
        return { verified: true, remainingCount: 0 };
      } else {
        console.log(`   ⚠️  Warning: ${remainingCount} slots still remain in database`);
        return { verified: false, remainingCount: remainingCount };
      }
    } else {
      console.log(`   ⚠️  Warning: Could not verify deletion`);
      return { verified: false, error: 'Verification failed' };
    }
  } catch (error) {
    console.log(`   ⚠️  Warning: Error verifying deletion: ${error.message}`);
    return { verified: false, error: error.message };
  }
}

// Main execution function
async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║     DELETE ALL APPOINTMENT SLOTS - ADMINISTRATIVE TOOL    ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');
  
  console.log('⚠️  WARNING: This will permanently delete ALL appointment slots!');
  console.log('ℹ️  Note: This only deletes slot DATA, not the slot generation functionality.\n');
  
  try {
    // Step 1: Login as admin (for verification purposes)
    await loginAsAdmin();
    
    // Step 2: Check current slot count
    const initialCount = await getCurrentSlotCount();
    
    if (initialCount === 0) {
      console.log('\n✅ No appointment slots found in database. Nothing to delete.');
      console.log('\n✨ Operation completed successfully!');
      process.exit(0);
    }
    
    // Step 3: Delete all slots
    const deleteResult = await deleteAllSlots();
    
    if (!deleteResult.success) {
      console.log('\n❌ Deletion failed. Please check the error above.');
      process.exit(1);
    }
    
    // Step 4: Verify deletion
    const verifyResult = await verifyDeletion();
    
    // Final summary
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║                    OPERATION SUMMARY                        ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');
    
    console.log(`📊 Initial slot count: ${initialCount !== null ? initialCount : 'Unknown'}`);
    console.log(`🗑️  Slots deleted: ${deleteResult.deletedCount || 'Unknown'}`);
    console.log(`✅ Remaining slots: ${verifyResult.remainingCount || 0}`);
    console.log(`🔒 Verification: ${verifyResult.verified ? 'PASSED' : 'FAILED'}`);
    
    if (verifyResult.verified && verifyResult.remainingCount === 0) {
      console.log('\n✅ SUCCESS: All appointment slots have been completely removed!');
      console.log('ℹ️  The slot generation functionality remains intact.');
      console.log('ℹ️  Administrators can generate new slots at any time.\n');
      process.exit(0);
    } else {
      console.log('\n⚠️  WARNING: Some slots may still remain. Please verify manually.');
      process.exit(1);
    }
    
  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error.message);
    console.error('\nStack trace:', error.stack);
    process.exit(1);
  }
}

// Run the script
main();
