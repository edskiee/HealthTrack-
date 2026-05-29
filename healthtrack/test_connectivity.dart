import 'dart:io';

Future<void> main() async {
  // Test if we can connect to localhost:3000
  try {
    print('Testing connection to localhost:3000');
    final socket = await Socket.connect('localhost', 3000);
    print('Successfully connected to localhost:3000');
    socket.close();
  } catch (e) {
    print('Failed to connect to localhost:3000: $e');
  }
  
  // Test if we can connect to 127.0.0.1:3000
  try {
    print('Testing connection to 127.0.0.1:3000');
    final socket = await Socket.connect('127.0.0.1', 3000);
    print('Successfully connected to 127.0.0.1:3000');
    socket.close();
  } catch (e) {
    print('Failed to connect to 127.0.0.1:3000: $e');
  }
  
  // Test if we can connect to 10.243.17.91:3000 (ZeroTier IP)
  try {
    print('Testing connection to 10.243.17.91:3000');
    final socket = await Socket.connect('10.243.17.91', 3000);
    print('Successfully connected to 10.243.17.91:3000');
    socket.close();
  } catch (e) {
    print('Failed to connect to 10.243.17.91:3000: $e');
  }
}