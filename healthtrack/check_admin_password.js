const crypto = require('crypto');

// Check what the hashed password would be for "admin"
const password = "admin";
const hashedPassword = crypto.createHash("md5").update(password).digest("hex");
console.log(`Password: ${password}`);
console.log(`Hashed password: ${hashedPassword}`);

// Check what the hashed password would be for "edwin"
const password2 = "edwin";
const hashedPassword2 = crypto.createHash("md5").update(password2).digest("hex");
console.log(`Password: ${password2}`);
console.log(`Hashed password: ${hashedPassword2}`);