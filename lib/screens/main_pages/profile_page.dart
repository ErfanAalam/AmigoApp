import 'package:amigo/api/user.service.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
// import '../../services/cookie_service.dart';
import '../auth/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  // final CookieService _cookieService = CookieService();
  final UserService _userService = UserService();

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await _userService.getUser();

      if (response['success'] && mounted) {
        setState(() {
          userData = response['data']['data'];
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
            onPressed: () {
              // Edit profile pressed
            },
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
                            child: IconButton(
                              icon: Icon(Icons.camera_alt, color: Colors.teal),
                              onPressed: () {
                                // Change profile picture
                              },
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

              // Profile Options
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
                    Divider(height: 1),
                    ProfileOption(
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
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
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
