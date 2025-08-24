// =============================================================================
// LOCALIZATION SERVICE
// =============================================================================
// This service provides internationalization (i18n) support for the app.
// It includes English and Arabic translations for all UI text,
// language switching functionality, and RTL support for Arabic.

import 'package:flutter/material.dart';

// =============================================================================
// LOCALIZATION SERVICE CLASS
// =============================================================================
// Static utility class for managing supported locales and language information
class LocalizationService {
  // =============================================================================
  // SUPPORTED LOCALES
  // =============================================================================
  
  /// English locale (United States)
  static const Locale english = Locale('en');
  
  /// Arabic locale (Egypt)
  static const Locale arabic = Locale('ar');
  
  /// List of all supported locales in the app
  static const List<Locale> supportedLocales = [english, arabic];
  
  /// Default fallback language if localization fails
  static const String fallbackLanguageCode = 'en';
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Determines if a locale uses right-to-left (RTL) text direction
  /// Currently only Arabic uses RTL, but this can be extended for other languages
  /// 
  /// [locale] - The locale to check for RTL support
  /// Returns true if the locale uses RTL text direction
  static bool isRTL(Locale locale) {
    return locale.languageCode == 'ar';
  }
  
  /// Gets the human-readable name of a language
  /// This is used in language selection UI elements
  /// 
  /// [languageCode] - The language code (e.g., 'en', 'ar')
  /// Returns the localized name of the language
  static String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return 'English'; // Fallback to English
    }
  }
  
  /// Gets the flag emoji for a language
  /// This is used in language selection UI elements for visual identification
  /// 
  /// [languageCode] - The language code (e.g., 'en', 'ar')
  /// Returns the flag emoji for the language
  static String getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸'; // United States flag
      case 'ar':
        return '🇪🇬'; // Egypt flag
      default:
        return '🇺🇸'; // Fallback to US flag
    }
  }
}

// =============================================================================
// APP LOCALIZATIONS CLASS
// =============================================================================
// Static class containing all the localized strings for the app
// This class provides a centralized location for all UI text
class AppLocalizations {
  // =============================================================================
  // ENGLISH TRANSLATIONS
  // =============================================================================
  // Complete English localization for all app text
  
  /// English translations map
  /// Contains all UI strings in English language
  static const Map<String, String> en = {
    // =============================================================================
    // COMMON STRINGS
    // =============================================================================
    // Frequently used strings across the app
    
    'app_name': 'Soc Chat App',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'close': 'Close',
    'ok': 'OK',
    'yes': 'Yes',
    'no': 'No',
    'back': 'Back',
    'next': 'Next',
    'done': 'Done',
    
    // =============================================================================
    // AUTHENTICATION STRINGS
    // =============================================================================
    // Strings related to user authentication and account management
    
    'login': 'Login',
    'register': 'Register',
    'logout': 'Logout',
    'email': 'Email',
    'password': 'Password',
    'confirm_password': 'Confirm Password',
    'username': 'Username',
    'phone_number': 'Phone Number',
    'forgot_password': 'Forgot Password?',
    'dont_have_account': "Don't have an account?",
    'already_have_account': 'Already have an account?',
    'sign_up': 'Sign Up',
    'sign_in': 'Sign In',
    'account_locked': 'Account Locked',
    'account_locked_message': 'Your account has been locked by an administrator.',
    'contact_admin': 'Contact Admin',
    'sign_out': 'Sign Out',
    
    // =============================================================================
    // CHAT STRINGS
    // =============================================================================
    // Strings related to chat functionality and messaging
    
    'chats': 'Chats',
    'messages': 'Messages',
    'send_message': 'Send Message',
    'type_message': 'Type a message...',
    'new_chat': 'New Chat',
    'group_chat': 'Group Chat',
    'private_chat': 'Private Chat',
    'create_group': 'Create Group',
    'group_name': 'Group Name',
    'add_members': 'Add Members',
    'remove_member': 'Remove Member',
    'leave_group': 'Leave Group',
    'delete_group': 'Delete Group',
    'group_info': 'Group Info',
    'members': 'Members',
    'admin': 'Admin',
    'promote': 'Promote',
    
    // =============================================================================
    // MEDIA STRINGS
    // =============================================================================
    // Strings related to media handling (images, videos, audio)
    
    'camera': 'Camera',
    'gallery': 'Gallery',
    'photo': 'Photo',
    'video': 'Video',
    'document': 'Document',
    'audio': 'Audio',
    'voice_message': 'Voice Message',
    'record_audio': 'Record Audio',
    'stop_recording': 'Stop Recording',
    'play': 'Play',
    'pause': 'Pause',
    'stop': 'Stop',
    
    // =============================================================================
    // PROFILE STRINGS
    // =============================================================================
    // Strings related to user profile management
    
    'profile': 'Profile',
    'edit_profile': 'Edit Profile',
    'display_name': 'Display Name',
    'profile_picture': 'Profile Picture',
    'take_photo': 'Take Photo',
    'choose_from_gallery': 'Choose from Gallery',
    'upload_photo': 'Upload Photo',
    'remove_photo': 'Remove Photo',
    
    // =============================================================================
    // SETTINGS STRINGS
    // =============================================================================
    // Strings related to app settings and configuration
    
    'settings': 'Settings',
    'notifications': 'Notifications',
    'dark_mode': 'Dark Mode',
    'switch_to_light_mode': 'Switch to light mode',
    'switch_to_dark_mode': 'Switch to dark mode',
    'english_language': 'English language',
    'arabic_language': 'Arabic language',
    'language': 'Language',
    'privacy': 'Privacy',
    'security': 'Security',
    'about': 'About',
    'version': 'Version',
    'terms_of_service': 'Terms of Service',
    'privacy_policy': 'Privacy Policy',
    
    // =============================================================================
    // ADMIN STRINGS
    // =============================================================================
    // Strings related to administrative functions
    
    'admin_panel': 'Admin Panel',
    'dashboard': 'Dashboard',
    'users': 'Users',
    'broadcast': 'Broadcast',
    'system': 'System',
    'activity': 'Activity',
    'statistics': 'Statistics',
    'user_management': 'User Management',
    'content_moderation': 'Content Moderation',
    'system_health': 'System Health',
    'backup_export': 'Backup & Export',
    'audit_logs': 'Audit Logs',
    
    // =============================================================================
    // SEARCH STRINGS
    // =============================================================================
    // Strings related to search functionality
    
    'search': 'Search',
    'search_users': 'Search Users',
    'search_messages': 'Search Messages',
    'no_results': 'No results found',
    'search_hint': 'Search for users or messages...',
    
    // =============================================================================
    // ERROR STRINGS
    // =============================================================================
    // Strings for error messages and user feedback
    
    'error_occurred': 'An error occurred',
    'try_again': 'Try again',
    'network_error': 'Network error',
    'permission_denied': 'Permission denied',
    'file_too_large': 'File too large',
    'invalid_format': 'Invalid format',
    'upload_failed': 'Upload failed',
    'download_failed': 'Download failed',
    
    // =============================================================================
    // SUCCESS STRINGS
    // =============================================================================
    // Strings for success messages and confirmations
    
    'message_sent': 'Message sent',
    'photo_uploaded': 'Photo uploaded',
    'profile_updated': 'Profile updated',
    'group_created': 'Group created',
    'member_added': 'Member added',
    'member_removed': 'Member removed',
    'user_blocked': 'User blocked',
    'user_unblocked': 'User unblocked',
    
    // =============================================================================
    // PERMISSION STRINGS
    // =============================================================================
    // Strings related to device permissions
    
    'camera_permission': 'Camera Permission',
    'photos_permission': 'Photos Permission',
    'microphone_permission': 'Microphone Permission',
    'permission_required': 'Permission Required',
    'permission_message': 'This app needs access to continue working properly.',
    'grant_permission': 'Grant Permission',
    'open_settings': 'Open Settings',
    
    // =============================================================================
    // TIME STRINGS
    // =============================================================================
    // Strings for time-related display
    
    'now': 'Now',
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This Week',
    'last_week': 'Last Week',
    'this_month': 'This Month',
    'last_month': 'Last Month',
    'this_year': 'This Year',
    'last_year': 'Last Year',
    
    // =============================================================================
    // STATUS STRINGS
    // =============================================================================
    // Strings for user status and online presence
    
    'online': 'Online',
    'offline': 'Offline',
    'typing': 'Typing...',
    'last_seen': 'Last seen',
    'away': 'Away',
    'busy': 'Busy',
    'available': 'Available',
    
    // =============================================================================
    // ACTION STRINGS
    // =============================================================================
    // Strings for user actions and interactions
    
    'add_friend': 'Add Friend',
    'remove_friend': 'Remove Friend',
    'block_user': 'Block User',
    'unblock_user': 'Unblock User',
    'report_user': 'Report User',
    'mute_chat': 'Mute Chat',
    'unmute_chat': 'Unmute Chat',
    'pin_chat': 'Pin Chat',
    'unpin_chat': 'Unpin Chat',
    'archive_chat': 'Archive Chat',
    'unarchive_chat': 'Unarchive Chat',
    
    // =============================================================================
    // VALIDATION STRINGS
    // =============================================================================
    // Strings for form validation and error messages
    
    'required_field': 'This field is required',
    'invalid_email': 'Please enter a valid email',
    'password_too_short': 'Password must be at least 6 characters',
    'passwords_dont_match': 'Passwords do not match',
    'username_too_short': 'Username must be at least 3 characters',
    'phone_invalid': 'Please enter a valid phone number',
  };
  
  // =============================================================================
  // ARABIC TRANSLATIONS
  // =============================================================================
  // Complete Arabic localization for all app text
  
  /// Arabic translations map
  /// Contains all UI strings in Arabic language with proper RTL support
  static const Map<String, String> ar = {
    // =============================================================================
    // COMMON STRINGS - ARABIC
    // =============================================================================
    // Frequently used strings across the app in Arabic
    
    'app_name': 'تطبيق الدردشة الاجتماعي',
    'loading': 'جاري التحميل...',
    'error': 'خطأ',
    'success': 'نجح',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'delete': 'حذف',
    'edit': 'تعديل',
    'close': 'إغلاق',
    'ok': 'موافق',
    'yes': 'نعم',
    'no': 'لا',
    'back': 'رجوع',
    'next': 'التالي',
    'done': 'تم',
    
    // =============================================================================
    // AUTHENTICATION STRINGS - ARABIC
    // =============================================================================
    // Strings related to user authentication and account management in Arabic
    
    'login': 'تسجيل الدخول',
    'register': 'تسجيل',
    'logout': 'تسجيل الخروج',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'confirm_password': 'تأكيد كلمة المرور',
    'username': 'اسم المستخدم',
    'phone_number': 'رقم الهاتف',
    'forgot_password': 'نسيت كلمة المرور؟',
    'dont_have_account': 'ليس لديك حساب؟',
    'already_have_account': 'لديك حساب بالفعل؟',
    'sign_up': 'إنشاء حساب',
    'sign_in': 'تسجيل الدخول',
    'account_locked': 'الحساب مقفل',
    'account_locked_message': 'تم قفل حسابك من قبل المدير.',
    'contact_admin': 'تواصل مع المدير',
    'sign_out': 'تسجيل الخروج',
    'display_name': 'اسم العرض',
    'create_your_account': 'إنشاء حسابك',
    'profile_picture': 'صورة الملف الشخصي',
    'take_photo': 'التقاط صورة',
    'choose_from_gallery': 'اختيار من المعرض',
    'upload_photo': 'رفع صورة',
    'remove_photo': 'إزالة الصورة',
    'account_created': 'تم إنشاء الحساب بنجاح',
    'account_creation_failed': 'فشل في إنشاء الحساب',
    'password_requirements': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
    'email_already_exists': 'البريد الإلكتروني موجود بالفعل',
    'invalid_phone_format': 'تنسيق رقم الهاتف غير صحيح',
    'network_error_try_again': 'خطأ في الشبكة. يرجى المحاولة مرة أخرى.',
    'verification_sent': 'تم إرسال بريد التحقق',
    'please_verify_email': 'يرجى التحقق من عنوان بريدك الإلكتروني',
    
    // =============================================================================
    // SETTINGS STRINGS - ARABIC
    // =============================================================================
    // Strings related to app settings and configuration in Arabic
    
    'settings': 'الإعدادات',
    'notifications': 'الإشعارات',
    'dark_mode': 'الوضع المظلم',
    'light_mode': 'الوضع المضيء',
    'switch_to_light_mode': 'التبديل إلى الوضع المضيء',
    'switch_to_dark_mode': 'التبديل إلى الوضع المظلم',
    'english_language': 'اللغة الإنجليزية',
    'arabic_language': 'اللغة العربية',
    'language': 'اللغة',
    'privacy': 'الخصوصية',
    'security': 'الأمان',
    'about': 'حول',
    'version': 'الإصدار',
    'terms_of_service': 'شروط الخدمة',
    'privacy_policy': 'سياسة الخصوصية',
    
    // =============================================================================
    // ADMIN STRINGS - ARABIC
    // =============================================================================
    // Strings related to administrative functions in Arabic
    
    'admin_panel': 'لوحة المدير',
    'dashboard': 'لوحة التحكم',
    'users': 'المستخدمون',
    'broadcast': 'بث',
    'system': 'النظام',
    'activity': 'النشاط',
    'statistics': 'الإحصائيات',
    'user_management': 'إدارة المستخدمين',
    'content_moderation': 'إدارة المحتوى',
    'system_health': 'صحة النظام',
    'backup_export': 'النسخ الاحتياطي والتصدير',
    'audit_logs': 'سجلات التدقيق',
    
    // =============================================================================
    // SEARCH STRINGS - ARABIC
    // =============================================================================
    // Strings related to search functionality in Arabic
    
    'search': 'بحث',
    'search_users': 'البحث عن المستخدمين',
    'search_messages': 'البحث في الرسائل',
    'no_results': 'لا توجد نتائج',
    'search_hint': 'البحث عن المستخدمين أو الرسائل...',
    
    // =============================================================================
    // ERROR STRINGS - ARABIC
    // =============================================================================
    // Strings for error messages and user feedback in Arabic
    
    'error_occurred': 'حدث خطأ',
    'try_again': 'حاول مرة أخرى',
    'network_error': 'خطأ في الشبكة',
    'permission_denied': 'تم رفض الإذن',
    'file_too_large': 'الملف كبير جداً',
    'invalid_format': 'تنسيق غير صحيح',
    'upload_failed': 'فشل الرفع',
    'download_failed': 'فشل التحميل',
    
    // =============================================================================
    // SUCCESS STRINGS - ARABIC
    // =============================================================================
    // Strings for success messages and confirmations in Arabic
    
    'message_sent': 'تم إرسال الرسالة',
    'photo_uploaded': 'تم رفع الصورة',
    'profile_updated': 'تم تحديث الملف الشخصي',
    'group_created': 'تم إنشاء المجموعة',
    'member_added': 'تم إضافة العضو',
    'member_removed': 'تم إزالة العضو',
    'user_blocked': 'تم حظر المستخدم',
    'user_unblocked': 'تم إلغاء حظر المستخدم',
    
    // =============================================================================
    // PERMISSION STRINGS - ARABIC
    // =============================================================================
    // Strings related to device permissions in Arabic
    
    'camera_permission': 'إذن الكاميرا',
    'photos_permission': 'إذن الصور',
    'microphone_permission': 'إذن الميكروفون',
    'permission_required': 'الإذن مطلوب',
    'permission_message': 'هذا التطبيق يحتاج إلى إذن للاستمرار في العمل بشكل صحيح.',
    'grant_permission': 'منح الإذن',
    'open_settings': 'فتح الإعدادات',
    
    // =============================================================================
    // TIME STRINGS - ARABIC
    // =============================================================================
    // Strings for time-related display in Arabic
    
    'now': 'الآن',
    'today': 'اليوم',
    'yesterday': 'أمس',
    'this_week': 'هذا الأسبوع',
    'last_week': 'الأسبوع الماضي',
    'this_month': 'هذا الشهر',
    'last_month': 'الشهر الماضي',
    'this_year': 'هذا العام',
    'last_year': 'العام الماضي',
    
    // =============================================================================
    // STATUS STRINGS - ARABIC
    // =============================================================================
    // Strings for user status and online presence in Arabic
    
    'online': 'متصل',
    'offline': 'غير متصل',
    'typing': 'يكتب...',
    'last_seen': 'آخر ظهور',
    'away': 'غائب',
    'busy': 'مشغول',
    'available': 'متاح',
    
    // =============================================================================
    // ACTION STRINGS - ARABIC
    // =============================================================================
    // Strings for user actions and interactions in Arabic
    
    'add_friend': 'إضافة صديق',
    'remove_friend': 'إزالة صديق',
    'block_user': 'حظر المستخدم',
    'unblock_user': 'إلغاء حظر المستخدم',
    'report_user': 'الإبلاغ عن المستخدم',
    'mute_chat': 'كتم المحادثة',
    'unmute_chat': 'إلغاء كتم المحادثة',
    'pin_chat': 'تثبيت المحادثة',
    'unpin_chat': 'إلغاء تثبيت المحادثة',
    'archive_chat': 'أرشفة المحادثة',
    'unarchive_chat': 'إلغاء أرشفة المحادثة',
    
    // =============================================================================
    // VALIDATION STRINGS - ARABIC
    // =============================================================================
    // Strings for form validation and error messages in Arabic
    
    'required_field': 'هذا الحقل مطلوب',
    'invalid_email': 'يرجى إدخال بريد إلكتروني صحيح',
    'password_too_short': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
    'passwords_dont_match': 'كلمات المرور غير متطابقة',
    'username_too_short': 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
    'phone_invalid': 'يرجى إدخال رقم هاتف صحيح',
  };
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Gets a localized string by key and language code
  /// This is the main method for retrieving localized text
  /// 
  /// [key] - The string key to look up
  /// [languageCode] - The language code ('en' or 'ar')
  /// Returns the localized string or the key if not found
  static String getString(String key, String languageCode) {
    // Select the appropriate translation map
    final translations = languageCode == 'ar' ? ar : en;
    
    // Return the translation or fallback to English, then to the key itself
    return translations[key] ?? en[key] ?? key;
  }
  
  /// Gets a localized string by key and locale
  /// Convenience method that extracts language code from locale
  /// 
  /// [key] - The string key to look up
  /// [locale] - The locale object containing language information
  /// Returns the localized string or the key if not found
  static String getStringFromLocale(String key, Locale locale) {
    return getString(key, locale.languageCode);
  }
}
