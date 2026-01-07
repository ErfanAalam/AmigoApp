import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/auth.api-client.dart';
import '../../api/user.api-client.dart';
import '../../models/country.model.dart' as country_model;
import '../../models/user.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/auth/auth.service.dart';
import '../../services/socket/websocket.service.dart';
import '../../ui/country-selector.modal.dart';
import '../../ui/snackbar.dart';
import '../home.layout.dart';
import 'signup.screen.dart';
import 'signup-status.screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = material.TextEditingController();
  final _otpController = material.TextEditingController();
  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isPhoneSubmitted = false;
  bool _isLoading = false;

  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final WebSocketService wsService = WebSocketService();
  final UserService _userService = UserService();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _updateCompletePhoneNumber() {
    setState(() {
      _completePhoneNumber = _selectedCountry.dialCode + _phoneController.text;
    });
  }

  void _showCountrySelector() {
    material.showDialog(
      context: context,
      builder: (context) => CountrySelectorModal(
        selectedCountry: _selectedCountry,
        onCountrySelected: (country_model.Country country) {
          setState(() {
            _selectedCountry = country;
            _updateCompletePhoneNumber();
          });
        },
      ),
    );
  }

  void handlePhoneSubmit() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 8) {
      Snack.error('Please enter a valid phone number.');
      // material.ScaffoldMessenger.of(context).showSnackBar(
      //   const material.SnackBar(
      //     content: material.Text('Please enter a valid phone number.'),
      //   ),
      // );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await apiService.sendLoginOtp(_completePhoneNumber);
    if (response['success']) {
      Snack.success('OTP sent successfully');
      // material.ScaffoldMessenger.of(context).showSnackBar(
      //   const material.SnackBar(
      //     content: material.Text('OTP sent successfully'),
      //   ),
      // );

      setState(() {
        _isPhoneSubmitted = true;
        _isLoading = false;
      });
    } else if (response['success'] == false && response['code'] == 404) {
      Snack.warning('Phone number not found! Please Signup First');
      // material.ScaffoldMessenger.of(context).showSnackBar(
      //   const material.SnackBar(
      //     content: material.Text('Phone number not found! Please Signup First'),
      //   ),
      // );
      setState(() {
        _isLoading = false;
      });
    } else {
      // material.ScaffoldMessenger.of(context).showSnackBar(
      //   const material.SnackBar(content: material.Text('Failed to send OTP')),
      // );
      Snack.error('Failed to send OTP');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void handleOtpSubmit() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 6) {
      // material.ScaffoldMessenger.of(context).showSnackBar(
      //   const material.SnackBar(
      //     content: material.Text('Please enter the OTP.'),
      //   ),
      // );
      Snack.error('Please enter the OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiService.verifyLoginOtp(
        _completePhoneNumber,
        int.parse(_otpController.text),
      );

      if (response['success']) {
        // Authentication is handled in the API service interceptor
        // which automatically stores cookies and updates auth state

        // if (mounted) {
        //   material.ScaffoldMessenger.of(context).showSnackBar(
        //     const material.SnackBar(
        //       content: material.Text('OTP verified successfully'),
        //     ),
        //   );
        // }
        Snack.success('OTP verified successfully');

        final appVersion = await UserUtils().getAppVersion();
        await _userService.updateUser({'app_version': appVersion});

        // storing the current user details in shared preferences
        final userDetail = {
          'id': response['data']['id'],
          'name': response['data']['name'],
          'phone': response['data']['phone'],
          'role': response['data']['role'],
          'profile_pic': response['data']['profile_pic'],
          'created_at': response['data']['created_at'],
          'call_access': response['data']['call_access'],
        };

        await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));

        // Send FCM token to backend after successful login
        await authService.sendFCMTokenToBackend(3);
        // navigate to the main screen
        if (mounted) {
          material.Navigator.pushReplacement(
            context,
            material.MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      } else {
        // if (mounted) {
        //   material.ScaffoldMessenger.of(context).showSnackBar(
        //     const material.SnackBar(
        //       content: material.Text('Failed to verify OTP'),
        //     ),
        //   );
        // }
        Snack.error('Failed to verify OTP');
      }
    } catch (e) {
      // if (mounted) {
      //   material.ScaffoldMessenger.of(context).showSnackBar(
      //     material.SnackBar(content: material.Text('Error: ${e.toString()}')),
      //   );
      // }
      Snack.error('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  material.Widget build(material.BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return material.Scaffold(
      body: material.Container(
        decoration: material.BoxDecoration(
          gradient: material.LinearGradient(
            begin: material.Alignment.topLeft,
            end: material.Alignment.bottomRight,
            colors: [themeColor.primary, themeColor.primaryDark],
            stops: [0.0, 0.5],
          ),
        ),
        child: material.SafeArea(
          child: material.Column(
            children: [
              // Status Check Button in Upper Right
              material.Padding(
                padding: const material.EdgeInsets.only(
                  top: 8,
                  right: 8,
                ),
                child: material.Align(
                  alignment: material.Alignment.topRight,
                  child: material.Material(
                    color: material.Colors.transparent,
                    child: material.InkWell(
                      onTap: () {
                        material.Navigator.push(
                          context,
                          material.MaterialPageRoute(
                            builder: (context) => const SignupStatusScreen(),
                          ),
                        );
                      },
                      borderRadius: material.BorderRadius.circular(12),
                      child: material.Container(
                        padding: const material.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: material.BoxDecoration(
                          color: material.Colors.white.withOpacity(0.2),
                          borderRadius: material.BorderRadius.circular(12),
                          border: material.Border.all(
                            color: material.Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: material.Row(
                          mainAxisSize: material.MainAxisSize.min,
                          children: [
                            const material.Icon(
                              material.Icons.info_outline_rounded,
                              color: material.Colors.white,
                              size: 18,
                            ),
                            const material.SizedBox(width: 6),
                            const material.Text(
                              'Check Status',
                              style: material.TextStyle(
                                color: material.Colors.white,
                                fontSize: 13,
                                fontWeight: material.FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Main Content
              material.Expanded(
                child: material.SingleChildScrollView(
                  padding: const material.EdgeInsets.symmetric(horizontal: 24.0),
                  child: material.ConstrainedBox(
                    constraints: material.BoxConstraints(
                      minHeight:
                          material.MediaQuery.of(context).size.height -
                          material.MediaQuery.of(context).padding.top -
                          material.MediaQuery.of(context).padding.bottom -
                          60,
                    ),
                    child: material.IntrinsicHeight(
                      child: material.Column(
                        children: [
                          const material.SizedBox(height: 20),

                    // App Logo Section
                    material.Container(
                      padding: const material.EdgeInsets.all(20),
                      decoration: material.BoxDecoration(
                        color: material.Colors.white.withOpacity(0.15),
                        shape: material.BoxShape.circle,
                        border: material.Border.all(
                          color: material.Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          material.BoxShadow(
                            color: material.Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const material.Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const material.Icon(
                        material.Icons.chat_bubble_rounded,
                        size: 60,
                        color: material.Colors.white,
                      ),
                    ),

                    const material.SizedBox(height: 30),

                    // App Name
                    const material.Text(
                      'Amigo Chat App',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 32,
                        fontWeight: material.FontWeight.bold,
                        color: material.Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const material.SizedBox(height: 8),

                    // Welcome Text
                    material.Text(
                      !_isPhoneSubmitted
                          ? 'Connect with friends and family'
                          : 'Enter verification code',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 16,
                        color: material.Colors.white.withOpacity(0.9),
                        fontWeight: material.FontWeight.w400,
                      ),
                    ),

                    const material.SizedBox(height: 50),

                    // Main Card
                    material.Container(
                      padding: const material.EdgeInsets.all(32),
                      decoration: material.BoxDecoration(
                        color: material.Colors.white,
                        borderRadius: material.BorderRadius.circular(24),
                        boxShadow: [
                          material.BoxShadow(
                            color: material.Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const material.Offset(0, 15),
                          ),
                        ],
                      ),
                      child: material.AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: material.Curves.easeInOutCubic,
                        child: material.Column(
                          crossAxisAlignment:
                              material.CrossAxisAlignment.stretch,
                          mainAxisSize: material.MainAxisSize.min,
                          children: [
                            // Phone Number Field or OTP Field based on state
                            !_isPhoneSubmitted
                                ? material.Column(
                                    crossAxisAlignment:
                                        material.CrossAxisAlignment.start,
                                    mainAxisSize: material.MainAxisSize.min,
                                    children: [
                                      material.Text(
                                        'Phone Number',
                                        style: material.TextStyle(
                                          fontSize: 16,
                                          fontWeight: material.FontWeight.w600,
                                          color: material.Colors.grey[800],
                                        ),
                                      ),
                                      const material.SizedBox(height: 8),
                                      material.Row(
                                        children: [
                                          // Country Code Selector
                                          material.Container(
                                            decoration: material.BoxDecoration(
                                              color: material.Colors.grey[50],
                                              borderRadius: material
                                                  .BorderRadius.circular(16),
                                              border: material.Border.all(
                                                color:
                                                    material.Colors.grey[200]!,
                                              ),
                                            ),
                                            child: material.Material(
                                              color:
                                                  material.Colors.transparent,
                                              child: material.InkWell(
                                                onTap: _showCountrySelector,
                                                borderRadius: material
                                                    .BorderRadius.circular(16),
                                                child: material.Padding(
                                                  padding:
                                                      const material.EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                        vertical: 8,
                                                      ),
                                                  child: material.Row(
                                                    mainAxisSize: material
                                                        .MainAxisSize
                                                        .min,
                                                    children: [
                                                      material.Text(
                                                        _selectedCountry.flag,
                                                        style:
                                                            const material.TextStyle(
                                                              fontSize: 20,
                                                            ),
                                                      ),
                                                      const material.SizedBox(
                                                        width: 8,
                                                      ),
                                                      material.Text(
                                                        _selectedCountry
                                                            .dialCode,
                                                        style:
                                                            material.TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  material
                                                                      .FontWeight
                                                                      .w600,
                                                              color: material
                                                                  .Colors
                                                                  .grey[800],
                                                            ),
                                                      ),
                                                      const material.SizedBox(
                                                        width: 4,
                                                      ),
                                                      material.Icon(
                                                        material
                                                            .Icons
                                                            .keyboard_arrow_down,
                                                        size: 20,
                                                        color: material
                                                            .Colors
                                                            .grey[600],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const material.SizedBox(width: 12),
                                          // Phone Number Input
                                          material.Expanded(
                                            child: material.Container(
                                              decoration: material.BoxDecoration(
                                                color: material.Colors.grey[50],
                                                borderRadius: material
                                                    .BorderRadius.circular(16),
                                                border: material.Border.all(
                                                  color: material
                                                      .Colors
                                                      .grey[200]!,
                                                ),
                                              ),
                                              child: material.Padding(
                                                padding:
                                                    const material.EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 0,
                                                    ),
                                                child: material.TextField(
                                                  controller: _phoneController,
                                                  keyboardType: material
                                                      .TextInputType
                                                      .phone,
                                                  textInputAction: material
                                                      .TextInputAction
                                                      .done,
                                                  onChanged: (value) =>
                                                      _updateCompletePhoneNumber(),
                                                  style: material.TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: material
                                                        .FontWeight
                                                        .w500,
                                                  ),
                                                  decoration: material.InputDecoration(
                                                    hintText:
                                                        'Enter your phone number',
                                                    hintStyle:
                                                        material.TextStyle(
                                                          color: material
                                                              .Colors
                                                              .grey[400],
                                                          fontSize: 16,
                                                        ),
                                                    border: material
                                                        .InputBorder
                                                        .none,
                                                    contentPadding:
                                                        const material.EdgeInsets.symmetric(
                                                          vertical: 10.0,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : material.Column(
                                    crossAxisAlignment:
                                        material.CrossAxisAlignment.start,
                                    mainAxisSize: material.MainAxisSize.min,
                                    children: [
                                      material.Row(
                                        children: [
                                          material.GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _isPhoneSubmitted = false;
                                              });
                                            },

                                            child: material.Icon(
                                              material
                                                  .Icons
                                                  .arrow_circle_left_outlined,
                                              color: themeColor.primary,
                                              size: 36,
                                            ),
                                          ),
                                          const material.SizedBox(width: 8),
                                          material.Text(
                                            'Verification Code',
                                            style: material.TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  material.FontWeight.w600,
                                              color: material.Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const material.SizedBox(height: 15),
                                      material.Container(
                                        decoration: material.BoxDecoration(
                                          color: material.Colors.grey[50],
                                          borderRadius: material
                                              .BorderRadius.circular(16),
                                          border: material.Border.all(
                                            color: material.Colors.grey[200]!,
                                          ),
                                        ),
                                        child: material.Padding(
                                          padding:
                                              const material.EdgeInsets.symmetric(
                                                horizontal: 20.0,
                                              ),
                                          child: material.TextField(
                                            controller: _otpController,
                                            keyboardType:
                                                material.TextInputType.number,
                                            textAlign:
                                                material.TextAlign.center,
                                            style: material.TextStyle(
                                              fontSize: 20,
                                              fontWeight:
                                                  material.FontWeight.w600,
                                              letterSpacing: 4,
                                            ),
                                            decoration: material.InputDecoration(
                                              hintText: '000000',
                                              hintStyle: material.TextStyle(
                                                color:
                                                    material.Colors.grey[400],
                                                fontSize: 20,
                                                letterSpacing: 4,
                                              ),
                                              border: material.InputBorder.none,
                                              contentPadding:
                                                  const material.EdgeInsets.symmetric(
                                                    vertical: 18.0,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                            const material.SizedBox(height: 32),

                            // Login Button - changes based on state
                            material.Container(
                              decoration: material.BoxDecoration(
                                gradient: material.LinearGradient(
                                  colors: [
                                    themeColor.primary,
                                    themeColor.primary,
                                  ],
                                ),
                                borderRadius: material.BorderRadius.circular(
                                  16,
                                ),
                                boxShadow: [
                                  material.BoxShadow(
                                    color: themeColor.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const material.Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: material.Material(
                                color: material.Colors.transparent,
                                child: material.InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          !_isPhoneSubmitted
                                              ? handlePhoneSubmit()
                                              : handleOtpSubmit();
                                        },
                                  borderRadius: material.BorderRadius.circular(
                                    16,
                                  ),
                                  child: material.Padding(
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                    child: material.Row(
                                      mainAxisAlignment:
                                          material.MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          const material.SizedBox(
                                            height: 20,
                                            width: 20,
                                            child:
                                                material.CircularProgressIndicator(
                                                  color: material.Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                          )
                                        else ...[
                                          material.Text(
                                            !_isPhoneSubmitted
                                                ? 'Send OTP'
                                                : 'Verify & Continue',
                                            style: const material.TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  material.FontWeight.bold,
                                              color: material.Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const material.SizedBox(width: 8),
                                          const material.Icon(
                                            material
                                                .Icons
                                                .arrow_forward_rounded,
                                            color: material.Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const material.SizedBox(height: 24),

                            // Sign Up Link
                            if (_isPhoneSubmitted)
                              material.Row(
                                mainAxisAlignment:
                                    material.MainAxisAlignment.center,
                                children: [
                                  material.GestureDetector(
                                    onTap: () {
                                      handlePhoneSubmit();
                                    },
                                    child: material.Container(
                                      decoration: material.BoxDecoration(
                                        border: material.Border(
                                          bottom: material.BorderSide(
                                            color: themeColor.primary,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      padding: const material.EdgeInsets.only(
                                        bottom: 0.5,
                                      ), // Adjust this for space between text and underline
                                      child: material.Text(
                                        'Resend OTP',
                                        style: material.TextStyle(
                                          color: themeColor.primary,
                                          fontWeight: material.FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            const material.SizedBox(height: 24),

                            // Sign Up Link
                            material.Row(
                              mainAxisAlignment:
                                  material.MainAxisAlignment.center,
                              children: [
                                material.Text(
                                  "Don't have an account? ",
                                  style: material.TextStyle(
                                    color: material.Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                material.GestureDetector(
                                  onTap: () {
                                    material.Navigator.push(
                                      context,
                                      material.MaterialPageRoute(
                                        builder: (context) =>
                                            const SignUpScreen(),
                                      ),
                                    );
                                  },
                                  child: material.Text(
                                    'Sign Up',
                                    style: material.TextStyle(
                                      color: themeColor.primary,
                                      fontWeight: material.FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const material.Spacer(),

                    // Footer
                    material.Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        color: material.Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const material.SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
