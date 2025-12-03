import 'package:amigo/api/user.service.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/user_model.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth/auth.service.dart';
// import '../../services/cookie_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile.dart';
import 'deleted_dms.dart';
import '../../api/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_color_provider.dart';
import '../../config/app_colors.dart';
// import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final AuthService _authService = AuthService();
  // final CookieService _cookieService = CookieService();
  final UserService _userService = UserService();
  final ConversationRepository _conversationRepo = ConversationRepository();
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUpdatingProfilePic = false;
  int deletedChatsCount = 0;
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDeletedChatsCount();
    _loadAppVersion();
    // _checkPermissions();
    _requestPermissions();
  }

  Future<void> _loadDeletedChatsCount() async {
    try {
      final deletedChats = await _conversationRepo.getAllDeletedDms();
      if (mounted) {
        setState(() {
          deletedChatsCount = deletedChats.length;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading deleted chats count: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final appVersion = await UserUtils().getAppVersion();
      if (mounted) {
        setState(() {
          this.appVersion = appVersion;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading app version: $e');
    }
  }

  // load user: first local, then remote & sync
  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final CurrentUser = await UserUtils().getUserDetails();

      debugPrint('CurrentUser: $CurrentUser');

      if (CurrentUser != null) {
        setState(() {
          userData = CurrentUser.toJson();
          isLoading = false;
        });
      } else {
        final response = await _userService.getUser();
        if (response['success'] == true) {
          setState(() {
            userData = response['data'];
            isLoading = false;
          });
        } else {
          if (mounted) setState(() => isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error _loadUserData: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty || name.trim().isEmpty) return 'U';
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length >= 2) {
      // Check if both words have at least one character
      if (nameParts[0].isNotEmpty && nameParts[1].isNotEmpty) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts[0].isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
    } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return 'U';
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
      // 1) Upload image to media server
      final uploadResponse = await _apiService.sendMedia(file: imageFile);
      if (!(uploadResponse['success'] == true)) {
        _showErrorSnackBar(uploadResponse['message'] ?? 'Upload failed');
        return;
      }
      final imageUrl = uploadResponse['data']['url'] as String;

      // 2) Update remote profile via API
      final updateResponse = await _userService.updateUser({
        'profile_pic': imageUrl,
      });

      if (updateResponse['success'] == true) {
        final updatedUser = UserModel.fromJson(
          userData ?? {},
        ).copyWith(profilePic: imageUrl);
        await UserUtils().updateUserDetails(updatedUser);
        if (mounted) setState(() => userData = updatedUser.toJson());
      } else {
        _showErrorSnackBar(
          updateResponse['message'] ?? 'Failed to update profile',
        );
      }
    } finally {
      if (mounted) setState(() => isUpdatingProfilePic = false);
    }
  }

  void _showImageSourceDialog() {
    final themeColor = ref.read(themeColorProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: themeColor.primary),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: themeColor.primary),
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

  void _showColorPickerDialog() {
    final currentTheme = ref.read(themeColorProvider);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Select Theme Color'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: AppColors.allThemes.map((theme) {
                final isSelected = currentTheme.name == theme.name;
                return GestureDetector(
                  onTap: () {
                    // Close dialog first to allow closing animation
                    Navigator.pop(context);
                    // Wait for closing animation to complete before changing theme
                    // This prevents the theme change from interrupting the animation
                    Future.delayed(Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        ref.read(themeColorProvider.notifier).setTheme(theme);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Theme changed to ${theme.name}'),
                            backgroundColor: theme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: theme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.4),
                          spreadRadius: isSelected ? 3 : 1,
                          blurRadius: isSelected ? 10 : 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: Colors.white, size: 30)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    // try {
    await Permission.contacts.request();
    await Permission.location.request();
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    final themeColor = ref.watch(themeColorProvider);
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
              color: themeColor.primary,
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
    final themeColor = ref.watch(themeColorProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: themeColor.primary, size: 20),
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
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: themeColor.primary,
          leadingWidth: 60,
          leading: Container(
            margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_rounded, color: Colors.white, size: 24),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  _loadUserData();
                },
              ),
            ),
            Container(
              margin: EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: _showEditProfileModal,
              ),
            ),
          ],
        ),
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
                    colors: [themeColor.primary, themeColor.primaryLight],
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
                            backgroundColor: themeColor.primaryLight
                                .withOpacity(0.3),
                            backgroundImage: userData?['profile_pic'] != null
                                ? CachedNetworkImageProvider(
                                    userData!['profile_pic'],
                                  )
                                : null,
                            child: userData?['profile_pic'] == null
                                ? Text(
                                    isLoading
                                        ? '...'
                                        : _getInitials(
                                            userData?['name'] ?? 'User',
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
                                              themeColor.primary,
                                            ),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      Icons.camera_alt,
                                      color: themeColor.primary,
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
                          : ((userData?['name']?.toString() ??
                                'User')), // Add null safety
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
                          valueColor: themeColor.primary,
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

              // App Theme Color Section
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
                      title: 'App Appearance',
                      children: [
                        InkWell(
                          onTap: () => _showColorPickerDialog(),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ref
                                        .watch(themeColorProvider)
                                        .primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.palette,
                                    color: ref
                                        .watch(themeColorProvider)
                                        .primary,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Theme Color',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Select your preferred app color',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
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

              SizedBox(height: 16),

              // App Version Section
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
                child: Column(
                  children: [
                    _buildInfoSection(
                      title: 'About',
                      children: [
                        _buildInfoItem(
                          icon: Icons.info_outline,
                          label: 'App Version',
                          value: appVersion.isNotEmpty
                              ? 'v$appVersion'
                              : 'Loading...',
                          valueColor: Colors.grey[700],
                        ),
                        // ProfileOption(
                        //   icon: Icons.storage,
                        //   title: 'Database Viewer',
                        //   subtitle: 'View and inspect database contents',
                        //   onTap: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => DriftDbViewer(
                        //           SqliteDatabase.instance.database,
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                  ],
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

class ProfileOption extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    return ListTile(
      leading: Icon(icon, color: textColor ?? themeColor.primary, size: 24),
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
