import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/responsive_utils.dart';
import '../theme/app_design_system.dart';

/// Widget to display a contact message in chat
class ContactMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const ContactMessageWidget({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onTap,
  });

  /// Extract contact data from message
  Map<String, dynamic>? _getContactData() {
    try {
      // Try to get contact data from mediaUrl (if sent as JSON)
      final mediaUrl = message['mediaUrl'] ?? message['media_url'];
      if (mediaUrl != null && mediaUrl is String) {
        try {
          final decoded = jsonDecode(mediaUrl);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          // Not JSON, try to parse from content
        }
      }

      // Try to get from contactData field
      final contactData = message['contactData'];
      if (contactData != null && contactData is Map) {
        return Map<String, dynamic>.from(contactData);
      }

      // Try to parse from content if it contains contact info
      final content = message['content'] ?? '';
      if (content.toString().contains('📇 Contact:')) {
        // Extract from text content (fallback)
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactData = _getContactData();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (contactData == null) {
      // Fallback: show as text message
      final content = message['content'] ?? '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? theme.colorScheme.primary
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          content.toString(),
          style: TextStyle(
            color: isCurrentUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    final displayName = contactData['displayName'] ?? 'Unknown Contact';
    final primaryPhone = contactData['phone'] as String?;
    final primaryEmail = contactData['email'] as String?;
    final contactInfo = contactData['contactData'] as Map<String, dynamic>?;
    
    // Extract phones and emails from contactData
    final phones = contactInfo?['phones'] as List<dynamic>? ?? [];
    final emails = contactInfo?['emails'] as List<dynamic>? ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 280.0,
            tablet: 350.0,
            desktop: 400.0,
          ),
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? theme.colorScheme.primary
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            ),
          ),
          border: Border.all(
            color: isCurrentUser
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 1.0,
              tablet: 1.5,
              desktop: 2.0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with contact icon
            Container(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 16.0,
                      tablet: 18.0,
                      desktop: 20.0,
                    ),
                  ),
                  topRight: Radius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 16.0,
                      tablet: 18.0,
                      desktop: 20.0,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.contact_phone,
                    color: isCurrentUser
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    size: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 24.0,
                      tablet: 26.0,
                      desktop: 28.0,
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Contact',
                      style: TextStyle(
                        color: isCurrentUser
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 14.0,
                          mobileMultiplier: 1.0,
                          tabletMultiplier: 1.1,
                          desktopMultiplier: 1.2,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contact details
            Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 16.0,
                        mobileMultiplier: 1.0,
                        tabletMultiplier: 1.1,
                        desktopMultiplier: 1.2,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  
                  // Phone numbers
                  if (phones.isNotEmpty || primaryPhone != null) ...[
                    ...(phones.isNotEmpty 
                        ? phones.map((phone) => _buildContactRow(
                            context,
                            icon: Icons.phone,
                            label: phone['label'] ?? 'Phone',
                            value: phone['number'] ?? '',
                            isCurrentUser: isCurrentUser,
                            onTap: () => _makePhoneCall(phone['number'] ?? ''),
                          ))
                        : [
                            if (primaryPhone != null)
                              _buildContactRow(
                                context,
                                icon: Icons.phone,
                                label: 'Phone',
                                value: primaryPhone,
                                isCurrentUser: isCurrentUser,
                                onTap: () => _makePhoneCall(primaryPhone),
                              ),
                          ]),
                    const SizedBox(height: 8),
                  ],
                  
                  // Email addresses
                  if (emails.isNotEmpty || primaryEmail != null) ...[
                    ...(emails.isNotEmpty
                        ? emails.map((email) => _buildContactRow(
                            context,
                            icon: Icons.email,
                            label: email['label'] ?? 'Email',
                            value: email['address'] ?? '',
                            isCurrentUser: isCurrentUser,
                            onTap: () => _sendEmail(email['address'] ?? ''),
                          ))
                        : [
                            if (primaryEmail != null)
                              _buildContactRow(
                                context,
                                icon: Icons.email,
                                label: 'Email',
                                value: primaryEmail,
                                isCurrentUser: isCurrentUser,
                                onTap: () => _sendEmail(primaryEmail),
                              ),
                          ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isCurrentUser,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        ResponsiveUtils.getResponsiveValue(
          context,
          mobile: 8.0,
          tablet: 10.0,
          desktop: 12.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 6.0,
            tablet: 8.0,
            desktop: 10.0,
          ),
          horizontal: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
              color: isCurrentUser
                  ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                  : theme.colorScheme.primary,
            ),
            SizedBox(
              width: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 11.0,
                        mobileMultiplier: 1.0,
                        tabletMultiplier: 1.1,
                        desktopMultiplier: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 2.0,
                      tablet: 3.0,
                      desktop: 4.0,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 14.0,
                        mobileMultiplier: 1.0,
                        tabletMultiplier: 1.1,
                        desktopMultiplier: 1.2,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0,
              ),
              color: isCurrentUser
                  ? theme.colorScheme.onPrimary.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch phone call');
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
    }
  }

  Future<void> _sendEmail(String emailAddress) async {
    try {
      final uri = Uri.parse('mailto:$emailAddress');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch email');
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
    }
  }
}

