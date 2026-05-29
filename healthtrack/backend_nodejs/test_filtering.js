const db = require('./src/config/db');

async function testFiltering() {
  try {
    console.log('Testing service filtering...');
    
    // Test 1: Get all services
    console.log('\n1. Getting all services:');
    let [allResults] = await db.execute("SELECT * FROM services_config WHERE is_enabled = 1");
    console.log(`Total services: ${allResults.length}`);
    allResults.forEach(r => console.log(`  - ${r.id}: ${r.service_name} (${r.service_type})`));
    
    // Test 2: Filter by immunization
    console.log('\n2. Filtering by immunization:');
    let [immResults] = await db.execute("SELECT * FROM services_config WHERE is_enabled = 1 AND service_type = ?", ['immunization']);
    console.log(`Immunization services: ${immResults.length}`);
    immResults.forEach(r => console.log(`  - ${r.id}: ${r.service_name} (${r.service_type})`));
    
    // Test 3: Using the exact same query as in the controller
    console.log('\n3. Using controller query pattern:');
    const service_type = 'immunization';
    let sql = "SELECT * FROM services_config WHERE is_enabled = 1";
    let params = [];
    
    if (service_type) {
      sql += " AND service_type = ?";
      params.push(service_type);
    }
    
    console.log(`Query: ${sql}`);
    console.log(`Params: ${params}`);
    let [filteredResults] = await db.execute(sql, params);
    console.log(`Filtered services: ${filteredResults.length}`);
    filteredResults.forEach(r => console.log(`  - ${r.id}: ${r.service_name} (${r.service_type})`));
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

testFiltering();