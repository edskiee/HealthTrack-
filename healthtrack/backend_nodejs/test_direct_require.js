try {
  console.log('Attempting to require server.js...');
  const server = require('./src/server.js');
  console.log('Server required successfully');
} catch (error) {
  console.error('Error requiring server.js:', error.message);
  console.error('Stack trace:', error.stack);
}