import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_service.dart';
import '../../models/country.model.dart' as country_model;
import '../../models/user.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/auth/auth.service.dart';
import '../../services/fcm/fcm-init.service.dart';
import '../../services/socket/transport.manager.dart';
import '../../services/cookies.service.dart';
import '../../ui/country-selector.modal.dart';
import '../../ui/setup-loading.popup.dart';
import '../../ui/snackbar.dart';
import '../../utils/user.utils.dart';
import '../../main.dart' as main;
import '../home.layout.dart';
import 'auth-ui.dart';
import 'signup-status.screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isOtpSent = false;
  bool _isLoading = false;

  final apiService = ApiService();
  final AuthService authService = AuthService();
  final NotificationService notificationService = NotificationService();
  final TransportManager transportManager = TransportManager();
  final CookieService cookieService = CookieService();

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SetupLoadingPopup(),
    );

    Future.delayed(const Duration(seconds: 2), () {
      _restartApp();
    });
  }

  void _restartApp() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
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

  void handleSendOtp() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _phoneController.text.length < 8) {
      Snack.warning('Please fill all fields correctly.');
      return;
    }

    final response = (await apiService.auth.generateSignupOtp(
      _completePhoneNumber.replaceAll(' ', ''),
    )).toMap();

    if (response['success']) {
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
        Snack.success('Signup OTP sent successfully');
      });
    } else if (response['success'] == false && response['code'] == 409) {
      Snack.warning('Phone number already exists! Please Login');
    } else {
      setState(() {
        _isLoading = false;
        Snack.error('Error sending Signup OTP');
      });
    }
  }

  void handleVerifyOtp() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 6) {
      Snack.warning('Please enter the OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = (await apiService.auth.verifySignupOtp(
      phoneNumber: _completePhoneNumber.replaceAll(' ', ''),
      otp: int.parse(_otpController.text),
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    )).toMap();

    if (response['success']) {
      _showSetupLoadingPopup();

      if (mounted) {
        Snack.success('Signup successful! Welcome to Amigo Chats!');
      }

      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _otpController.clear();
      setState(() {
        _isOtpSent = false;
        _isLoading = false;
      });

      final appVersion = await UserUtils().getAppVersion();
      await apiService.user.updateUser({'app_version': appVersion});

      final userDetail = {
        'id': response['data']['id'],
        'name': response['data']['name'],
        'phone': response['data']['phone'],
        'role': response['data']['role'],
        'profile_pic': null,
        'created_at': DateTime.now().toIso8601String(),
        'call_access': response['data']['call_access'] ?? true,
      };

      await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));

      final appState = main.MyApp.appStateKey.currentState;
      if (appState != null && appState is main.AppStateInterface) {
        await (appState as main.AppStateInterface)
            .initializeAuthenticatedUser();
      }
    } else {
      if (mounted) {
        Snack.error('Error verifying Signup OTP');
      }
    }

    setState(() {
      _isLoading = false;
    });
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
          MaterialPageRoute(
            builder: (context) => const SignupStatusScreen(),
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthLogo(icon: Icons.person_add_alt_1_rounded, theme: themeColor),
          const SizedBox(height: 24),
          AuthHeader(
            title: 'Create account',
            subtitle: !_isOtpSent
                ? 'Join the conversation. It only takes a minute.'
                : 'Enter the code we just sent.',
            theme: themeColor,
          ),
          const SizedBox(height: 32),
          AuthCard(
            theme: themeColor,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isOtpSent)
                    _detailsSection()
                  else
                    _otpSection(),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: !_isOtpSent ? 'Send OTP' : 'Verify & Create Account',
                    trailingIcon: Icons.arrow_forward_rounded,
                    loading: _isLoading,
                    theme: themeColor,
                    onPressed: () {
                      !_isOtpSent ? handleSendOtp() : handleVerifyOtp();
                    },
                  ),
                  const SizedBox(height: 18),
                  AuthLinkRow(
                    prefix: 'Already have an account? ',
                    linkLabel: 'Sign In',
                    theme: themeColor,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthFooterText(
            'By creating an account, you agree to our Terms of Service\nand Privacy Policy',
            theme: themeColor,
          ),
        ],
      ),
    );
  }

  Widget _detailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthInput(
          controller: _firstNameController,
          hint: 'First name',
          label: 'First name',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AuthInput(
          controller: _lastNameController,
          hint: 'Last name',
          label: 'Last name',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _updateCompletePhoneNumber(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Verification code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        AuthInput(
          controller: _otpController,
          hint: '000000',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          fontSize: 20,
          letterSpacing: 6,
        ),
      ],
    );
  }
}
