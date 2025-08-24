// =============================================================================
// THEME SERVICE
// =============================================================================
// This service manages the app's theme (light/dark mode) and language settings.
// It provides a centralized way to control app appearance and localization
// with persistent storage across app sessions.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// THEME SERVICE CLASS
// =============================================================================
// Main service class that extends ChangeNotifier to provide reactive updates
// when theme or language settings change
class ThemeService extends ChangeNotifier {
  // =============================================================================
  // SINGLETON INSTANCE
  // =============================================================================
  
  static ThemeService? _instance;
  static ThemeService get instance {
    _instance ??= ThemeService._internal();
    return _instance!;
  }
  
  // =============================================================================
  // CONSTANTS & KEYS
  // =============================================================================
  
  /// Storage key for theme mode preference
  static const String _themeKey = 'theme_mode';
  
  /// Storage key for language preference
  static const String _languageKey = 'language';
  
  // =============================================================================
  // PRIVATE STATE VARIABLES
  // =============================================================================
  
  /// Current theme mode (light, dark, or system)
  ThemeMode _themeMode = ThemeMode.light;
  
  /// Current locale for internationalization
  Locale _locale = const Locale('en');
  
  // =============================================================================
  // PUBLIC GETTERS
  // =============================================================================
  
  /// Getter for current theme mode
  ThemeMode get themeMode => _themeMode;
  
  /// Getter for current locale
  Locale get locale => _locale;
  
  /// Getter for whether dark mode is currently active
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  /// Getter for whether Arabic language is currently selected
  bool get isArabic => _locale.languageCode == 'ar';
  
  // =============================================================================
  // LIGHT THEME CONFIGURATION
  // =============================================================================
  // Complete theme configuration for light mode with Material 3 design
  
  /// Light theme configuration with blue accent colors
  static final ThemeData lightTheme = ThemeData(
    // Enable Material 3 design system
    useMaterial3: true,
    
    // Set brightness to light
    brightness: Brightness.light,
    
    // Generate color scheme from seed color with fallback
    colorScheme: _generateSafeColorScheme(const Color(0xFF667eea), Brightness.light),
    
    // App bar styling
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF667eea),
      foregroundColor: Colors.white,
      elevation: 0, // Flat design
    ),
    
    // Card styling
    cardTheme: CardThemeData(
      elevation: 2, // Subtle shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Elevated button styling
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    // Outlined button styling
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF667eea),
        side: const BorderSide(color: Color(0xFF667eea)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    // Input field styling
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF667eea)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    
    // Floating action button styling
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF667eea),
      foregroundColor: Colors.white,
    ),
    
    // Scaffold background color for light mode
    scaffoldBackgroundColor: Colors.white,
  );
  
  // =============================================================================
  // DARK THEME CONFIGURATION
  // =============================================================================
  // Complete theme configuration for dark mode with Material 3 design
  
  /// Dark theme configuration with blue accent colors
  static final ThemeData darkTheme = ThemeData(
    // Enable Material 3 design system
    useMaterial3: true,
    
    // Set brightness to dark
    brightness: Brightness.dark,
    
    // Generate color scheme from seed color with fallback
    colorScheme: _generateSafeColorScheme(const Color(0xFF667eea), Brightness.dark),
    
    // App bar styling for dark mode
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1a1a1a), // Dark background
      foregroundColor: Colors.white,
      elevation: 0, // Flat design
    ),
    
    // Card styling for dark mode
    cardTheme: CardThemeData(
      elevation: 2, // Subtle shadow
      color: const Color(0xFF2a2a2a), // Dark card background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Elevated button styling (same as light theme)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    // Outlined button styling (same as light theme)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF667eea),
        side: const BorderSide(color: Color(0xFF667eea)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    // Input field styling for dark mode
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF667eea)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade600),
      ),
      filled: true, // Fill input background
      fillColor: const Color(0xFF2a2a2a), // Dark fill color
    ),
    
    // Floating action button styling (same as light theme)
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF667eea),
      foregroundColor: Colors.white,
    ),
    
    // Scaffold background color for dark mode
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
  );
  
  // =============================================================================
  // INITIALIZATION
  // =============================================================================
  
  /// Private constructor for singleton pattern
  ThemeService._internal();
  
  /// Constructor that initializes the service and loads saved settings
  /// Use ThemeService.instance instead of ThemeService()
  @Deprecated('Use ThemeService.instance instead')
  ThemeService();
  
  /// Initialize the theme service and load saved settings
  /// This method should be called before using the service
  Future<void> initialize() async {
    await _loadSettings();
  }
  
  // =============================================================================
  // PRIVATE METHODS
  // =============================================================================
  
  /// Loads theme and language settings from persistent storage
  /// This method is called during initialization to restore user preferences
  Future<void> _loadSettings() async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode from storage
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeMode = ThemeMode.values[themeIndex];
      
      // Load language from storage
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _locale = Locale(languageCode);
      
      // Notify listeners of the loaded settings
      notifyListeners();
    } catch (e) {
      // If loading fails, use default values
      print('Error loading theme settings: $e');
      _themeMode = ThemeMode.light;
      _locale = const Locale('en');
    }
  }
  
  // =============================================================================
  // PUBLIC THEME METHODS
  // =============================================================================
  
  /// Toggles between light and dark themes
  /// This method switches the current theme and saves the preference
  Future<void> toggleTheme() async {
    try {
      // Switch theme mode
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.index);
      
      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      print('Error toggling theme: $e');
    }
  }
  
  /// Sets the theme to a specific mode
  /// This method allows setting the theme to light, dark, or system
  /// 
  /// [mode] - The ThemeMode to set (light, dark, or system)
  Future<void> setTheme(ThemeMode mode) async {
    try {
      // Update theme mode
      _themeMode = mode;
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
      
      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      print('Error setting theme: $e');
    }
  }
  
  // =============================================================================
  // PUBLIC LANGUAGE METHODS
  // =============================================================================
  
  /// Toggles between English and Arabic languages
  /// This method switches the current language and saves the preference
  Future<void> toggleLanguage() async {
    try {
      // Switch language
      _locale = _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, _locale.languageCode);
      
      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      print('Error toggling language: $e');
    }
  }
  
  /// Sets the language to a specific language code
  /// This method allows setting the language to any supported language
  /// 
  /// [languageCode] - The language code to set (e.g., 'en', 'ar')
  Future<void> setLanguage(String languageCode) async {
    try {
      // Update language
      _locale = Locale(languageCode);
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      
      // Log the language change for debugging
      print('Language changed to: $languageCode');
      
      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      print('Error setting language: $e');
      // Even if saving fails, update the locale and notify listeners
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }
  
  // =============================================================================
  // PRIVATE HELPER METHODS
  // =============================================================================
  
  /// Generates a safe color scheme with fallback colors
  /// This prevents the red screen issue on some devices/tablets
  /// 
  /// [seedColor] - The primary color to use
  /// [brightness] - Whether to use light or dark theme
  /// Returns a safe ColorScheme that won't cause rendering issues
  static ColorScheme _generateSafeColorScheme(Color seedColor, Brightness brightness) {
    try {
      // Try to generate from seed color
      return ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
    } catch (e) {
      print('Error generating color scheme from seed, using fallback: $e');
      
      // Fallback to a safe, predefined color scheme
      if (brightness == Brightness.light) {
        return const ColorScheme.light(
          primary: Color(0xFF667eea),
          secondary: Color(0xFF764ba2),
          surface: Colors.white,
          error: Color(0xFFB00020),
        );
      } else {
        return const ColorScheme.dark(
          primary: Color(0xFF667eea),
          secondary: Color(0xFF764ba2),
          surface: Color(0xFF2a2a2a),
          error: Color(0xFFCF6679),
        );
      }
    }
  }
}
