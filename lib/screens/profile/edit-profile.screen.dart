import 'package:amigo/utils/user.utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../api/api_service.dart';
import '../../db/repositories/user.repo.dart';
import '../../models/user.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../ui/snackbar.dart';

class EditProfileModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileModal({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  ConsumerState<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<EditProfileModal> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final apiService = ApiService();
  File? _selectedImage;
  bool _isLoading = false;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData['name'] ?? '';
    _profilePicUrl = widget.userData['profile_pic'];
  }

  @override
  void dispose() {
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
      Snack.error('Failed to pick image: $e');
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
      Snack.error('Failed to take photo: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      Snack.error('Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final previousProfilePic = widget.userData['profile_pic'] as String?;
      Map<String, dynamic> updateData = {'name': _nameController.text.trim()};

      if (_selectedImage != null) {
        final uploadResult = await apiService.client.uploadMedia(
          file: _selectedImage!,
        );
        if (!uploadResult.isSuccess || uploadResult.data == null) {
          Snack.error(uploadResult.message);
          return;
        }
        final imageUrl = uploadResult.data!['url'] as String;
        updateData['profile_pic'] = imageUrl;
      }
      final result = await apiService.user.updateUser(updateData);

      if (result.isSuccess) {
        Map<String, dynamic> updatedUserData = Map.from(widget.userData);
        updatedUserData['name'] = _nameController.text.trim();
        if (_selectedImage != null && updateData.containsKey('profile_pic')) {
          updatedUserData['profile_pic'] = updateData['profile_pic'];

          // Evict the previous PFP from the on-disk image cache so any
          // CachedNetworkImage that still holds the old URL refetches.
          if (previousProfilePic != null && previousProfilePic.isNotEmpty) {
            try {
              await CachedNetworkImage.evictFromCache(previousProfilePic);
              await DefaultCacheManager().removeFile(previousProfilePic);
            } catch (_) {/* best-effort */}
          }
        }

        widget.onProfileUpdated(updatedUserData);

        final updatedUser = UserModel.fromJson(updatedUserData);
        await UserUtils().updateUserDetails(updatedUser);

        // Mirror the change into the local Drift users table so any
        // screen that reads from it (e.g. DM list) updates in-place.
        try {
          final userId = updatedUserData['id'] as String?;
          if (userId != null) {
            await UserRepository().updateUser(updatedUser);
          }
        } catch (_) {/* best-effort */}

        Snack.success('Profile updated successfully!');
        Navigator.of(context).pop();
      } else {
        Snack.error(result.message);
      }
    } catch (e) {
      Snack.error('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2 &&
        nameParts[0].isNotEmpty &&
        nameParts[1].isNotEmpty) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showImageSourceSheet() {
    final themeColor = ref.read(themeColorProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: themeColor.primary,
                  ),
                  title: const Text('Choose from gallery',
                      style: TextStyle(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(
                    Icons.camera_alt_outlined,
                    color: themeColor.primary,
                  ),
                  title: const Text('Take a photo',
                      style: TextStyle(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final hasImage = _selectedImage != null || _profilePicUrl != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Avatar
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_profilePicUrl != null
                                  ? NetworkImage(_profilePicUrl!)
                                  : null)
                              as ImageProvider?,
                    child: !hasImage
                        ? Text(
                            _getInitials(_nameController.text),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeColor.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Name field
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Full name',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: themeColor.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _updateProfile,
          style: TextButton.styleFrom(
            foregroundColor: themeColor.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeColor.primary,
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
