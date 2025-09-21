import 'package:flutter/material.dart' as material;
import '../main_screen.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/country_model.dart' as country_model;
import '../../widgets/country_selector_modal.dart';

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

    // setState(() {
    //   _isLoading = true;
    // });

    // TODO: Implement send OTP API call
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call

    // setState(() {
    //   _isOtpSent = true;
    //   _isLoading = false;
    // });

    // material.ScaffoldMessenger.of(context).showSnackBar(
    //   const material.SnackBar(content: material.Text('OTP sent successfully')),
    // );
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
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Account created successfully'),
        ),
      );
      material.Navigator.pushReplacement(
        context,
        material.MaterialPageRoute(builder: (context) => const MainScreen()),
      );
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
      backgroundColor: material.Colors.white,
      resizeToAvoidBottomInset: true,
      body: material.SafeArea(
        child: material.SingleChildScrollView(
          padding: const material.EdgeInsets.all(20.0),
          child: material.SizedBox(
            height:
                material.MediaQuery.of(context).size.height -
                material.MediaQuery.of(context).padding.top -
                material.MediaQuery.of(context).padding.bottom -
                40,
            child: material.Column(
              mainAxisAlignment: material.MainAxisAlignment.center,
              crossAxisAlignment: material.CrossAxisAlignment.stretch,
              children: [
                // App Logo/Title
                const material.Icon(
                  material.Icons.chat_bubble_outline,
                  size: 80,
                  color: material.Colors.blue,
                ),
                const material.SizedBox(height: 20),
                const material.Text(
                  'Create Account',
                  textAlign: material.TextAlign.center,
                  style: material.TextStyle(
                    fontSize: 28,
                    fontWeight: material.FontWeight.bold,
                    color: material.Colors.black87,
                  ),
                ),
                const material.SizedBox(height: 10),
                material.Text(
                  !_isOtpSent
                      ? 'Sign up to get started'
                      : 'Enter the OTP sent to your phone',
                  textAlign: material.TextAlign.center,
                  style: material.TextStyle(
                    fontSize: 16,
                    color: material.Colors.grey[600],
                  ),
                ),
                const material.SizedBox(height: 40),

                // Form Fields
                if (!_isOtpSent) ...[
                  // First Name Field
                  material.Container(
                    decoration: material.BoxDecoration(
                      color: const material.Color(0xFFFAFAFA),
                      borderRadius: material.BorderRadius.circular(10),
                      border: material.Border.all(
                        color: material.Colors.grey.shade300,
                      ),
                    ),
                    child: material.Padding(
                      padding: const material.EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 0.0,
                      ),
                      child: material.TextField(
                        controller: _firstNameController,
                        textInputAction: material.TextInputAction.next,
                        decoration: const material.InputDecoration(
                          labelText: 'First Name',
                          border: material.InputBorder.none,
                          contentPadding: material.EdgeInsets.symmetric(
                            vertical: 15.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const material.SizedBox(height: 20),

                  // Last Name Field
                  material.Container(
                    decoration: material.BoxDecoration(
                      color: const material.Color(0xFFFAFAFA),
                      borderRadius: material.BorderRadius.circular(10),
                      border: material.Border.all(
                        color: material.Colors.grey.shade300,
                      ),
                    ),
                    child: material.Padding(
                      padding: const material.EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 0.0,
                      ),
                      child: material.TextField(
                        controller: _lastNameController,
                        textInputAction: material.TextInputAction.next,
                        decoration: const material.InputDecoration(
                          labelText: 'Last Name',
                          border: material.InputBorder.none,
                          contentPadding: material.EdgeInsets.symmetric(
                            vertical: 15.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const material.SizedBox(height: 20),

                  // Phone Number Field
                  material.Row(
                    children: [
                      // Country Code Selector
                      CountrySelectorButton(
                        selectedCountry: _selectedCountry,
                        onTap: _showCountrySelector,
                      ),
                      const material.SizedBox(width: 12),
                      // Phone Number Input
                      material.Expanded(
                        child: material.Container(
                          decoration: material.BoxDecoration(
                            color: const material.Color(0xFFFAFAFA),
                            borderRadius: material.BorderRadius.circular(10),
                            border: material.Border.all(
                              color: material.Colors.grey.shade300,
                            ),
                          ),
                          child: material.Padding(
                            padding: const material.EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 0.0,
                            ),
                            child: material.TextField(
                              controller: _phoneController,
                              keyboardType: material.TextInputType.phone,
                              textInputAction: material.TextInputAction.done,
                              onChanged: (value) =>
                                  _updateCompletePhoneNumber(),
                              decoration: const material.InputDecoration(
                                hintText: 'Phone Number',
                                border: material.InputBorder.none,
                                contentPadding: material.EdgeInsets.symmetric(
                                  vertical: 15.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // OTP Field
                  material.Container(
                    decoration: material.BoxDecoration(
                      color: const material.Color(0xFFFAFAFA),
                      borderRadius: material.BorderRadius.circular(10),
                      border: material.Border.all(
                        color: material.Colors.grey.shade300,
                      ),
                    ),
                    child: material.Padding(
                      padding: const material.EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 0.0,
                      ),
                      child: material.TextField(
                        controller: _otpController,
                        keyboardType: material.TextInputType.number,
                        textInputAction: material.TextInputAction.done,
                        decoration: const material.InputDecoration(
                          labelText: 'Enter OTP',
                          border: material.InputBorder.none,
                          contentPadding: material.EdgeInsets.symmetric(
                            vertical: 15.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const material.SizedBox(height: 30),

                // Action Button
                material.ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          !_isOtpSent ? handleSendOtp() : handleVerifyOtp();
                        },
                  style: material.ElevatedButton.styleFrom(
                    backgroundColor: material.Colors.blue,
                    foregroundColor: material.Colors.white,
                    padding: const material.EdgeInsets.symmetric(vertical: 15),
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const material.SizedBox(
                          height: 20,
                          width: 20,
                          child: material.CircularProgressIndicator(
                            color: material.Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : material.Text(
                          !_isOtpSent ? 'Send OTP' : 'Verify & Create Account',
                          style: const material.TextStyle(
                            fontSize: 16,
                            fontWeight: material.FontWeight.bold,
                          ),
                        ),
                ),
                const material.SizedBox(height: 20),

                // Login Link
                material.Row(
                  mainAxisAlignment: material.MainAxisAlignment.center,
                  children: [
                    material.Text(
                      "Already have an account? ",
                      style: material.TextStyle(
                        color: material.Colors.grey[600],
                      ),
                    ),
                    material.GestureDetector(
                      onTap: () {
                        // Navigate back to login screen
                        material.Navigator.pop(context);
                      },
                      child: const material.Text(
                        'Sign In',
                        style: material.TextStyle(
                          color: material.Colors.blue,
                          fontWeight: material.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const material.SizedBox(height: 40), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}
