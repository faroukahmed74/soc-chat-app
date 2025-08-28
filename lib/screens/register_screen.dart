// =============================================================================
// REGISTER SCREEN
// =============================================================================
// This screen handles new user registration and account creation.
// It includes profile picture upload, form validation, and Firebase authentication.
// The screen supports both mobile and web platforms with appropriate media handling.
//
// KEY FEATURES:
// - User registration with email/password
// - Profile picture upload (camera/gallery)
// - Form validation and error handling
// - Cross-platform media support
// - Responsive design for different screen sizes
//
// ARCHITECTURE:
// - Uses UnifiedMediaService for platform-agnostic media operations
// - Implements form validation with real-time feedback
// - Handles Firebase Auth and Firestore user creation
// - Supports profile picture storage in Firebase Storage
//
// PLATFORM SUPPORT:
// - Web: Uses web file picker and canvas for image processing
// - Mobile: Native camera/gallery access with permissions
// - Cross-platform: Unified interface for all platforms

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/unified_media_service.dart';
import '../services/localization_service.dart';
import '../services/theme_service.dart';

// =============================================================================
// REGISTER SCREEN WIDGET
// =============================================================================
// Main widget for user registration with state management
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// =============================================================================
// REGISTER SCREEN STATE
// =============================================================================
// Manages the registration screen state including form data, media uploads,
// loading states, and error handling
class _RegisterScreenState extends State<RegisterScreen> {
  // =============================================================================
  // CONTROLLERS & STATE VARIABLES
  // =============================================================================
  
  /// Controller for the display name input field
  final _displayNameController = TextEditingController();
  
  /// Controller for the email input field
  final _emailController = TextEditingController();
  
  /// Controller for the phone number input field
  final _phoneController = TextEditingController();
  
  /// Controller for the password input field
  final _passwordController = TextEditingController();
  
  /// Controller for the confirm password input field
  final _confirmPasswordController = TextEditingController();
  
  /// Whether the registration process is currently in progress
  bool _isLoading = false;
  
  /// Current error message to display (if any)
  String? _error;
  
  /// Whether the password is currently visible or hidden
  bool _obscurePassword = true;
  
  /// Whether the confirm password is currently visible or hidden
  bool _obscureConfirmPassword = true;
  
  /// Profile picture data as bytes (for upload)
  Uint8List? _profileImageBytes;
  
  /// URL of the uploaded profile picture
  String? _photoUrl;
  
  /// Upload progress indicator (0.0 to 1.0)
  double _uploadProgress = 0.0;
  
  /// Whether an upload is currently in progress
  bool _isUploading = false;
  
  /// Service for managing app theme (light/dark mode)
  late ThemeService _themeService;
  
  /// Theme change listener callback
  late VoidCallback _themeListener;
  
  /// Current language code for localization
  late String _currentLanguage;

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
    
    // Set current language to English only to prevent switching issues
    _currentLanguage = 'en';
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _themeService.removeListener(_themeListener);
    super.dispose();
  }

  // =============================================================================
  // FORM VALIDATION METHODS
  // =============================================================================
  
  /// Validates the registration form input
  /// This method checks all required fields and validates their content
  /// Returns true if validation passes, false otherwise
  bool _validateForm() {
    // Check if display name is provided
    if (_displayNameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Display name is required';
      });
      return false;
    }
    
    // Check if email is provided and valid
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Email is required';
      });
      return false;
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _error = 'Please enter a valid email address';
      });
      return false;
    }
    
    // Check if phone number is provided
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _error = 'Phone number is required';
      });
      return false;
    }
    
    // Check if password is provided and meets minimum length
    if (_passwordController.text.isEmpty) {
      setState(() {
        _error = 'Password is required';
      });
      return false;
    }
    
    if (_passwordController.text.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters long';
      });
      return false;
    }
    
    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _error = 'Passwords do not match';
      });
      return false;
    }
    
    // Clear any previous errors
    setState(() {
      _error = null;
    });
    
    return true;
  }

  // =============================================================================
  // MEDIA HANDLING METHODS
  // =============================================================================
  
  /// Handles profile picture selection from camera or gallery
  /// This method delegates to the appropriate media service based on platform
  /// 
  /// [source] - The source of the image (camera or gallery)
  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      // Show loading indicator
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });
      
      // Pick image using unified media service
      final currentContext = context;
      final imageBytes = source == ImageSource.camera
          ? await UnifiedMediaService.pickImageFromCamera(currentContext) // ignore: use_build_context_synchronously
          : await UnifiedMediaService.pickImageFromGallery(currentContext); // ignore: use_build_context_synchronously
      
      if (imageBytes != null) {
        setState(() {
          _profileImageBytes = imageBytes;
          _uploadProgress = 0.5; // Image picked successfully
        });
        
        // Upload the image
        await _uploadProfileImage(imageBytes);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      
      // Clear error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _error = null;
          });
        }
      });
    }
  }
  
  /// Uploads profile picture to Firebase Storage
  /// This method handles the upload process and updates the UI accordingly
  /// 
  /// [imageBytes] - The image data as bytes
  Future<void> _uploadProfileImage(Uint8List imageBytes) async {
    try {
      // Create a unique filename
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Reference to Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(fileName);
      
      // Upload the image
      final uploadTask = ref.putData(imageBytes);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _photoUrl = downloadUrl;
        _uploadProgress = 1.0;
        _isUploading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Failed to upload image: $e';
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  // =============================================================================
  // REGISTRATION METHODS
  // =============================================================================
  
  /// Handles the user registration process
  /// This method creates a new user account and stores user data
  Future<void> _register() async {
    // Validate form input
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Create user account with Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final user = userCredential.user;
      if (user != null) {
        // Update user profile with display name and photo
        await user.updateDisplayName(_displayNameController.text.trim());
        if (_photoUrl != null) {
          await user.updatePhotoURL(_photoUrl);
        }
        
        // Store additional user data in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': _displayNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'photoURL': _photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
        
        // Navigate to main app
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/chats');
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase authentication errors
      String errorMessage = 'Registration failed.';
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please provide a valid email address.';
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
  
  /// Shows the image picker bottom sheet
  /// This allows users to choose between camera and gallery
  void _showImagePicker() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Profile Picture',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera option
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickProfileImage(ImageSource.camera);
                      },
                      icon: Icon(
                        Icons.camera_alt, 
                        size: isSmallScreen ? 28 : 32
                      ),
                    ),
                    Text(
                      'Camera',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                
                // Gallery option
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickProfileImage(ImageSource.gallery);
                      },
                      icon: Icon(
                        Icons.photo_library, 
                        size: isSmallScreen ? 28 : 32
                      ),
                    ),
                    Text(
                      'Gallery',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // BUILD METHOD
  // =============================================================================
  // Builds the complete registration screen UI with proper theming,
  // localization, responsive design, and form validation
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;

    
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
    final avatarRadius = isSmallScreen ? 40.0 : isMediumScreen ? 45.0 : 50.0;
    
    return Scaffold(
      // =============================================================================
      // APP BAR
      // =============================================================================
      appBar: AppBar(
        title: Text(AppLocalizations.getString('register', _currentLanguage)),
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
                  maxWidth: isLargeScreen ? 600 : double.infinity,
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
                          'Create your account',
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 32),
                        
                        // =============================================================================
                        // PROFILE PICTURE SECTION
                        // =============================================================================
                        // Allows users to upload a profile picture
                        GestureDetector(
                          onTap: _showImagePicker,
                          child: Stack(
                            children: [
                              // Profile picture display
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundImage: _photoUrl != null
                                    ? NetworkImage(_photoUrl!)
                                    : null,
                                backgroundColor: _photoUrl == null
                                    ? Colors.grey.shade300
                                    : null,
                                child: _photoUrl == null
                                    ? Icon(
                                        Icons.person, 
                                        size: avatarRadius, 
                                        color: Colors.grey
                                      )
                                    : null,
                              ),
                              
                              // Camera icon overlay
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 3 : 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: isSmallScreen ? 16 : 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Upload progress indicator
                        if (_isUploading) ...[
                          LinearProgressIndicator(value: _uploadProgress),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Uploading... ${(_uploadProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                        ],
                        
                        // =============================================================================
                        // REGISTRATION FORM
                        // =============================================================================
                        // Form fields for user information
                        
                        // Display name field
                        TextField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.getString('display_name', _currentLanguage),
                            hintText: 'Enter your display name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Email field
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
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Phone number field
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.getString('phone_number', _currentLanguage),
                            hintText: 'Enter your phone number',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Password field
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
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Confirm password field
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.getString('confirm_password', _currentLanguage),
                            hintText: 'Confirm your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        
                        // =============================================================================
                        // ERROR MESSAGE DISPLAY
                        // =============================================================================
                        // Shows validation and registration errors to the user
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                        ],
                        
                        // =============================================================================
                        // REGISTER BUTTON
                        // =============================================================================
                        // Primary action button for user registration
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    AppLocalizations.getString('sign_up', _currentLanguage),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        
                        // =============================================================================
                        // LOGIN LINK
                        // =============================================================================
                        // Allows existing users to navigate to login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.getString('already_have_account', _currentLanguage),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/login'),
                              child: Text(
                                AppLocalizations.getString('sign_in', _currentLanguage),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ),
        ),
      ),
    );
  }
} 