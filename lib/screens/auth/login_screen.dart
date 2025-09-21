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
      backgroundColor: material.Colors.white,
      body: material.SafeArea(
        child: material.Padding(
          padding: const material.EdgeInsets.all(20.0),
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
                'Welcome Back!',
                textAlign: material.TextAlign.center,
                style: material.TextStyle(
                  fontSize: 28,
                  fontWeight: material.FontWeight.bold,
                  color: material.Colors.black87,
                ),
              ),
              const material.SizedBox(height: 10),
              material.Text(
                !_isPhoneSubmitted
                    ? 'Sign in to continue'
                    : 'Enter the OTP sent to your phone',
                textAlign: material.TextAlign.center,
                style: material.TextStyle(
                  fontSize: 16,
                  color: material.Colors.grey[600],
                ),
              ),
              const material.SizedBox(height: 40),

              // Phone Number Field or OTP Field based on state
              !_isPhoneSubmitted
                  ? material.Row(
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
                    )
                  : material.Container(
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
              const material.SizedBox(height: 30),

              // Login Button - changes based on state
              material.ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        !_isPhoneSubmitted
                            ? handlePhoneSubmit()
                            : handleOtpSubmit();
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
                        !_isPhoneSubmitted ? 'Get OTP' : 'Verify & Sign In',
                        style: const material.TextStyle(
                          fontSize: 16,
                          fontWeight: material.FontWeight.bold,
                        ),
                      ),
              ),
              const material.SizedBox(height: 20),

              // Sign Up Link
              material.Row(
                mainAxisAlignment: material.MainAxisAlignment.center,
                children: [
                  material.Text(
                    "Don't have an account? ",
                    style: material.TextStyle(color: material.Colors.grey[600]),
                  ),
                  material.GestureDetector(
                    onTap: () {
                      // Navigate to sign up screen
                      material.Navigator.push(
                        context,
                        material.MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const material.Text(
                      'Sign Up',
                      style: material.TextStyle(
                        color: material.Colors.blue,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
