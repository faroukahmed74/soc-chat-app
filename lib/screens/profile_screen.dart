import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_design_system.dart';
import '../utils/responsive_utils.dart';
import '../config/database_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  Map<String, dynamic>? _userData;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final serverUrl = DatabaseConfig.physicalServerUrl;
      final profileUrl = '$serverUrl/api/auth/profile';
      
      print('ProfileScreen: Loading profile from: $profileUrl');
      print('ProfileScreen: Token exists: ${token.isNotEmpty}');

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('ProfileScreen: Response status: ${response.statusCode}');
      print('ProfileScreen: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _displayNameController.text = data['displayName'] ?? '';
          _emailController.text = data['email'] ?? '';
          // Support both phoneNumber and phone for backward compatibility
          _phoneController.text = data['phoneNumber'] ?? data['phone'] ?? '';
        });
      } else if (response.statusCode == 404) {
        // Server needs to be restarted - show helpful message
        setState(() {
          _errorMessage = 'Profile endpoint not available. Please restart the server on the main PC to enable profile features.';
        });
      } else {
        final errorBody = response.body;
        throw Exception('Failed to load profile data: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('ProfileScreen: Error loading profile: $e');
      setState(() {
        _errorMessage = 'Error loading profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text.isNotEmpty && 
        _passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final updateData = {
        'displayName': _displayNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),  // Use phoneNumber for consistency
        'phone': _phoneController.text.trim(),       // Also send as phone for backward compatibility
      };

      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _passwordController.text;
      }

      final response = await http.put(
        Uri.parse('${DatabaseConfig.physicalServerUrl}/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Profile updated successfully!';
          _isEditing = false;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        await _loadUserData(); // Reload data to get updated info
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _errorMessage = null;
      _successMessage = null;
      if (!_isEditing) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        _loadUserData(); // Reset to original values
      }
    });
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spacingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignSystem.primaryColor,
            AppDesignSystem.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppDesignSystem.radiusXL),
          bottomRight: Radius.circular(AppDesignSystem.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: ResponsiveUtils.isMobile(context) ? 80 : 100,
            height: ResponsiveUtils.isMobile(context) ? 80 : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppDesignSystem.primaryColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: ResponsiveUtils.isMobile(context) ? 40 : 50,
              color: AppDesignSystem.primaryColor,
            ),
          ),
          SizedBox(height: AppDesignSystem.spacingMD),
          
          // User Name
          Text(
            _userData?['displayName'] ?? 'Loading...',
            style: AppDesignSystem.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: AppDesignSystem.spacingXS),
          
          // User Email
          Text(
            _userData?['email'] ?? '',
            style: AppDesignSystem.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: AppDesignSystem.spacingLG),
          
          // Edit Button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _toggleEditMode,
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              size: 18,
            ),
            label: Text(_isEditing ? 'Cancel' : 'Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppDesignSystem.primaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spacingLG,
                vertical: AppDesignSystem.spacingMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Padding(
      padding: EdgeInsets.all(AppDesignSystem.spacingLG),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success/Error Messages
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppDesignSystem.spacingMD),
                margin: EdgeInsets.only(bottom: AppDesignSystem.spacingMD),
                decoration: BoxDecoration(
                  color: AppDesignSystem.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                  border: Border.all(
                    color: AppDesignSystem.successColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppDesignSystem.successColor,
                      size: 20,
                    ),
                    SizedBox(width: AppDesignSystem.spacingSM),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppDesignSystem.spacingMD),
                margin: EdgeInsets.only(bottom: AppDesignSystem.spacingMD),
                decoration: BoxDecoration(
                  color: AppDesignSystem.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                  border: Border.all(
                    color: AppDesignSystem.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: AppDesignSystem.errorColor,
                      size: 20,
                    ),
                    SizedBox(width: AppDesignSystem.spacingSM),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Display Name Field
            _buildFormField(
              label: 'Display Name',
              controller: _displayNameController,
              icon: Icons.person_outline,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required';
                }
                if (value.trim().length < 2) {
                  return 'Display name must be at least 2 characters';
                }
                return null;
              },
            ),

            SizedBox(height: AppDesignSystem.spacingLG),

            // Email Field
            _buildFormField(
              label: 'Email',
              controller: _emailController,
              icon: Icons.email_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            SizedBox(height: AppDesignSystem.spacingLG),

            // Phone Field
            _buildFormField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                }
                return null;
              },
            ),

            if (_isEditing) ...[
              SizedBox(height: AppDesignSystem.spacingLG),

              // Password Section
              Container(
                padding: EdgeInsets.all(AppDesignSystem.spacingMD),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Password (Optional)',
                      style: AppDesignSystem.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppDesignSystem.spacingSM),
                    Text(
                      'Leave password fields empty to keep current password',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: AppDesignSystem.spacingMD),

                    // New Password Field
                    _buildPasswordField(
                      label: 'New Password',
                      controller: _passwordController,
                      isVisible: _isPasswordVisible,
                      onToggleVisibility: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: AppDesignSystem.spacingMD),

                    // Confirm Password Field
                    _buildPasswordField(
                      label: 'Confirm New Password',
                      controller: _confirmPasswordController,
                      isVisible: _isConfirmPasswordVisible,
                      onToggleVisibility: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (_passwordController.text.isNotEmpty) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppDesignSystem.spacingXL),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateProfile,
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.save, size: 18),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.successColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: AppDesignSystem.spacingLG,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],

            SizedBox(height: AppDesignSystem.spacingXL),

            // Account Info Section
            _buildAccountInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppDesignSystem.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppDesignSystem.spacingXS),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: AppDesignSystem.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: enabled
                  ? AppDesignSystem.primaryColor
                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            filled: true,
            fillColor: enabled
                ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: AppDesignSystem.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: AppDesignSystem.errorColor,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingMD,
              vertical: AppDesignSystem.spacingMD,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppDesignSystem.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppDesignSystem.spacingXS),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          style: AppDesignSystem.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.lock_outline,
              color: AppDesignSystem.primaryColor,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: AppDesignSystem.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              borderSide: BorderSide(
                color: AppDesignSystem.errorColor,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingMD,
              vertical: AppDesignSystem.spacingMD,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfo() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: AppDesignSystem.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppDesignSystem.spacingMD),
          
          _buildInfoRow('Display Name', _userData?['displayName'] ?? 'Loading...'),
          _buildInfoRow('Email', _userData?['email'] ?? 'Loading...'),
          _buildInfoRow('Phone Number', (_userData?['phoneNumber'] ?? _userData?['phone'] ?? 'Not provided').toString()),
          _buildInfoRow('User ID', _userData?['_id'] ?? 'Loading...'),
          _buildInfoRow('Status', _getUserStatus()),
          _buildInfoRow('Created', _formatDate(_userData?['createdAt'])),
          _buildInfoRow('Role', _userData?['role'] ?? 'Loading...'),
          _buildInfoRow('Last Updated', _formatDate(_userData?['updatedAt'])),
          _buildInfoRow('Last Login', _formatDate(_userData?['lastLogin'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesignSystem.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppDesignSystem.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppDesignSystem.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserStatus() {
    // Check isOnline first (boolean field)
    if (_userData?['isOnline'] == true || _userData?['isOnline'] == 'true') {
      return 'Active';
    }
    // Check status field (string: 'online' or 'offline')
    final status = _userData?['status'];
    if (status == 'online') {
      return 'Active';
    }
    // Default to inactive if neither field indicates online
    return 'Inactive';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppDesignSystem.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _userData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.primaryColor),
                  ),
                  SizedBox(height: AppDesignSystem.spacingMD),
                  Text(
                    'Loading profile...',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  _buildProfileForm(),
                ],
              ),
            ),
    );
  }
}
