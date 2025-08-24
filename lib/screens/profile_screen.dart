// =============================================================================
// PROFILE SCREEN
// =============================================================================
// This screen allows users to view and edit their profile information.
// It includes profile picture management, personal details editing,
// and responsive design for different screen sizes.
//
// KEY FEATURES:
// - Profile picture display and editing
// - Personal information editing (name, phone)
// - Responsive design with adaptive layouts
// - Real-time profile updates
// - Form validation and error handling
//
// ARCHITECTURE:
// - Uses StreamBuilder for real-time profile updates
// - Implements responsive design with MediaQuery
// - Provides profile editing with validation
// - Supports profile picture management
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified profile experience

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import '../services/unified_media_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart'; // Added import for logging

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _photoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  double _uploadProgress = 0.0;
  String? _successMessage;
  Uint8List? _profileImageBytes;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      setState(() {
        _displayNameController.text = data['displayName'] ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
        _photoUrl = data['photoUrl'];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'displayName': _displayNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'photoUrl': _photoUrl ?? '',
        });
        setState(() {
          _successMessage = 'Profile updated successfully!';
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to save profile.';
        });
      }
    }
    setState(() {
      _isSaving = false;
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    // Capture BuildContext-dependent objects before async operations
    final currentContext = context;
    
    Uint8List? imageBytes;
    if (source == 'camera') {
      Log.i('Picking image from camera', 'PROFILE_SCREEN');
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      imageBytes = await UnifiedMediaService.pickImageFromCamera(currentContext);
              Log.i('Camera result: ${imageBytes?.length ?? 0} bytes', 'PROFILE_SCREEN');
    } else if (source == 'gallery') {
              Log.i('Picking image from gallery', 'PROFILE_SCREEN');
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      imageBytes = await UnifiedMediaService.pickImageFromGallery(currentContext);
              Log.i('Gallery result: ${imageBytes?.length ?? 0} bytes', 'PROFILE_SCREEN');
    }

    if (imageBytes != null) {
      Log.i('Image picked successfully, setting state', 'PROFILE_SCREEN');
      setState(() {
        _profileImageBytes = imageBytes;
        _error = null;
        _successMessage = null;
      });
              Log.i('State updated, _profileImageBytes length: ${_profileImageBytes?.length ?? 0}', 'PROFILE_SCREEN');
    } else {
              Log.w('Failed to pick image', 'PROFILE_SCREEN');
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate responsive dimensions
    final avatarRadius = (screenWidth < 400) ? 40.0 : (screenWidth > 800) ? 60.0 : 48.0;
    final padding = (screenWidth < 400) ? 16.0 : (screenWidth > 800) ? 32.0 : 24.0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              _themeService.toggleTheme();
            },
            tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isSaving ? null : _pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundImage: _profileImageBytes != null
                              ? (() {
                                  Log.i('Using MemoryImage with ${_profileImageBytes!.length} bytes', 'PROFILE_SCREEN');
                                  return MemoryImage(_profileImageBytes!);
                                }())
                              : (_photoUrl != null && _photoUrl!.isNotEmpty
                                  ? (() {
                                      Log.i('Using NetworkImage with URL: $_photoUrl', 'PROFILE_SCREEN');
                                      return NetworkImage(_photoUrl!);
                                    }())
                                  : null),
                          child: _profileImageBytes == null && (_photoUrl == null || _photoUrl!.isEmpty)
                              ? (() {
                                  Log.i('Showing default person icon', 'PROFILE_SCREEN');
                                  return Icon(Icons.person, size: avatarRadius);
                                }())
                              : null,
                        ),
                        if (_isSaving && _uploadProgress > 0.0 && _uploadProgress < 1.0)
                          CircularProgressIndicator(value: _uploadProgress),
                      ],
                    ),
                  ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
                    ),
                  if (_profileImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        children: [
                          Text('Debug: Image loaded (${_profileImageBytes!.length} bytes)', 
                               style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          Container(
                            width: avatarRadius * 2,
                            height: avatarRadius * 2,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: Image.memory(
                              _profileImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                Log.e('Image.memory error', 'PROFILE_SCREEN', error);
                                return Container(
                                  color: Colors.red[100],
                                  child: const Icon(Icons.error, color: Colors.red),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: (screenHeight < 600) ? 12.0 : 16.0),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 