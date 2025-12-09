import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../api/auth.api-client.dart';
import '../../api/user.api-client.dart';
import '../../models/user.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../ui/snackbar.dart';

class EditProfileModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileModal({
    Key? key,
    required this.userData,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  ConsumerState<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<EditProfileModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _nameController = TextEditingController();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  File? _selectedImage;
  bool _isLoading = false;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Set initial values
    _nameController.text = widget.userData['name'] ?? '';
    _profilePicUrl = widget.userData['profile_pic'];

    // Start animations
    _animationController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> updateData = {'name': _nameController.text.trim()};

      if (_selectedImage != null) {
        final response = await _apiService.sendMedia(file: _selectedImage!);
        final imageUrl = response['data']['url'];
        updateData['profile_pic'] = imageUrl;
      }
      final response = await _userService.updateUser(updateData);

      if (response['success']) {
        // Update the user data with new information
        Map<String, dynamic> updatedUserData = Map.from(widget.userData);
        updatedUserData['name'] = _nameController.text.trim();
        if (_selectedImage != null && updateData.containsKey('profile_pic')) {
          updatedUserData['profile_pic'] = updateData['profile_pic'];
        }

        widget.onProfileUpdated(updatedUserData);

        final updatedUser = UserModel.fromJson(updatedUserData);
        await UserUtils().updateUserDetails(updatedUser);

        _showSuccessSnackBar('Profile updated successfully!');
        Navigator.of(context).pop();
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    Snack.error(message);
  }

  void _showSuccessSnackBar(String message) {
    Snack.success(message);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      margin: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeColor.primary,
                                  themeColor.primaryLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Profile Picture Section
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: themeColor.primary,
                                          width: 3,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: themeColor.primaryLight
                                            .withOpacity(0.3),
                                        backgroundImage: _selectedImage != null
                                            ? FileImage(_selectedImage!)
                                            : (_profilePicUrl != null
                                                      ? NetworkImage(
                                                          _profilePicUrl!,
                                                        )
                                                      : null)
                                                  as ImageProvider?,
                                        child:
                                            _selectedImage == null &&
                                                _profilePicUrl == null
                                            ? Text(
                                                _getInitials(
                                                  _nameController.text,
                                                ),
                                                style: TextStyle(
                                                  color: themeColor.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 24,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: themeColor.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'gallery') {
                                              _pickImage();
                                            } else if (value == 'camera') {
                                              _takePhoto();
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'gallery',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.photo_library,
                                                    color: themeColor.primary,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Gallery'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'camera',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.camera_alt,
                                                    color: themeColor.primary,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Camera'),
                                                ],
                                              ),
                                            ),
                                          ],
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 20),

                                // Name Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      labelStyle: TextStyle(
                                        color: themeColor.primary,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.person,
                                        color: themeColor.primary,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),

                                SizedBox(height: 20),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: themeColor.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: themeColor.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _updateProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeColor.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: _isLoading
                                            ? SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
