import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Comprehensive notification system test
void main() async {
  print('🧪 SOC Chat App - Notification System Test');
  print('==========================================');
  
  await _testFCMServer();
  await _testNotificationEndpoints();
  
  print('\n✅ Notification system tests completed!');
}

/// Test FCM server health
Future<void> _testFCMServer() async {
  print('\n📡 Testing FCM Server...');
  
  try {
    final response = await http.get(Uri.parse('http://localhost:3000/health'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ FCM Server: ${data['status']}');
    } else {
      print('❌ FCM Server Failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ FCM Server Error: $e');
  }
}

/// Test notification endpoints
Future<void> _testNotificationEndpoints() async {
  print('\n🔗 Testing Notification Endpoints...');
  
  // Test individual notification
  await _testEndpoint('Individual Notification', {
    'token': 'test_token',
    'title': 'Test Notification',
    'body': 'This is a test notification!',
  });
  
  // Test topic notification
  await _testEndpoint('Topic Notification', {
    'topic': 'test_topic',
    'title': 'Test Topic',
    'body': 'This is a test topic notification!',
  });
}

/// Test a specific endpoint
Future<void> _testEndpoint(String name, Map<String, dynamic> data) async {
  try {
    final response = await http.post(
      Uri.parse('http://localhost:3000/send-notification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200) {
      print('✅ $name: Success');
    } else {
      print('❌ $name: Failed');
    }
  } catch (e) {
    print('❌ $name: Error - $e');
  }
}