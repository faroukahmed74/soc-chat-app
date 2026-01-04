// =============================================================================
// MODERN LOGIN SCREEN
// =============================================================================
// Enhanced login screen with modern UI/UX, animations, and responsive design
// for all platforms (Android, iOS, Web)

import 'package:flutter/material.dart';
import 'dart:async';

import '../services/theme_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../theme/app_design_system.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_logo.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  // Services
  late ThemeService _themeService;
  late VoidCallback _themeListener;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _themeService = ThemeService.instance;
    _themeListener = () {
      if (mounted) setState(() {});
    };
    _themeService.addListener(_themeListener);

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _themeService.removeListener(_themeListener);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await PhysicalAuthService().login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result['success']) {
        Log.i('Login successful', 'MODERN_LOGIN');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/chats');
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Login failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Login error', 'MODERN_LOGIN', e);
      setState(() {
        _error = 'Login failed. Please check your credentials.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                      AppDesignSystem.neutral900,
                      AppDesignSystem.neutral800,
                    ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                      AppDesignSystem.primaryColor.withOpacity(0.1),
                      AppDesignSystem.secondaryColor.withOpacity(0.05),
                    ],
                ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : isTablet ? 48 : 64,
                vertical: 32,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 450,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo and Title
                          _buildHeader(isDark),
                          const SizedBox(height: 48),

                          // Email Field
                          _buildEmailField(isDark),
                          const SizedBox(height: 20),

                          // Password Field
                          _buildPasswordField(isDark),
                          const SizedBox(height: 8),

                          // Error Message
                          if (_error != null) _buildErrorMessage(),
                          const SizedBox(height: 24),

                          // Login Button
                          _buildLoginButton(isDark),
                          const SizedBox(height: 16),

                          // Register Link
                          _buildRegisterLink(),

                          // Theme Toggle
                          const SizedBox(height: 32),
                          _buildThemeToggle(),
                        ],
                      ),
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

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        // App Logo
        AppLogo(
          size: 80,
          showBackground: true,
          showAppName: false,
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome Back',
          style: AppDesignSystem.headlineLarge.copyWith(
            color: isDark ? AppDesignSystem.neutral50 : AppDesignSystem.neutral900,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue',
          style: AppDesignSystem.bodyLarge.copyWith(
            color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(bool isDark) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: Icon(
          Icons.email_outlined,
          color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
        ),
        filled: true,
        fillColor: isDark ? AppDesignSystem.neutral800 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(
            color: isDark ? AppDesignSystem.neutral700 : AppDesignSystem.neutral300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(
            color: isDark ? AppDesignSystem.neutral700 : AppDesignSystem.neutral300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: const BorderSide(
            color: AppDesignSystem.primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: Icon(
          Icons.lock_outline,
          color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: isDark ? AppDesignSystem.neutral800 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(
            color: isDark ? AppDesignSystem.neutral700 : AppDesignSystem.neutral300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(
            color: isDark ? AppDesignSystem.neutral700 : AppDesignSystem.neutral300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: const BorderSide(
            color: AppDesignSystem.primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(color: AppDesignSystem.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppDesignSystem.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(bool isDark) {
    return AnimatedContainer(
      duration: AppDesignSystem.animationDurationNormal,
      curve: AppDesignSystem.animationCurve,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          ),
          shadowColor: AppDesignSystem.primaryColor.withOpacity(0.3),
        ).copyWith(
          elevation: MaterialStateProperty.resolveWith<double>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) return 0;
              if (states.contains(MaterialState.disabled)) return 0;
              return 4;
            },
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: AppDesignSystem.bodyMedium.copyWith(
            color: _themeService.isDarkMode
                ? AppDesignSystem.neutral400
                : AppDesignSystem.neutral600,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/register');
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle() {
    return Center(
      child: IconButton(
        onPressed: () async {
          await _themeService.toggleTheme();
        },
        icon: Icon(
          _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: _themeService.isDarkMode
              ? AppDesignSystem.neutral400
              : AppDesignSystem.neutral600,
        ),
        tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      ),
    );
  }
}
