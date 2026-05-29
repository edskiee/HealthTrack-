// Test script for IP detection
const os = require('os');

function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const interface of interfaces[name]) {
            if (interface.family === 'IPv4' && !interface.internal) {
                // Check if it's in a private network range
                const ip = interface.address;
                if (ip.startsWith('192.168.') || 
                    ip.startsWith('10.') || 
                    (ip.startsWith('172.') && 
                     parseInt(ip.split('.')[1]) >= 16 && 
                     parseInt(ip.split('.')[1]) <= 31)) {
                    return ip;
                }
            }
        }
    }
    return '127.0.0.1';
}

console.log('Local IP Address:', getLocalIP());