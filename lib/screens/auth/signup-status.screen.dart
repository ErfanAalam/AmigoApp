import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/auth.api-client.dart';
import '../../models/country.model.dart' as country_model;
import '../../providers/theme-color.provider.dart';
import '../../ui/country-selector.modal.dart';
import '../../ui/snackbar.dart';

class SignupStatusScreen extends ConsumerStatefulWidget {
  const SignupStatusScreen({super.key});

  @override
  ConsumerState<SignupStatusScreen> createState() => _SignupStatusScreenState();
}

class _SignupStatusScreenState extends ConsumerState<SignupStatusScreen> {
  final _phoneController = material.TextEditingController();
  String _completePhoneNumber = '';
  country_model.Country _selectedCountry =
      country_model.CountryData.getCountryByCode('IN');
  bool _isLoading = false;
  Map<String, dynamic>? _statusData;

  final ApiService apiService = ApiService();

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

  void _checkStatus() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 8) {
      Snack.warning('Please enter a valid phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusData = null;
    });

    final response = await apiService.getSignupRequestStatus(
      _completePhoneNumber.replaceAll(' ', ''),
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success'] == true && response['data'] != null) {
      // Handle both array and object responses (for backward compatibility)
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
      Snack.error('Error checking status: ${response['message'] ?? 'Unknown error'}');
      setState(() {
        _statusData = null;
      });
    }
  }

  material.Color _getStatusMaterialColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return material.Colors.green;
      case 'rejected':
        return material.Colors.red;
      case 'pending':
      default:
        return material.Colors.orange;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return '✓';
      case 'rejected':
        return '✗';
      case 'pending':
      default:
        return '⏳';
    }
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
                        material.Icons.info_outline_rounded,
                        size: 40,
                        color: material.Colors.white,
                      ),
                    ),

                    const material.SizedBox(height: 20),

                    // App Name
                    const material.Text(
                      'Check Signup Status',
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
                    const material.Text(
                      'Enter your phone number to check your signup request status',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 14,
                        color: material.Colors.white,
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
                          // Phone Number Field
                          material.Column(
                            crossAxisAlignment: material.CrossAxisAlignment.start,
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
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
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
                          const material.SizedBox(height: 24),

                          // Check Status Button
                          material.Container(
                            decoration: material.BoxDecoration(
                              gradient: material.LinearGradient(
                                colors: [
                                  themeColor.primary,
                                  themeColor.primary,
                                ],
                              ),
                              borderRadius: material.BorderRadius.circular(14),
                              boxShadow: [
                                material.BoxShadow(
                                  color: themeColor.primary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const material.Offset(0, 8),
                                ),
                              ],
                            ),
                            child: material.Material(
                              color: material.Colors.transparent,
                              child: material.InkWell(
                                onTap: _isLoading ? null : _checkStatus,
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
                                          'Check Status',
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
                                          material.Icons.search_rounded,
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

                          // Status Display
                          if (_statusData != null) ...[
                            const material.SizedBox(height: 24),
                            material.Divider(
                              color: material.Colors.grey[300],
                              thickness: 1,
                            ),
                            const material.SizedBox(height: 24),
                            material.Container(
                              padding: const material.EdgeInsets.all(16),
                              decoration: material.BoxDecoration(
                                color: _getStatusMaterialColor(
                                  _statusData!['status'] ?? 'pending',
                                ).withOpacity(0.1),
                                borderRadius: material.BorderRadius.circular(12),
                                border: material.Border.all(
                                  color: _getStatusMaterialColor(
                                    _statusData!['status'] ?? 'pending',
                                  ).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: material.Column(
                                crossAxisAlignment:
                                    material.CrossAxisAlignment.start,
                                children: [
                                  material.Row(
                                    children: [
                                      material.Container(
                                        padding: const material.EdgeInsets.all(8),
                                        decoration: material.BoxDecoration(
                                          color: _getStatusMaterialColor(
                                            _statusData!['status'] ?? 'pending',
                                          ),
                                          shape: material.BoxShape.circle,
                                        ),
                                        child: material.Text(
                                          _getStatusIcon(
                                            _statusData!['status'] ?? 'pending',
                                          ),
                                          style: const material.TextStyle(
                                            color: material.Colors.white,
                                            fontSize: 16,
                                            fontWeight: material.FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const material.SizedBox(width: 12),
                                      material.Expanded(
                                        child: material.Column(
                                          crossAxisAlignment:
                                              material.CrossAxisAlignment.start,
                                          children: [
                                            material.Text(
                                              'Status',
                                              style: material.TextStyle(
                                                fontSize: 12,
                                                color: material.Colors.grey[600],
                                                fontWeight: material.FontWeight.w500,
                                              ),
                                            ),
                                            const material.SizedBox(height: 2),
                                            material.Text(
                                              (_statusData!['status'] ?? 'pending')
                                                  .toString()
                                                  .toUpperCase(),
                                              style: material.TextStyle(
                                                fontSize: 18,
                                                fontWeight: material.FontWeight.bold,
                                                color: _getStatusMaterialColor(
                                                  _statusData!['status'] ?? 'pending',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_statusData!['first_name'] != null ||
                                      _statusData!['last_name'] != null) ...[
                                    const material.SizedBox(height: 16),
                                    material.Divider(
                                      color: material.Colors.grey[300],
                                      height: 1,
                                    ),
                                    const material.SizedBox(height: 12),
                                    material.Row(
                                      children: [
                                        material.Icon(
                                          material.Icons.person_outline,
                                          size: 18,
                                          color: material.Colors.grey[600],
                                        ),
                                        const material.SizedBox(width: 8),
                                        material.Expanded(
                                          child: material.Text(
                                            '${_statusData!['first_name'] ?? ''} ${_statusData!['last_name'] ?? ''}'.trim(),
                                            style: material.TextStyle(
                                              fontSize: 14,
                                              fontWeight: material.FontWeight.w600,
                                              color: material.Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_statusData!['created_at'] != null) ...[
                                    const material.SizedBox(height: 12),
                                    material.Row(
                                      children: [
                                        material.Icon(
                                          material.Icons.calendar_today_outlined,
                                          size: 18,
                                          color: material.Colors.grey[600],
                                        ),
                                        const material.SizedBox(width: 8),
                                        material.Expanded(
                                          child: material.Text(
                                            'Requested on: ${_formatDate(_statusData!['created_at'])}',
                                            style: material.TextStyle(
                                              fontSize: 13,
                                              color: material.Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_statusData!['rejected_reason'] != null &&
                                      _statusData!['rejected_reason'].toString().isNotEmpty) ...[
                                    const material.SizedBox(height: 16),
                                    material.Divider(
                                      color: material.Colors.grey[300],
                                      height: 1,
                                    ),
                                    const material.SizedBox(height: 12),
                                    material.Row(
                                      crossAxisAlignment:
                                          material.CrossAxisAlignment.start,
                                      children: [
                                        material.Icon(
                                          material.Icons.info_outline,
                                          size: 18,
                                          color: material.Colors.red[600],
                                        ),
                                        const material.SizedBox(width: 8),
                                        material.Expanded(
                                          child: material.Column(
                                            crossAxisAlignment:
                                                material.CrossAxisAlignment.start,
                                            children: [
                                              material.Text(
                                                'Rejection Reason',
                                                style: material.TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: material.FontWeight.w600,
                                                  color: material.Colors.grey[700],
                                                ),
                                              ),
                                              const material.SizedBox(height: 4),
                                              material.Text(
                                                _statusData!['rejected_reason'],
                                                style: material.TextStyle(
                                                  fontSize: 13,
                                                  color: material.Colors.grey[800],
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
                            ),
                          ],
                        ],
                      ),
                    ),

                    const material.Spacer(),

                    // Back Button
                    material.Padding(
                      padding: const material.EdgeInsets.only(bottom: 15),
                      child: material.GestureDetector(
                        onTap: () {
                          material.Navigator.pop(context);
                        },
                        child: material.Container(
                          padding: const material.EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
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
                            mainAxisAlignment: material.MainAxisAlignment.center,
                            children: [
                              const material.Icon(
                                material.Icons.arrow_back_rounded,
                                color: material.Colors.white,
                                size: 20,
                              ),
                              const material.SizedBox(width: 8),
                              const material.Text(
                                'Go Back',
                                style: material.TextStyle(
                                  color: material.Colors.white,
                                  fontSize: 14,
                                  fontWeight: material.FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'N/A';
      String dateStr = dateValue.toString();
      // Handle ISO 8601 format
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

