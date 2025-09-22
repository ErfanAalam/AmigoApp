import 'package:flutter/material.dart' as material;
import '../main_screen.dart';
import 'signup_screen.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/country_model.dart' as country_model;
import '../../widgets/country_selector_modal.dart';

class LoginScreen extends material.StatefulWidget {
  const LoginScreen({material.Key? key}) : super(key: key);

  @override
  material.State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends material.State<LoginScreen> {
  final _phoneController = material.TextEditingController();
  final _otpController = material.TextEditingController();
  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('US');
  bool _isPhoneSubmitted = false;
  bool _isLoading = false;

  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();

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
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Please enter a valid phone number.'),
        ),
      );
      return;
    }

    final response = await apiService.send_login_otp(_completePhoneNumber);
    // print('this is the response: $response');

    if (response['success']) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('OTP sent successfully'),
        ),
      );
      setState(() {
        _isPhoneSubmitted = true;
      });
    } else {
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(content: material.Text('Failed to send OTP')),
      );
    }
  }

  void handleOtpSubmit() async {
    print('OTP button pressed');

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

    try {
      final response = await apiService.verify_login_otp(
        _completePhoneNumber,
        int.parse(_otpController.text),
      );

      if (response['success']) {
        // Authentication is handled in the API service interceptor
        // which automatically stores cookies and updates auth state
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('OTP verified successfully'),
          ),
        );

        // Navigate to main screen after login
        material.Navigator.pushReplacement(
          context,
          material.MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('Failed to verify OTP'),
          ),
        );
      }
    } catch (e) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        material.SnackBar(content: material.Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if user is already authenticated
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await authService.isAuthenticated();
    if (isAuthenticated) {
      // Navigate to main screen if already authenticated
      material.WidgetsBinding.instance.addPostFrameCallback((_) {
        material.Navigator.pushReplacement(
          context,
          material.MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      });
    }
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
                    const material.SizedBox(height: 60),

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
                      child: material.Column(
                        crossAxisAlignment: material.CrossAxisAlignment.stretch,
                        children: [
                          // Phone Number Field or OTP Field based on state
                          !_isPhoneSubmitted
                              ? material.Column(
                                  crossAxisAlignment:
                                      material.CrossAxisAlignment.start,
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
                                                      horizontal: 2,
                                                      vertical: 8,
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
                                                color:
                                                    material.Colors.grey[200]!,
                                              ),
                                            ),
                                            child: material.Padding(
                                              padding:
                                                  const material.EdgeInsets.symmetric(
                                                    horizontal: 6.0,
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
                                                  fontWeight:
                                                      material.FontWeight.w500,
                                                ),
                                                decoration: material.InputDecoration(
                                                  hintText:
                                                      'Enter your phone number',
                                                  hintStyle: material.TextStyle(
                                                    color: material
                                                        .Colors
                                                        .grey[400],
                                                    fontSize: 16,
                                                  ),
                                                  border:
                                                      material.InputBorder.none,
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
                                  children: [
                                    material.Text(
                                      'Verification Code',
                                      style: material.TextStyle(
                                        fontSize: 16,
                                        fontWeight: material.FontWeight.w600,
                                        color: material.Colors.grey[800],
                                      ),
                                    ),
                                    const material.SizedBox(height: 8),
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
                                              horizontal: 20.0,
                                            ),
                                        child: material.TextField(
                                          controller: _otpController,
                                          keyboardType:
                                              material.TextInputType.number,
                                          textAlign: material.TextAlign.center,
                                          style: material.TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                material.FontWeight.w600,
                                            letterSpacing: 4,
                                          ),
                                          decoration: material.InputDecoration(
                                            hintText: '000000',
                                            hintStyle: material.TextStyle(
                                              color: material.Colors.grey[400],
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
                              gradient: const material.LinearGradient(
                                colors: [
                                  material.Colors.teal,
                                  material.Colors.teal,
                                ],
                              ),
                              borderRadius: material.BorderRadius.circular(16),
                              boxShadow: [
                                material.BoxShadow(
                                  color: const material.Color(
                                    0xFF667eea,
                                  ).withOpacity(0.3),
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
                                  padding: const material.EdgeInsets.symmetric(
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
                                    color: const material.Color(0xFF667eea),
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
      ),
    );
  }
}
