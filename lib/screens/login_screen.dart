// =============================================================================
// LOGIN SCREEN
// =============================================================================
// This screen handles user authentication and login functionality.
// It includes account locking detection, theme/language toggles,
// and proper error handling for various authentication scenarios.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/localization_service.dart';
import '../services/theme_service.dart';

// =============================================================================
// LOGIN SCREEN WIDGET
// =============================================================================
// Main widget for the login screen with state management
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// =============================================================================
// LOGIN SCREEN STATE
// =============================================================================
// Manages the login screen state including form data, loading states,
// error handling, and account locking detection
class _LoginScreenState extends State<LoginScreen> {
  // =============================================================================
  // CONTROLLERS & STATE VARIABLES
  // =============================================================================
  
  /// Controller for the email input field
  final _emailController = TextEditingController();
  
  /// Controller for the password input field
  final _passwordController = TextEditingController();
  
  /// Whether the login process is currently in progress
  bool _isLoading = false;
  
  /// Current error message to display (if any)
  String? _error;
  
  /// Whether the current account is locked
  bool _isAccountLocked = false;
  
  /// Email of the locked account (for display purposes)
  String? _lockedAccountEmail;
  
  /// Service for managing app theme (light/dark mode)
  late ThemeService _themeService;
  
  /// Theme change listener callback
  late VoidCallback _themeListener;
  
  /// Current language code for localization
  late String _currentLanguage;
  
  /// Whether the password is currently visible or hidden
  bool _obscurePassword = true;

  // =============================================================================
  // INITIALIZATION & CLEANUP
  // =============================================================================
  
  @override
  void initState() {
    super.initState();
    
    // Initialize theme service for managing app appearance
    _themeService = ThemeService.instance;
    _themeListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _themeService.addListener(_themeListener);
    
    // Set current language from theme service
    _currentLanguage = 'en';
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    _themeService.removeListener(_themeListener);
    super.dispose();
  }

  // =============================================================================
  // AUTHENTICATION METHODS
  // =============================================================================
  
  /// Handles the user sign-in process
  /// This method validates input, attempts Firebase authentication,
  /// and checks for account locking status
  Future<void> _signIn() async {
    // Validate input fields
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Attempt Firebase authentication
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        // Check if account is locked in Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['disabled'] == true) {
          // Account is locked - sign out and show locked message
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isAccountLocked = true;
            _lockedAccountEmail = user.email;
            _isLoading = false;
          });
          return;
        }

        // Account not locked - proceed to main app
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/chats');
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase authentication errors
      String errorMessage = 'Login failed.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with that email address.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'Please provide a valid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message}';
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      // Handle general errors
      setState(() {
        _error = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }

  // =============================================================================
  // UI HELPER METHODS
  // =============================================================================
  
  /// Shows a dialog with contact admin information
  /// This is displayed when a user's account is locked
  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.getString('contact_admin', _currentLanguage)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To unlock your account, please contact an administrator with:'),
            const SizedBox(height: 16),
            Text('• Your email address: ${_lockedAccountEmail ?? 'N/A'}'),
            Text('• Reason for unlocking'),
            Text('• Any additional context'),
            const SizedBox(height: 16),
            Text(
              'You can also try contacting support if you believe this was done in error.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.getString('ok', _currentLanguage)),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // BUILD METHOD
  // =============================================================================
  // Builds the complete login screen UI with proper theming,
  // localization, and responsive design
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate responsive dimensions
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
    final isLargeScreen = screenWidth >= 900;
    
    // Responsive sizing
    final cardPadding = isSmallScreen ? 16.0 : isMediumScreen ? 24.0 : 32.0;
    final outerPadding = isSmallScreen ? 16.0 : isMediumScreen ? 20.0 : 24.0;
    final iconSize = isSmallScreen ? 48.0 : isMediumScreen ? 56.0 : 64.0;
    final titleFontSize = isSmallScreen ? 22.0 : isMediumScreen ? 26.0 : 28.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : isMediumScreen ? 15.0 : 16.0;
    final buttonHeight = isSmallScreen ? 48.0 : 52.0;
    
    return Scaffold(
      // =============================================================================
      // APP BAR
      // =============================================================================
      appBar: AppBar(
        title: Text(AppLocalizations.getString('login', _currentLanguage)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // =============================================================================
          // THEME TOGGLE BUTTON
          // =============================================================================
          // Allows users to switch between light and dark themes
          IconButton(
            onPressed: () {
              _themeService.toggleTheme();
              setState(() {});
            },
            icon: Icon(
              _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          
          // =============================================================================
          // LANGUAGE SELECTOR - REMOVED DUE TO ISSUES
          // =============================================================================
          // Temporarily removed until language switching issues are resolved
        ],
      ),
      
      // =============================================================================
      // BODY
      // =============================================================================
      body: Container(
        // Gradient background for visual appeal
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(outerPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLargeScreen ? 500 : double.infinity,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =============================================================================
                        // APP LOGO SECTION
                        // =============================================================================
                        Icon(
                          Icons.chat_bubble,
                          size: iconSize,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        
                        // App title with localization
                        Text(
                          AppLocalizations.getString('app_name', _currentLanguage),
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        
                        // Welcome subtitle
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 32),
                        
                        // =============================================================================
                        // ACCOUNT LOCKED MESSAGE
                        // =============================================================================
                        // Displayed when a user's account has been locked
                        if (_isAccountLocked) ...[
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                // Lock icon
                                Icon(
                                  Icons.lock,
                                  size: isSmallScreen ? 24 : 32,
                                  color: Colors.red.shade600,
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                
                                // Locked message
                                Text(
                                  AppLocalizations.getString('account_locked', _currentLanguage),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                
                                // Locked reason
                                Text(
                                  AppLocalizations.getString('account_locked_message', _currentLanguage),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                
                                // Action buttons - Responsive layout
                                if (isSmallScreen) ...[
                                  // Stacked layout for small screens
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _isAccountLocked = false;
                                              _lockedAccountEmail = null;
                                            });
                                          },
                                          child: Text(AppLocalizations.getString('back', _currentLanguage)),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _showContactAdminDialog,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(AppLocalizations.getString('contact_admin', _currentLanguage)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  // Side-by-side layout for larger screens
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _isAccountLocked = false;
                                              _lockedAccountEmail = null;
                                            });
                                          },
                                          child: Text(AppLocalizations.getString('back', _currentLanguage)),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _showContactAdminDialog,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(AppLocalizations.getString('contact_admin', _currentLanguage)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                        ],
                        
                        // =============================================================================
                        // LOGIN FORM
                        // =============================================================================
                        // Only show login form if account is not locked
                        if (!_isAccountLocked) ...[
                          // Email input field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.getString('email', _currentLanguage),
                              hintText: 'Enter your email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Password input field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.getString('password', _currentLanguage),
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20 : 24),
                          
                          // =============================================================================
                          // ERROR MESSAGE DISPLAY
                          // =============================================================================
                          // Shows authentication errors to the user
                          if (_error != null) ...[
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error, 
                                    color: Colors.red.shade600,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: isSmallScreen ? 13 : 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                          ],
                          
                          // =============================================================================
                          // LOGIN BUTTON
                          // =============================================================================
                          // Primary action button for user authentication
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: isSmallScreen ? 18 : 20,
                                      height: isSmallScreen ? 18 : 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      AppLocalizations.getString('sign_in', _currentLanguage),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 15 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20 : 24),
                          
                          // =============================================================================
                          // REGISTRATION LINK
                          // =============================================================================
                          // Allows new users to navigate to registration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  AppLocalizations.getString('dont_have_account', _currentLanguage),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/register'),
                                child: Text(
                                  AppLocalizations.getString('sign_up', _currentLanguage),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
