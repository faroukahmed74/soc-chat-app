// =============================================================================
// REGISTER SCREEN - MONGODB VERSION
// =============================================================================
// This screen handles new user registration using MongoDB
// It includes form validation and physical server authentication

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/theme_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../services/localization_service.dart';
import '../utils/responsive_utils.dart';
import '../theme/app_design_system.dart';

class RegisterScreenMongoDB extends StatefulWidget {
  const RegisterScreenMongoDB({Key? key}) : super(key: key);

  @override
  State<RegisterScreenMongoDB> createState() => _RegisterScreenMongoDBState();
}

class _RegisterScreenMongoDBState extends State<RegisterScreenMongoDB> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _error;
  String _currentLanguage = 'en';
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_displayNameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your display name.';
      });
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your email address.';
      });
      return false;
    }

    if (!_emailController.text.trim().contains('@')) {
      setState(() {
        _error = 'Please enter a valid email address.';
      });
      return false;
    }

    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your phone number.';
      });
      return false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a password.';
      });
      return false;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters long.';
      });
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _error = 'Passwords do not match.';
      });
      return false;
    }

    return true;
  }

  Future<void> _register() async {
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Use physical server registration only
      final result = await PhysicalAuthService().register(
        _emailController.text.trim(),
        _passwordController.text,
        _displayNameController.text.trim(),
        _phoneController.text.trim(),
      );

      if (result['success']) {
        // Registration successful - navigate to main app
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/chats');
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Registration failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Registration error', 'REGISTER_SCREEN_MONGODB', e);
      setState(() {
        _error = 'Registration failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.getString('register', _currentLanguage),
          style: AppDesignSystem.titleLarge.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              _themeService.toggleTheme();
              setState(() {});
            },
            tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: ResponsiveUtils.getResponsiveCardConstraints(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo/Title
                  Text(
                    AppLocalizations.getString('app_name', _currentLanguage),
                    style: ResponsiveUtils.getResponsiveHeadingStyle(
                      context,
                      weight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing / 2),
                  Text(
                    'Create your account',
                    style: ResponsiveUtils.getResponsiveBodyStyle(
                      context,
                      color: _themeService.isDarkMode 
                          ? AppDesignSystem.neutral400 
                          : AppDesignSystem.neutral600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing * 2),

                  // Display Name Field
                  TextField(
                    controller: _displayNameController,
                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.getString('display_name', _currentLanguage),
                      prefixIcon: Icon(
                        Icons.person,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  SizedBox(height: spacing),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.getString('email', _currentLanguage),
                      prefixIcon: Icon(
                        Icons.email,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                  SizedBox(height: spacing),

                  // Phone Number Field
                  TextField(
                    controller: _phoneController,
                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.getString('phone_number', _currentLanguage),
                      prefixIcon: Icon(
                        Icons.phone,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                  ),
                  SizedBox(height: spacing),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.getString('password', _currentLanguage),
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
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Confirm Password Field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.getString('confirm_password', _currentLanguage),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          size: ResponsiveUtils.getResponsiveIconSize(context),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),

                  // Error Message
                  if (_error != null) ...[
                    Container(
                      padding: EdgeInsets.all(spacing / 2),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.errorColor.withOpacity(0.1),
                        border: Border.all(
                          color: AppDesignSystem.errorColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: AppDesignSystem.errorColor,
                            size: ResponsiveUtils.getResponsiveIconSize(context),
                          ),
                          SizedBox(width: spacing / 2),
                          Expanded(
                            child: Text(
                              _error!,
                              style: ResponsiveUtils.getResponsiveBodyStyle(
                                context,
                                color: AppDesignSystem.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing),
                  ],

                  // Register Button
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveButtonHeight(context),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: spacing,
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: ResponsiveUtils.getResponsiveValue(
                                context,
                                mobile: 18.0,
                                tablet: 20.0,
                                desktop: 22.0,
                              ),
                              width: ResponsiveUtils.getResponsiveValue(
                                context,
                                mobile: 18.0,
                                tablet: 20.0,
                                desktop: 22.0,
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              AppLocalizations.getString('sign_up', _currentLanguage),
                              style: ResponsiveUtils.getResponsiveBodyStyle(
                                context,
                                color: Colors.white,
                                weight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.getString('already_have_account', _currentLanguage),
                        style: TextStyle(
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          AppLocalizations.getString('sign_in', _currentLanguage),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
