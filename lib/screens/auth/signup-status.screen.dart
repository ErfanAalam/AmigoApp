import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_service.dart';
import '../../models/country.model.dart' as country_model;
import '../../providers/theme-color.provider.dart';
import '../../ui/country-selector.modal.dart';
import '../../ui/snackbar.dart';
import 'auth-ui.dart';

class SignupStatusScreen extends ConsumerStatefulWidget {
  const SignupStatusScreen({super.key});

  @override
  ConsumerState<SignupStatusScreen> createState() => _SignupStatusScreenState();
}

class _SignupStatusScreenState extends ConsumerState<SignupStatusScreen> {
  final _phoneController = TextEditingController();
  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isLoading = false;
  Map<String, dynamic>? _statusData;

  final apiService = ApiService();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

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

  void _checkStatus() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 8) {
      Snack.warning('Please enter a valid phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusData = null;
    });

    final response = (await apiService.auth.getSignupRequestStatus(
      _completePhoneNumber.replaceAll(' ', ''),
    )).toMap();

    setState(() {
      _isLoading = false;
    });

    if (response['success'] == true && response['data'] != null) {
      dynamic data = response['data'];
      if (data is List && data.isNotEmpty) {
        data = data[0];
      }
      setState(() {
        _statusData = data is Map<String, dynamic> ? data : null;
      });
    } else if (response['success'] == false && response['code'] == 404) {
      Snack.warning('No signup request found for this phone number.');
      setState(() {
        _statusData = null;
      });
    } else {
      Snack.error(
        'Error checking status: ${response['message'] ?? 'Unknown error'}',
      );
      setState(() {
        _statusData = null;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      case 'pending':
      default:
        return const Color(0xFFEF6C00);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_rounded;
      case 'rejected':
        return Icons.close_rounded;
      case 'pending':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return AuthScaffold(
      theme: themeColor,
      topRightAction: AuthChipButton(
        icon: Icons.arrow_back_rounded,
        label: 'Back',
        theme: themeColor,
        onTap: () => Navigator.pop(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthLogo(icon: Icons.fact_check_outlined, theme: themeColor),
          const SizedBox(height: 24),
          AuthHeader(
            title: 'Signup status',
            subtitle:
                'Enter your phone number to check your signup request status.',
            theme: themeColor,
          ),
          const SizedBox(height: 32),
          AuthCard(
            theme: themeColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _updateCompletePhoneNumber(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Check status',
                  trailingIcon: Icons.search_rounded,
                  loading: _isLoading,
                  theme: themeColor,
                  onPressed: _checkStatus,
                ),
                if (_statusData != null) ...[
                  const SizedBox(height: 20),
                  _statusCard(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final status = (_statusData!['status'] ?? 'pending').toString();
    final color = _getStatusColor(status);
    final hasName =
        _statusData!['first_name'] != null || _statusData!['last_name'] != null;
    final hasDate = _statusData!['created_at'] != null;
    final hasReason = _statusData!['rejected_reason'] != null &&
        _statusData!['rejected_reason'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasName) ...[
            const SizedBox(height: 14),
            _statusRow(
              icon: Icons.person_outline,
              text:
                  '${_statusData!['first_name'] ?? ''} ${_statusData!['last_name'] ?? ''}'
                      .trim(),
            ),
          ],
          if (hasDate) ...[
            const SizedBox(height: 10),
            _statusRow(
              icon: Icons.calendar_today_outlined,
              text: 'Requested on ${_formatDate(_statusData!['created_at'])}',
            ),
          ],
          if (hasReason) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.red[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rejection reason',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusData!['rejected_reason'].toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'N/A';
      String dateStr = dateValue.toString();
      if (dateStr.contains('T')) {
        DateTime date = DateTime.parse(dateStr);
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return dateStr;
    } catch (e) {
      return dateValue.toString();
    }
  }
}
