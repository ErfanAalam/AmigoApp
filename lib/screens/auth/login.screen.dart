import 'package:amigo/utils/user.utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_service.dart';
import '../../config/app-colors.config.dart';
import '../../models/country.model.dart' as country_model;
import '../../models/user.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/auth/auth.service.dart';
import '../../services/socket/transport.manager.dart';
import '../../services/cookies.service.dart';
import '../../ui/country-selector.modal.dart';
import '../../ui/snackbar.dart';
import '../home.layout.dart';
import '../../main.dart' as main;
import 'auth-ui.dart';
import 'signup.screen.dart';
import 'signup-status.screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isPhoneSubmitted = false;
  bool _isLoading = false;

  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final TransportManager transportManager = TransportManager();
  final CookieService cookieService = CookieService();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool get _isGuestNumber => _phoneController.text.startsWith('100100100');

  void _updateCompletePhoneNumber() {
    setState(() {
      _completePhoneNumber = _selectedCountry.dialCode + _phoneController.text;
    });
  }

  void _showCountrySelector() {
    showDialog(
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
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await apiService.auth.sendLoginOtp(_completePhoneNumber);
    if (response.isSuccess) {
      Snack.success('OTP sent successfully');
      setState(() {
        _isPhoneSubmitted = true;
        _isLoading = false;
      });
    } else if (response.isSuccess == false && response.code == 404) {
      Snack.warning('Phone number not found! Please Signup First');
      setState(() {
        _isLoading = false;
      });
    } else {
      Snack.error('Failed to send OTP');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void handleOtpSubmit() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 6) {
      Snack.error('Please enter the OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiService.auth.verifyLoginOtp(
        phoneNumber: _completePhoneNumber,
        otp: int.parse(_otpController.text),
      );

      if (response.isSuccess) {
        Snack.success('OTP verified successfully');

        final appVersion = await UserUtils().getAppVersion();
        await apiService.user.updateUser({'app_version': appVersion});

        if (response.data != null) {
          final userDetail = {
            'id': response.data!['id'],
            'name': response.data!['name'],
            'phone': response.data!['phone'],
            'role': response.data!['role'],
            'profile_pic': response.data!['profile_pic'],
            'created_at': response.data!['created_at'],
            'call_access': response.data!['call_access'],
          };

          await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));
        } else {
          Snack.warning(
            'Unable to fetch user details. Please update your profile after login.',
          );
        }

        final appState = main.MyApp.appStateKey.currentState;
        if (appState != null && appState is main.AppStateInterface) {
          await (appState as main.AppStateInterface)
              .initializeAuthenticatedUser();
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        Snack.error('Failed to verify OTP');
      }
    } catch (e) {
      Snack.error('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void handleGuestLogin() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 8) {
      Snack.error('Please enter a valid phone number.');
      return;
    }

    Environment.setGuestMode(true);

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiService.auth.verifyLoginOtp(
        phoneNumber: _completePhoneNumber,
        otp: 0,
      );

      if (response.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', true);

        Snack.success('Logged in as guest');

        final appVersion = await UserUtils().getAppVersion();
        await apiService.user.updateUser({'app_version': appVersion});

        if (response.data != null) {
          final userDetail = {
            'id': response.data!['id'],
            'name': response.data!['name'],
            'phone': response.data!['phone'],
            'role': response.data!['role'],
            'profile_pic': response.data!['profile_pic'],
            'created_at': response.data!['created_at'],
            'call_access': response.data!['call_access'],
          };

          await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));
        } else {
          Snack.warning(
            'Unable to fetch user details. Please update your profile after login.',
          );
        }

        final appState = main.MyApp.appStateKey.currentState;
        if (appState != null && appState is main.AppStateInterface) {
          await (appState as main.AppStateInterface)
              .initializeAuthenticatedUser();
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        Environment.setGuestMode(false);
        Snack.error('Guest login failed');
      }
    } catch (e) {
      Environment.setGuestMode(false);
      Snack.error('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String get _buttonLabel {
    if (_isGuestNumber) return 'Guest Login';
    return _isPhoneSubmitted ? 'Verify & Continue' : 'Send OTP';
  }

  void _handlePrimaryAction() {
    if (_isGuestNumber) {
      handleGuestLogin();
    } else if (!_isPhoneSubmitted) {
      handlePhoneSubmit();
    } else {
      handleOtpSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return AuthScaffold(
      theme: themeColor,
      topRightAction: AuthChipButton(
        icon: Icons.info_outline_rounded,
        label: 'Check Status',
        theme: themeColor,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignupStatusScreen()),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: themeColor.primary.withOpacity(0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 15),
          AuthHeader(
            title: 'Amigo Chats',
            subtitle: !_isPhoneSubmitted
                ? 'Welcome back. Sign in to continue.'
                : 'Enter the code we just sent.',
            theme: themeColor,
          ),
          const SizedBox(height: 20),
          AuthCard(
            theme: themeColor,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isPhoneSubmitted)
                    _phoneSection()
                  else
                    _otpSection(themeColor),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: _buttonLabel,
                    trailingIcon: Icons.arrow_forward_rounded,
                    loading: _isLoading,
                    theme: themeColor,
                    onPressed: _handlePrimaryAction,
                  ),
                  if (_isPhoneSubmitted) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: GestureDetector(
                        onTap: handlePhoneSubmit,
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: themeColor.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: themeColor.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AuthLinkRow(
                    prefix: "Don't have an account? ",
                    linkLabel: 'Sign Up',
                    theme: themeColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthFooterText(
            'By continuing, you agree to our Terms of Service\nand Privacy Policy',
            theme: themeColor,
          ),
        ],
      ),
    );
  }

  Widget _phoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Phone number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            CountryCodeButton(
              country: _selectedCountry,
              onTap: _showCountrySelector,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AuthInput(
                controller: _phoneController,
                hint: 'Phone number',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _updateCompletePhoneNumber(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpSection(ColorTheme themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isPhoneSubmitted = false),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: themeColor.primary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Verification code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AuthInput(
          controller: _otpController,
          hint: '000000',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          fontSize: 20,
          letterSpacing: 6,
        ),
      ],
    );
  }
}
