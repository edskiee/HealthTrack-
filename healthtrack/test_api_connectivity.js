// Test script to verify API connectivity from different IP addresses
const http = require('http');

const testUrls = [
    'http://localhost:3000',
    'http://127.0.0.1:3000', 
    'http://10.243.17.91:3000',
    'http://192.168.254.113:3000',
    'http://192.168.137.1:3000'
];

async function testConnectivity() {
    console.log('🔍 Testing API connectivity from different IP addresses...\n');
    
    for (const url of testUrls) {
        try {
            console.log(`Testing: ${url}`);
            
            const response = await fetch(`${url}/`, {
                method: 'GET',
                timeout: 5000
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log(`✅ ${url} - SUCCESS`);
                console.log(`   Response: ${data.message}`);
                console.log(`   Timestamp: ${data.timestamp}\n`);
            } else {
                console.log(`❌ ${url} - HTTP ${response.status}\n`);
            }
        } catch (error) {
            console.log(`❌ ${url} - FAILED`);
            console.log(`   Error: ${error.message}\n`);
        }
    }
    
    console.log('🎯 Recommendation:');
    console.log('Use the first URL that shows SUCCESS in your Flutter app configuration.');
    console.log('The app will automatically try these URLs in order until one works.');
}

// Run the test
testConnectivity();
