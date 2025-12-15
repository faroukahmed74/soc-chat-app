import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'logger_service.dart' as Log;

/// Service for picking contacts from device
/// Handles Android 13+ granular permissions and iOS permissions
class ContactPickerService {
  static final ContactPickerService _instance = ContactPickerService._internal();
  factory ContactPickerService() => _instance;
  ContactPickerService._internal();

  /// Check and request contact permissions
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestContactPermission() async {
    try {
      if (kIsWeb) {
        Log.LoggerService.warning('Contact picker not supported on web', 'CONTACT_PICKER');
        return false;
      }

      if (Platform.isAndroid) {
        // Check Android version
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        Log.LoggerService.info('Android SDK: $sdkInt', 'CONTACT_PICKER');

        // For Android, we need READ_CONTACTS permission
        // Android 13+ (API 33+) still uses READ_CONTACTS, but with granular access
        // The flutter_contacts package handles the granular permissions internally
        
        // First check current status
        final currentStatus = await Permission.contacts.status;
        Log.LoggerService.info('Current contact permission status: $currentStatus', 'CONTACT_PICKER');
        
        if (currentStatus.isGranted) {
          Log.LoggerService.info('Contact permission already granted', 'CONTACT_PICKER');
          return true;
        }

        // Request permission
        if (sdkInt >= 33) {
          // Android 13+ (API 33+) - Granular permissions
          Log.LoggerService.info('Android 13+ detected, requesting READ_CONTACTS permission', 'CONTACT_PICKER');
        } else {
          // Android 12 and below
          Log.LoggerService.info('Android 12 or below detected, requesting READ_CONTACTS permission', 'CONTACT_PICKER');
        }
        
        final contactsStatus = await Permission.contacts.request();
        Log.LoggerService.info('Permission request result: $contactsStatus', 'CONTACT_PICKER');
        
        if (contactsStatus.isGranted) {
          Log.LoggerService.info('Contact permission granted', 'CONTACT_PICKER');
          return true;
        } else if (contactsStatus.isPermanentlyDenied) {
          Log.LoggerService.warning('Contact permission permanently denied. User needs to enable it in settings.', 'CONTACT_PICKER');
          return false;
        } else if (contactsStatus.isDenied) {
          Log.LoggerService.warning('Contact permission denied by user', 'CONTACT_PICKER');
          return false;
        } else {
          Log.LoggerService.warning('Contact permission status: $contactsStatus', 'CONTACT_PICKER');
          return false;
        }
      } else if (Platform.isIOS) {
        // iOS - Request contacts permission
        Log.LoggerService.info('iOS detected, requesting contacts permission', 'CONTACT_PICKER');
        
        // First check current status
        final currentStatus = await Permission.contacts.status;
        Log.LoggerService.info('Current contact permission status: $currentStatus', 'CONTACT_PICKER');
        
        if (currentStatus.isGranted || currentStatus == PermissionStatus.limited) {
          // iOS 18+ supports limited access
          Log.LoggerService.info('Contact permission already granted (or limited)', 'CONTACT_PICKER');
          return true;
        }
        
        // Request permission
        final contactsStatus = await Permission.contacts.request();
        Log.LoggerService.info('Permission request result: $contactsStatus', 'CONTACT_PICKER');
        
        if (contactsStatus.isGranted || contactsStatus == PermissionStatus.limited) {
          Log.LoggerService.info('Contact permission granted (or limited)', 'CONTACT_PICKER');
          return true;
        } else if (contactsStatus.isPermanentlyDenied) {
          Log.LoggerService.warning('Contact permission permanently denied. User needs to enable it in Settings > Privacy & Security > Contacts', 'CONTACT_PICKER');
          return false;
        } else if (contactsStatus.isDenied) {
          Log.LoggerService.warning('Contact permission denied by user', 'CONTACT_PICKER');
          return false;
        } else {
          Log.LoggerService.warning('Contact permission status: $contactsStatus', 'CONTACT_PICKER');
          return false;
        }
      }

      return false;
    } catch (e, stackTrace) {
      Log.LoggerService.error('Error requesting contact permission', 'CONTACT_PICKER', e, stackTrace);
      return false;
    }
  }

  /// Check if contact permission is granted
  /// Returns true if permission is granted (or limited on iOS 18+)
  Future<bool> hasContactPermission() async {
    try {
      if (kIsWeb) return false;
      
      final status = await Permission.contacts.status;
      // On iOS 18+, limited access is also acceptable for contact picking
      if (Platform.isIOS) {
        return status.isGranted || status == PermissionStatus.limited;
      }
      return status.isGranted;
    } catch (e, stackTrace) {
      Log.LoggerService.error('Error checking contact permission', 'CONTACT_PICKER', e, stackTrace);
      return false;
    }
  }

  /// Pick a contact from device
  /// Returns a Map with contact information or null if cancelled/denied
  /// Throws exception with error message if permission is denied
  Future<Map<String, dynamic>?> pickContact() async {
    try {
      if (kIsWeb) {
        Log.LoggerService.warning('Contact picker not supported on web', 'CONTACT_PICKER');
        throw Exception('Contact picker is not supported on web');
      }

      // Step 1: Check permission first using permission_handler
      final hasPermission = await hasContactPermission();
      Log.LoggerService.info('Has contact permission: $hasPermission', 'CONTACT_PICKER');
      
      if (!hasPermission) {
        Log.LoggerService.info('Permission not granted, requesting...', 'CONTACT_PICKER');
        final granted = await requestContactPermission();
        if (!granted) {
          final status = await Permission.contacts.status;
          String errorMessage;
          if (status.isPermanentlyDenied) {
            if (Platform.isAndroid) {
              errorMessage = 'Contact permission is permanently denied. Please enable it in Settings > Apps > SOC Chat App > Permissions > Contacts';
            } else {
              errorMessage = 'Contact permission is permanently denied. Please enable it in Settings > Privacy & Security > Contacts';
            }
          } else {
            errorMessage = 'Contact permission was denied. Please grant contact access to send contacts.';
          }
          Log.LoggerService.warning('Contact permission not granted: $status', 'CONTACT_PICKER');
          throw Exception(errorMessage);
        }
      }

      // Step 2: Also request permission from flutter_contacts (it may have its own permission handling)
      // This is important because flutter_contacts may need to verify permissions again
      try {
        final flutterContactsPermission = await FlutterContacts.requestPermission(readonly: true);
        if (!flutterContactsPermission) {
          Log.LoggerService.warning('FlutterContacts permission not granted', 'CONTACT_PICKER');
          throw Exception('Contact access was denied. Please grant contact permission to send contacts.');
        }
        Log.LoggerService.info('FlutterContacts permission granted', 'CONTACT_PICKER');
      } catch (e) {
        Log.LoggerService.error('Error requesting FlutterContacts permission', 'CONTACT_PICKER', e);
        // If flutter_contacts throws an error, we'll still try to open the picker
        // as the permission_handler permission might be sufficient
      }

      // Step 3: Open contact picker
      Log.LoggerService.info('Opening contact picker...', 'CONTACT_PICKER');
      final contact = await FlutterContacts.openExternalPick();
      
      if (contact == null) {
        Log.LoggerService.info('Contact picker cancelled by user', 'CONTACT_PICKER');
        return null;
      }

      // Extract contact information
      final contactData = <String, dynamic>{
        'id': contact.id,
        'displayName': contact.displayName,
        'name': {
          'first': contact.name.first,
          'last': contact.name.last,
          'middle': contact.name.middle,
          'prefix': contact.name.prefix,
          'suffix': contact.name.suffix,
        },
        'phones': contact.phones.map((phone) => {
          'number': phone.number,
          'label': phone.label.name,
          'normalizedNumber': phone.normalizedNumber,
        }).toList(),
        'emails': contact.emails.map((email) => {
          'address': email.address,
          'label': email.label.name,
        }).toList(),
        'addresses': contact.addresses.map((address) => {
          'street': address.street,
          'city': address.city,
          'region': address.state ?? '', // Use 'state' property
          'postcode': address.postalCode ?? '', // Use 'postalCode' property
          'country': address.country,
          'label': address.label.name,
        }).toList(),
        'organizations': contact.organizations.map((org) => {
          'company': org.company,
          'title': org.title,
          'department': org.department,
        }).toList(),
        'photo': contact.photo != null ? contact.photo : null,
        'thumbnail': contact.thumbnail != null ? contact.thumbnail : null,
      };

      Log.LoggerService.info('Contact picked successfully: ${contact.displayName}', 'CONTACT_PICKER');
      return contactData;
    } catch (e, stackTrace) {
      // Re-throw permission-related exceptions so caller can show appropriate message
      if (e is Exception && e.toString().contains('permission')) {
        Log.LoggerService.error('Permission error picking contact', 'CONTACT_PICKER', e, stackTrace);
        rethrow;
      }
      // For other errors, log and return null
      Log.LoggerService.error('Error picking contact', 'CONTACT_PICKER', e, stackTrace);
      return null;
    }
  }

  /// Format contact as vCard string
  String formatContactAsVCard(Map<String, dynamic> contactData) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    
    // Name
    final name = contactData['name'] as Map<String, dynamic>?;
    if (name != null) {
      final firstName = name['first'] ?? '';
      final lastName = name['last'] ?? '';
      final middleName = name['middle'] ?? '';
      final prefix = name['prefix'] ?? '';
      final suffix = name['suffix'] ?? '';
      
      buffer.writeln('FN:${contactData['displayName'] ?? ''}');
      buffer.writeln('N:$lastName;$firstName;$middleName;$prefix;$suffix');
    } else {
      buffer.writeln('FN:${contactData['displayName'] ?? ''}');
      buffer.writeln('N:${contactData['displayName'] ?? ''};;;;');
    }
    
    // Phones
    final phones = contactData['phones'] as List<dynamic>?;
    if (phones != null) {
      for (final phone in phones) {
        final number = phone['number'] ?? '';
        final label = phone['label'] ?? 'CELL';
        buffer.writeln('TEL;TYPE=$label:$number');
      }
    }
    
    // Emails
    final emails = contactData['emails'] as List<dynamic>?;
    if (emails != null) {
      for (final email in emails) {
        final address = email['address'] ?? '';
        final label = email['label'] ?? 'HOME';
        buffer.writeln('EMAIL;TYPE=$label:$address');
      }
    }
    
    // Addresses
    final addresses = contactData['addresses'] as List<dynamic>?;
    if (addresses != null) {
      for (final address in addresses) {
        final street = address['street'] ?? '';
        final city = address['city'] ?? '';
        final region = address['region'] ?? '';
        final postcode = address['postcode'] ?? '';
        final country = address['country'] ?? '';
        final label = address['label'] ?? 'HOME';
        final formattedAddress = '$street;$city;$region;$postcode;$country';
        buffer.writeln('ADR;TYPE=$label:;;$formattedAddress');
      }
    }
    
    // Organizations
    final organizations = contactData['organizations'] as List<dynamic>?;
    if (organizations != null && organizations.isNotEmpty) {
      final org = organizations[0];
      final company = org['company'] ?? '';
      final title = org['title'] ?? '';
      if (company.isNotEmpty) {
        buffer.writeln('ORG:$company');
      }
      if (title.isNotEmpty) {
        buffer.writeln('TITLE:$title');
      }
    }
    
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  /// Get primary phone number from contact
  String? getPrimaryPhone(Map<String, dynamic> contactData) {
    final phones = contactData['phones'] as List<dynamic>?;
    if (phones == null || phones.isEmpty) return null;
    
    // Try to find mobile/cell phone first
    for (final phone in phones) {
      final label = (phone['label'] ?? '').toString().toUpperCase();
      if (label.contains('MOBILE') || label.contains('CELL')) {
        return phone['number'] as String?;
      }
    }
    
    // Return first phone if no mobile found
    return phones[0]['number'] as String?;
  }

  /// Get primary email from contact
  String? getPrimaryEmail(Map<String, dynamic> contactData) {
    final emails = contactData['emails'] as List<dynamic>?;
    if (emails == null || emails.isEmpty) return null;
    return emails[0]['address'] as String?;
  }
}

