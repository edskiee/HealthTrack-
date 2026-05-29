const crypto = require('crypto');

// Check what password corresponds to the hash for the "admin" user
const hashes = [
  '098f6bcd4621d373cade4e832627b4f6', // admin user hash
  '21232f297a57a5a743894a0e4a801fc3'  // edwin, tano, brenda user hash
];

const commonPasswords = [
  'admin',
  'password',
  '123456',
  'test',
  'edwin'
];

console.log('Checking password hashes:');
hashes.forEach((hash, index) => {
  console.log(`\nHash ${index + 1}: ${hash}`);
  let found = false;
  
  commonPasswords.forEach(password => {
    const hashed = crypto.createHash("md5").update(password).digest("hex");
    if (hashed === hash) {
      console.log(`  -> Password: ${password}`);
      found = true;
    }
  });
  
  if (!found) {
    console.log('  -> Password not found in common list');
  }
});