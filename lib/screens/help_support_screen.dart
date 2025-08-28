import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help and Support Screen
/// Provides comprehensive help, FAQ, and support options for users
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  Map<String, bool> _isExpanded = {};

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            
            // Quick Help
            _buildQuickHelp(),
            const SizedBox(height: 24),
            
            // FAQ Section
            _buildFAQSection(),
            const SizedBox(height: 24),
            
            // Contact Support
            _buildContactSupport(),
            const SizedBox(height: 24),
            
            // App Information
            _buildAppInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Welcome to SOC Chat App Support',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re here to help you get the most out of your chat experience. Find answers to common questions, get support, and learn about app features.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHelp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Help',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickHelpCard(
          'Getting Started',
          'Learn the basics of using SOC Chat App',
          Icons.play_circle_outline,
          () => _showGettingStarted(),
        ),
        const SizedBox(height: 8),
        _buildQuickHelpCard(
          'Media & Files',
          'How to send photos, videos, and documents',
          Icons.perm_media,
          () => _showMediaHelp(),
        ),
        const SizedBox(height: 8),
        _buildQuickHelpCard(
          'Notifications',
          'Configure and troubleshoot notifications',
          Icons.notifications,
          () => _showNotificationHelp(),
        ),
        const SizedBox(height: 8),
        _buildQuickHelpCard(
          'Privacy & Security',
          'Learn about your privacy and security settings',
          Icons.security,
          () => _showPrivacyHelp(),
        ),
      ],
    );
  }

  Widget _buildQuickHelpCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQSection() {
    final faqs = [
      {
        'question': 'How do I send a photo or video?',
        'answer': 'Tap the camera icon in the chat input area. You can choose to take a new photo/video or select from your gallery. Make sure to grant camera and photo permissions when prompted.',
      },
      {
        'question': 'Why am I not receiving notifications?',
        'answer': 'Check your device notification settings and ensure SOC Chat App has permission to send notifications. Also, make sure you\'re logged in and have a stable internet connection.',
      },
      {
        'question': 'How do I create a group chat?',
        'answer': 'Go to the main chat list, tap the "+" button, and select "Create Group". Add members and give your group a name.',
      },
      {
        'question': 'Can I delete messages?',
        'answer': 'Yes, you can delete your own messages by long-pressing on them and selecting "Delete". Deleted messages are removed for all participants.',
      },
      {
        'question': 'How do I change my profile picture?',
        'answer': 'Go to your profile screen and tap on your current profile picture. You can then select a new image from your gallery or take a new photo.',
      },
      {
        'question': 'Is my data secure?',
        'answer': 'Yes, SOC Chat App uses end-to-end encryption for messages and follows industry-standard security practices to protect your data.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...faqs.map((faq) => _buildFAQItem(faq['question']!, faq['answer']!)).toList(),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    // final isExpanded = _isExpanded[question] ?? false;
    
    return Card(
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded[question] = expanded;
          });
        },
      ),
    );
  }

  Widget _buildContactSupport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Feedback Form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe your issue or suggestion...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendFeedback,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Contact Options
        _buildContactOption(
          'Email Support',
          'support@socchatapp.com',
          Icons.email,
          () => _launchEmail(),
        ),
        const SizedBox(height: 8),
        _buildContactOption(
          'Report Bug',
          'Report technical issues',
          Icons.bug_report,
          () => _reportBug(),
        ),
        const SizedBox(height: 8),
        _buildContactOption(
          'Feature Request',
          'Suggest new features',
          Icons.lightbulb,
          () => _requestFeature(),
        ),
      ],
    );
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAppInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', '1.0.1'),
            _buildInfoRow('Build', '4'),
            _buildInfoRow('Platform', 'Cross-platform'),
            _buildInfoRow('Last Updated', 'August 26, 2025'),
            const SizedBox(height: 12),
            const Text(
              'SOC Chat App - Secure, fast, and reliable messaging for everyone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Help Methods
  void _showGettingStarted() {
    _showHelpDialog(
      'Getting Started',
      'Welcome to SOC Chat App! Here\'s how to get started:\n\n'
      '1. Create an account or log in\n'
      '2. Allow camera and notification permissions\n'
      '3. Start chatting with friends\n'
      '4. Create groups for team communication\n'
      '5. Send photos, videos, and documents\n\n'
      'Need more help? Check out our FAQ section below!',
    );
  }

  void _showMediaHelp() {
    _showHelpDialog(
      'Media & Files',
      'Sending media is easy:\n\n'
      '📷 Photos: Tap the camera icon → Choose camera or gallery\n'
      '🎥 Videos: Tap the video icon → Record or select from gallery\n'
      '📄 Documents: Tap the attachment icon → Select files\n'
      '🎤 Voice: Tap and hold the microphone button\n\n'
      'Make sure to grant the necessary permissions when prompted.',
    );
  }

  void _showNotificationHelp() {
    _showHelpDialog(
      'Notifications',
      'To receive notifications:\n\n'
      '1. Allow notification permissions when prompted\n'
      '2. Check your device settings if notifications aren\'t working\n'
      '3. Ensure you\'re logged in and connected to the internet\n'
      '4. Try the notification test in Settings → Test Notifications\n\n'
      'If issues persist, contact our support team.',
    );
  }

  void _showPrivacyHelp() {
    _showHelpDialog(
      'Privacy & Security',
      'Your privacy is important to us:\n\n'
      '🔒 End-to-end encryption for all messages\n'
      '🛡️ Secure data storage and transmission\n'
      '👤 You control your personal information\n'
      '🚫 No data mining or tracking\n'
      '🔐 Regular security updates\n\n'
      'For more details, check our Privacy Policy.',
    );
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _sendFeedback() {
    final feedback = _feedbackController.text.trim();
    if (feedback.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    // Copy feedback to clipboard
    Clipboard.setData(ClipboardData(text: feedback));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback copied to clipboard. Please email it to support@socchatapp.com'),
        duration: Duration(seconds: 5),
      ),
    );
    
    _feedbackController.clear();
  }

  void _launchEmail() {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@socchatapp.com',
      query: 'subject=SOC Chat App Support Request',
    );
    _launchUrl(emailUri);
  }

  void _reportBug() {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@socchatapp.com',
      query: 'subject=Bug Report - SOC Chat App',
    );
    _launchUrl(emailUri);
  }

  void _requestFeature() {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@socchatapp.com',
      query: 'subject=Feature Request - SOC Chat App',
    );
    _launchUrl(emailUri);
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
