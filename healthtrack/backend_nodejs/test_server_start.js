const path = require('path');
console.log('Current directory:', __dirname);
console.log('Server.js path:', path.join(__dirname, 'src', 'server.js'));
console.log('Does file exist?', require('fs').existsSync(path.join(__dirname, 'src', 'server.js')));