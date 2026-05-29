import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Test direct socket connection
  try {
    print('Testing direct socket connection to localhost:3000');
    final socket = await Socket.connect('localhost', 3000);
    print('Socket connection successful');
    
    // Send HTTP request manually
    final request = 'POST /admin/login HTTP/1.1\r\n'
        'Host: localhost:3000\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: 35\r\n'
        '\r\n'
        '{"username":"admin","password":"test"}';
    
    socket.write(request);
    
    // Read response
    final response = await utf8.decoder.bind(socket).join();
    print('Raw response: $response');
    
    socket.close();
  } catch (e) {
    print('Socket connection failed: $e');
  }
  
  // Test with http client
  try {
    print('\nTesting with HTTP client');
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('http://localhost:3000/admin/login'));
    request.headers.set('Content-Type', 'application/json');
    request.write('{"username":"admin","password":"test"}');
    
    final response = await request.close();
    print('Status code: ${response.statusCode}');
    
    final body = await utf8.decoder.bind(response).join();
    print('Response body: $body');
    
    client.close();
  } catch (e) {
    print('HTTP client failed: $e');
  }
}