import 'package:amigo/api/user.service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
// import '../../services/cookie_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_modal.dart';
import 'deleted_chats_page.dart';
import '../../api/api_service.dart';
import '../../services/chat_preferences_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  // final CookieService _cookieService = CookieService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUpdatingProfilePic = false;
  int deletedChatsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDeletedChatsCount();
  }

  Future<void> _loadDeletedChatsCount() async {
    try {
      final deletedChats = await _chatPreferencesService.getDeletedChats();
      if (mounted) {
        setState(() {
          deletedChatsCount = deletedChats.length;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading deleted chats count: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final response = await _userService.getUser();
      print(response);

      if (response['success'] && mounted) {
        setState(() {
          userData = response['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showEditProfileModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditProfileModal(
        userData: userData ?? {},
        onProfileUpdated: (updatedData) {
          setState(() {
            userData = updatedData;
          });
        },
      ),
    );
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
        await _updateProfilePicture(File(image.path));
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
        await _updateProfilePicture(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _updateProfilePicture(File imageFile) async {
    setState(() {
      isUpdatingProfilePic = true;
    });

    try {
      // Upload the image first
      final uploadResponse = await _apiService.sendMedia(file: imageFile);

      if (uploadResponse['success']) {
        final imageUrl = uploadResponse['data']['url'];

        // Update user profile with new image URL
        final updateResponse = await _userService.updateUser({
          'profile_pic': imageUrl,
        });

        if (updateResponse['success'] && mounted) {
          setState(() {
            userData = {...userData!, 'profile_pic': imageUrl};
          });
          // _showSuccessSnackBar('Profile picture updated successfully!');
        } else {
          _showErrorSnackBar(
            updateResponse['message'] ?? 'Failed to update profile picture',
          );
        }
      } else {
        _showErrorSnackBar(
          uploadResponse['message'] ?? 'Failed to upload image',
        );
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        isUpdatingProfilePic = false;
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.teal),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.teal),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40, // Reduce leading width to minimize gap
        leading: Padding(
          padding: EdgeInsets.only(left: 16), // Add some left padding
          child: Icon(Icons.person, color: Colors.white),
        ),
        titleSpacing: 8,
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _loadUserData();
            },
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditProfileModal,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.teal, Colors.teal[300]!],
                  ),
                ),
                child: Column(
                  children: [
                    // Profile Picture
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 47,
                            backgroundColor: Colors.teal[100],
                            backgroundImage: userData?['profile_pic'] != null
                                ? NetworkImage(userData!['profile_pic'])
                                : null,
                            child: userData?['profile_pic'] == null
                                ? Text(
                                    isLoading
                                        ? '...'
                                        : _getInitials(
                                            userData?['name'] ?? 'User',
                                          ),
                                    style: TextStyle(
                                      color: Colors.teal,
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: isUpdatingProfilePic
                                ? Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.teal,
                                            ),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      Icons.camera_alt,
                                      color: Colors.teal,
                                    ),
                                    onPressed: _showImageSourceDialog,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Name and Phone
                    Text(
                      isLoading
                          ? 'Loading...'
                          : ((userData?['name'].toString() ?? 'User')),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isLoading
                          ? 'Loading...'
                          : (userData?['phone'] ?? 'No phone number'),
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userData?['role']?.toString().toUpperCase() ?? 'USER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // User Information Section
              Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoSection(
                      title: 'Account Information',
                      children: [
                        _buildInfoItem(
                          icon: Icons.phone,
                          label: 'Phone Number',
                          value: userData?['phone'] ?? 'N/A',
                        ),
                        _buildInfoItem(
                          icon: Icons.person,
                          label: 'Role',
                          value: (userData?['role'] ?? 'user')
                              .toString()
                              .toUpperCase(),
                          valueColor: Colors.teal,
                        ),
                      ],
                    ),

                    Divider(height: 1),

                    _buildInfoSection(
                      title: 'Activity & Status',
                      children: [
                        _buildInfoItem(
                          icon: Icons.calendar_today,
                          label: 'Member Since',
                          value: _formatDate(userData?['created_at']),
                        ),
                        _buildInfoItem(
                          icon: Icons.call,
                          label: 'Call Access',
                          value: (userData?['call_access'] == true)
                              ? 'Enabled'
                              : 'Disabled',
                          valueColor: (userData?['call_access'] == true)
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chat Management Section
              Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoSection(
                      title: 'Chat Management',
                      children: [
                        ProfileOption(
                          icon: Icons.delete_outline,
                          title: 'Deleted Chats',
                          subtitle: deletedChatsCount > 0
                              ? '$deletedChatsCount deleted chat${deletedChatsCount > 1 ? 's' : ''}'
                              : 'View deleted chats',
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeletedChatsPage(),
                              ),
                            );
                            // Refresh count when returning
                            _loadDeletedChatsCount();

                            // If a chat was restored, notify the parent to refresh
                            if (result == true && mounted) {
                              // Send a signal to refresh the chats page
                              Navigator.pop(context, 'refresh_chats');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Logout Section
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ProfileOption(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  textColor: Colors.red,
                  onTap: () async {
                    // Show confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Sign Out'),
                        content: Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'SIGN OUT',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    // If user confirmed logout
                    if (shouldLogout == true) {
                      // Clear auth state
                      await _authService.logout();

                      // Navigate to login screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? textColor;

  const ProfileOption({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.teal, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey[400],
        size: 16,
      ),
      onTap: onTap,
    );
  }
}
