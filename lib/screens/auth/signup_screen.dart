import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import '../main_screen.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/country_model.dart' as country_model;
import '../../widgets/country_selector_modal.dart';
import '../../widgets/setup_loading_popup.dart';
import '../../utils/navigation_helper.dart';
import '../../utils/app_restart_helper.dart';

class SignUpScreen extends material.StatefulWidget {
  const SignUpScreen({material.Key? key}) : super(key: key);

  @override
  material.State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends material.State<SignUpScreen> {
  final _firstNameController = material.TextEditingController();
  final _lastNameController = material.TextEditingController();
  final _phoneController = material.TextEditingController();
  final _otpController = material.TextEditingController();

  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isOtpSent = false;
  bool _isLoading = false;

  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final NotificationService notificationService = NotificationService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _updateCompletePhoneNumber() {
    setState(() {
      _completePhoneNumber = _selectedCountry.dialCode + _phoneController.text;
    });
  }

  void _showSetupLoadingPopup() {
    material.showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SetupLoadingPopup(),
    );

    // Wait for a moment to show the popup, then restart the app
    Future.delayed(const Duration(seconds: 2), () {
      _restartApp();
    });
  }

  void _restartApp() {
    // Close the popup first
    if (material.Navigator.of(context).canPop()) {
      material.Navigator.of(context).pop();
    }

    // Clear all navigation and go to main screen
    // This will trigger a fresh authentication check
    material.Navigator.pushAndRemoveUntil(
      context,
      material.MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
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

  Future<void> _sendFCMTokenToBackend() async {
    try {
      // Initialize notification service if not already done
      await notificationService.initialize();
      
      // Get the FCM token
      final fcmToken = notificationService.fcmToken;
      
      if (fcmToken != null && fcmToken.isNotEmpty) {
        print('🔑 Sending FCM token to backend: $fcmToken');
        await apiService.updateFCMToken(fcmToken);
        print('✅ FCM token sent successfully');
      } else {
        print('⚠️ FCM token not available, will retry later');
        // Retry getting the token after a short delay
        await Future.delayed(const Duration(seconds: 2));
        final retryToken = notificationService.fcmToken;
        if (retryToken != null && retryToken.isNotEmpty) {
          await apiService.updateFCMToken(retryToken);
          print('✅ FCM token sent successfully on retry');
        }
      }
    } catch (e) {
      print('❌ Error sending FCM token: $e');
      // Don't fail the signup flow for FCM token issues
    }
  }

  void handleSendOtp() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _phoneController.text.length < 8) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Please fill all fields correctly.'),
        ),
      );
      return;
    }

    final response = await apiService.generateSignupOtp(_completePhoneNumber);

    if (response['success']) {
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('Signup OTP sent successfully'),
          ),
        );
      });
    } else if (response['success'] == false && response['code'] == 409) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Phone number already exists! Please Login'),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('Error sending Signup OTP'),
          ),
        );
      });
    }
  }

  void handleVerifyOtp() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 6) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Please enter the OTP.'),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final response = await apiService.verifySignupOtp(
      _completePhoneNumber,
      int.parse(_otpController.text),
      _firstNameController.text,
      _lastNameController.text,
    );

    if (response['success']) {
      setState(() {
        _isLoading = false;
      });

      // Send FCM token to backend after successful signup
      _sendFCMTokenToBackend();

      // Show the setup loading popup
      _showSetupLoadingPopup();
      // Authentication is handled in the API service interceptor
      // which automatically stores cookies and updates auth state
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Account created successfully'),
        ),
      );

      // Restart the app to ensure all services are properly initialized
      // await AppRestartHelper.restartAppWithDialog(context);
    } else {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Error verifying Signup OTP'),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }

    // setState(() {
    //   _isLoading = false;
    // });

    // material.ScaffoldMessenger.of(context).showSnackBar(
    //   const material.SnackBar(
    //     content: material.Text('Account created successfully'),
    //   ),
    // );

    // // Navigate to main screen after successful signup
    // material.Navigator.pushReplacement(
    //   context,
    //   material.MaterialPageRoute(builder: (context) => const MainScreen()),
    // );
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      body: material.Container(
        decoration: const material.BoxDecoration(
          gradient: material.LinearGradient(
            begin: material.Alignment.topLeft,
            end: material.Alignment.bottomRight,
            colors: [
              material.Colors.teal,
              material.Color.fromARGB(255, 10, 107, 97),
            ],
            stops: [0.0, 0.5],
          ),
        ),
        child: material.SafeArea(
          child: material.SingleChildScrollView(
            padding: const material.EdgeInsets.symmetric(horizontal: 24.0),
            child: material.ConstrainedBox(
              constraints: material.BoxConstraints(
                minHeight:
                    material.MediaQuery.of(context).size.height -
                    material.MediaQuery.of(context).padding.top -
                    material.MediaQuery.of(context).padding.bottom,
              ),
              child: material.IntrinsicHeight(
                child: material.Column(
                  children: [
                    const material.SizedBox(height: 30),

                    // App Logo Section
                    material.Container(
                      padding: const material.EdgeInsets.all(12),
                      decoration: material.BoxDecoration(
                        color: material.Colors.white.withOpacity(0.15),
                        shape: material.BoxShape.circle,
                        border: material.Border.all(
                          color: material.Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          material.BoxShadow(
                            color: material.Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const material.Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const material.Icon(
                        material.Icons.person_add_rounded,
                        size: 40,
                        color: material.Colors.white,
                      ),
                    ),

                    const material.SizedBox(height: 20),

                    // App Name
                    const material.Text(
                      'Amigo Chat App',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 24,
                        fontWeight: material.FontWeight.bold,
                        color: material.Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const material.SizedBox(height: 4),

                    // Welcome Text
                    material.Text(
                      !_isOtpSent
                          ? 'Join the conversation'
                          : 'Enter verification code',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 14,
                        color: material.Colors.white.withOpacity(0.9),
                        fontWeight: material.FontWeight.w400,
                      ),
                    ),

                    const material.SizedBox(height: 30),

                    // Main Card
                    material.Container(
                      padding: const material.EdgeInsets.all(20),
                      decoration: material.BoxDecoration(
                        color: material.Colors.white,
                        borderRadius: material.BorderRadius.circular(20),
                        boxShadow: [
                          material.BoxShadow(
                            color: material.Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const material.Offset(0, 10),
                          ),
                        ],
                      ),
                      child: material.Column(
                        crossAxisAlignment: material.CrossAxisAlignment.stretch,
                        children: [
                          // Form Fields
                          if (!_isOtpSent) ...[
                            // First Name Field
                            material.Column(
                              crossAxisAlignment:
                                  material.CrossAxisAlignment.start,
                              children: [
                                material.Text(
                                  'First Name',
                                  style: material.TextStyle(
                                    fontSize: 14,
                                    fontWeight: material.FontWeight.w600,
                                    color: material.Colors.grey[800],
                                  ),
                                ),
                                const material.SizedBox(height: 6),
                                material.Container(
                                  decoration: material.BoxDecoration(
                                    color: material.Colors.grey[50],
                                    borderRadius:
                                        material.BorderRadius.circular(16),
                                    border: material.Border.all(
                                      color: material.Colors.grey[200]!,
                                    ),
                                  ),
                                  child: material.Padding(
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                    child: material.TextField(
                                      controller: _firstNameController,
                                      textInputAction:
                                          material.TextInputAction.next,
                                      style: material.TextStyle(
                                        fontSize: 15,
                                        fontWeight: material.FontWeight.w500,
                                      ),
                                      decoration: material.InputDecoration(
                                        hintText: 'Enter your first name',
                                        hintStyle: material.TextStyle(
                                          color: material.Colors.grey[400],
                                          fontSize: 15,
                                        ),
                                        border: material.InputBorder.none,
                                        contentPadding:
                                            const material.EdgeInsets.symmetric(
                                              vertical: 14.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const material.SizedBox(height: 16),

                            // Last Name Field
                            material.Column(
                              crossAxisAlignment:
                                  material.CrossAxisAlignment.start,
                              children: [
                                material.Text(
                                  'Last Name',
                                  style: material.TextStyle(
                                    fontSize: 14,
                                    fontWeight: material.FontWeight.w600,
                                    color: material.Colors.grey[800],
                                  ),
                                ),
                                const material.SizedBox(height: 6),
                                material.Container(
                                  decoration: material.BoxDecoration(
                                    color: material.Colors.grey[50],
                                    borderRadius:
                                        material.BorderRadius.circular(16),
                                    border: material.Border.all(
                                      color: material.Colors.grey[200]!,
                                    ),
                                  ),
                                  child: material.Padding(
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                    child: material.TextField(
                                      controller: _lastNameController,
                                      textInputAction:
                                          material.TextInputAction.next,
                                      style: material.TextStyle(
                                        fontSize: 15,
                                        fontWeight: material.FontWeight.w500,
                                      ),
                                      decoration: material.InputDecoration(
                                        hintText: 'Enter your last name',
                                        hintStyle: material.TextStyle(
                                          color: material.Colors.grey[400],
                                          fontSize: 15,
                                        ),
                                        border: material.InputBorder.none,
                                        contentPadding:
                                            const material.EdgeInsets.symmetric(
                                              vertical: 14.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const material.SizedBox(height: 16),

                            // Phone Number Field
                            material.Column(
                              crossAxisAlignment:
                                  material.CrossAxisAlignment.start,
                              children: [
                                material.Text(
                                  'Phone Number',
                                  style: material.TextStyle(
                                    fontSize: 14,
                                    fontWeight: material.FontWeight.w600,
                                    color: material.Colors.grey[800],
                                  ),
                                ),
                                const material.SizedBox(height: 6),
                                material.Row(
                                  children: [
                                    // Country Code Selector
                                    material.Container(
                                      decoration: material.BoxDecoration(
                                        color: material.Colors.grey[50],
                                        borderRadius:
                                            material.BorderRadius.circular(16),
                                        border: material.Border.all(
                                          color: material.Colors.grey[200]!,
                                        ),
                                      ),
                                      child: material.Material(
                                        color: material.Colors.transparent,
                                        child: material.InkWell(
                                          onTap: _showCountrySelector,
                                          borderRadius: material
                                              .BorderRadius.circular(16),
                                          child: material.Padding(
                                            padding:
                                                const material.EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 14,
                                                ),
                                            child: material.Row(
                                              mainAxisSize:
                                                  material.MainAxisSize.min,
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
                                                  _selectedCountry.dialCode,
                                                  style: material.TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: material
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
                                                  color:
                                                      material.Colors.grey[600],
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
                                            color: material.Colors.grey[200]!,
                                          ),
                                        ),
                                        child: material.Padding(
                                          padding:
                                              const material.EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                              ),
                                          child: material.TextField(
                                            controller: _phoneController,
                                            keyboardType:
                                                material.TextInputType.phone,
                                            textInputAction:
                                                material.TextInputAction.done,
                                            onChanged: (value) =>
                                                _updateCompletePhoneNumber(),
                                            style: material.TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                                  material.FontWeight.w500,
                                            ),
                                            decoration: material.InputDecoration(
                                              hintText:
                                                  'Enter your phone number',
                                              hintStyle: material.TextStyle(
                                                color:
                                                    material.Colors.grey[400],
                                                fontSize: 15,
                                              ),
                                              border: material.InputBorder.none,
                                              contentPadding:
                                                  const material.EdgeInsets.symmetric(
                                                    vertical: 14.0,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ] else ...[
                            // OTP Field
                            material.Column(
                              crossAxisAlignment:
                                  material.CrossAxisAlignment.start,
                              children: [
                                material.Text(
                                  'Verification Code',
                                  style: material.TextStyle(
                                    fontSize: 14,
                                    fontWeight: material.FontWeight.w600,
                                    color: material.Colors.grey[800],
                                  ),
                                ),
                                const material.SizedBox(height: 6),
                                material.Container(
                                  decoration: material.BoxDecoration(
                                    color: material.Colors.grey[50],
                                    borderRadius:
                                        material.BorderRadius.circular(16),
                                    border: material.Border.all(
                                      color: material.Colors.grey[200]!,
                                    ),
                                  ),
                                  child: material.Padding(
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                    child: material.TextField(
                                      controller: _otpController,
                                      keyboardType:
                                          material.TextInputType.number,
                                      textAlign: material.TextAlign.center,
                                      textInputAction:
                                          material.TextInputAction.done,
                                      style: material.TextStyle(
                                        fontSize: 18,
                                        fontWeight: material.FontWeight.w600,
                                        letterSpacing: 3,
                                      ),
                                      decoration: material.InputDecoration(
                                        hintText: '000000',
                                        hintStyle: material.TextStyle(
                                          color: material.Colors.grey[400],
                                          fontSize: 18,
                                          letterSpacing: 3,
                                        ),
                                        border: material.InputBorder.none,
                                        contentPadding:
                                            const material.EdgeInsets.symmetric(
                                              vertical: 14.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const material.SizedBox(height: 24),

                          // Action Button
                          material.Container(
                            decoration: material.BoxDecoration(
                              gradient: const material.LinearGradient(
                                colors: [
                                  material.Colors.teal,
                                  material.Colors.teal,
                                ],
                              ),
                              borderRadius: material.BorderRadius.circular(14),
                              boxShadow: [
                                material.BoxShadow(
                                  color: material.Colors.teal.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const material.Offset(0, 8),
                                ),
                              ],
                            ),
                            child: material.Material(
                              color: material.Colors.transparent,
                              child: material.InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () {
                                        !_isOtpSent
                                            ? handleSendOtp()
                                            : handleVerifyOtp();
                                      },
                                borderRadius: material.BorderRadius.circular(
                                  14,
                                ),
                                child: material.Padding(
                                  padding: const material.EdgeInsets.symmetric(
                                    vertical: 14,
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
                                          !_isOtpSent
                                              ? 'Send OTP'
                                              : 'Verify & Create Account',
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
                                          material.Icons.arrow_forward_rounded,
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

                          const material.SizedBox(height: 20),

                          // Login Link
                          material.Row(
                            mainAxisAlignment:
                                material.MainAxisAlignment.center,
                            children: [
                              material.Text(
                                "Already have an account? ",
                                style: material.TextStyle(
                                  color: material.Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              material.GestureDetector(
                                onTap: () {
                                  material.Navigator.pop(context);
                                },
                                child: material.Text(
                                  'Sign In',
                                  style: material.TextStyle(
                                    color: material.Colors.teal,
                                    fontWeight: material.FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const material.Spacer(),

                    // Footer
                    material.Text(
                      'By creating an account, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        color: material.Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),

                    const material.SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
