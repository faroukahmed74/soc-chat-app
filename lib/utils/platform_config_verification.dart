// =============================================================================
// PLATFORM CONFIGURATION VERIFICATION
// =============================================================================
// This script verifies that the platform-specific configuration is working
// correctly for web (local network) and mobile (ngrok) platforms

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/database_config.dart';

class PlatformConfigVerification {
  static void verifyConfiguration() {
    print('========================================');
    print('  Platform Configuration Verification');
    print('========================================');
    
    // Check platform detection
    print('Platform Detection:');
    print('  kIsWeb: $kIsWeb');
    print('  Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
    
    // Check configuration values
    print('\nConfiguration Values:');
    print('  webServerUrl: ${DatabaseConfig.webServerUrl}');
    print('  mobileServerUrl: ${DatabaseConfig.mobileServerUrl}');
    print('  serverUrl: ${DatabaseConfig.serverUrl}');
    
    // Check resolved URL
    final resolvedUrl = DatabaseConfig.physicalServerUrl;
    print('\nResolved URL:');
    print('  physicalServerUrl: $resolvedUrl');
    
    // Verify correct URL for platform
    final expectedWebUrl = 'http://10.120.4.230:8082';
    final expectedMobileUrl = 'https://soc-chat-app.ngrok-free.app';
    
    print('\nVerification:');
    if (kIsWeb) {
      if (resolvedUrl == expectedWebUrl) {
        print('  ✓ Web platform correctly configured for local network');
        print('  ✓ MongoDB will connect to: $expectedWebUrl');
      } else {
        print('  ✗ Web platform configuration mismatch');
        print('  Expected: $expectedWebUrl');
        print('  Actual: $resolvedUrl');
      }
    } else {
      if (resolvedUrl == expectedMobileUrl) {
        print('  ✓ Mobile platform correctly configured for ngrok');
        print('  ✓ MongoDB will connect to: $expectedMobileUrl');
      } else {
        print('  ✗ Mobile platform configuration mismatch');
        print('  Expected: $expectedMobileUrl');
        print('  Actual: $resolvedUrl');
      }
    }
    
    print('\n========================================');
  }
  
  static Widget buildVerificationWidget(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Platform Detection
            _buildInfoRow('Platform', kIsWeb ? 'Web' : 'Mobile'),
            _buildInfoRow('kIsWeb', kIsWeb.toString()),
            
            const Divider(),
            
            // Configuration URLs
            Text(
              'Configuration URLs:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Web Server URL', DatabaseConfig.webServerUrl),
            _buildInfoRow('Mobile Server URL', DatabaseConfig.mobileServerUrl),
            _buildInfoRow('Fallback Server URL', DatabaseConfig.serverUrl),
            
            const Divider(),
            
            // Resolved URL
            Text(
              'Resolved URL:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Current Platform URL', DatabaseConfig.physicalServerUrl),
            
            const Divider(),
            
            // Verification Status
            Text(
              'Verification Status:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Web Platform',
              kIsWeb && DatabaseConfig.physicalServerUrl == 'http://10.120.4.230:8082',
              'Local Network MongoDB',
            ),
            _buildStatusRow(
              'Mobile Platform',
              !kIsWeb && DatabaseConfig.physicalServerUrl == 'https://soc-chat-app.ngrok-free.app',
              'Ngrok MongoDB',
            ),
          ],
        ),
      ),
    );
  }
  
  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildStatusRow(String platform, bool isCorrect, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.error,
            color: isCorrect ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$platform: $description',
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
