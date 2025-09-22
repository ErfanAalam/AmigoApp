import 'dart:convert';
import 'package:http/http.dart' as http;

class IpService {
  static final IpService _instance = IpService._internal();
  factory IpService() => _instance;
  IpService._internal();

  /// Get user's current IP address using multiple fallback services
  Future<Map<String, dynamic>> getCurrentIp() async {
    // List of IP detection services as fallbacks
    final List<String> ipServices = [
      'https://api.ipify.org?format=json',
      'https://httpbin.org/ip',
      'https://api.my-ip.io/ip.json',
      'https://ipapi.co/json/',
    ];

    for (String serviceUrl in ipServices) {
      try {
        print('🌐 Attempting to get IP from: $serviceUrl');

        final response = await http
            .get(Uri.parse(serviceUrl), headers: {'Accept': 'application/json'})
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          String? ip;

          // Different services return IP in different formats
          if (data['ip'] != null) {
            ip = data['ip'];
          } else if (data['origin'] != null) {
            ip = data['origin'];
          } else if (data is String) {
            ip = data;
          }

          if (ip != null && ip.isNotEmpty) {
            print('🌐 IP Address retrieved successfully: $ip');
            print('   Service used: $serviceUrl');

            return {
              'success': true,
              'ip': ip,
              'service': serviceUrl,
              'additional_info': data,
            };
          }
        }
      } catch (e) {
        print('🌐 Failed to get IP from $serviceUrl: $e');
        continue; // Try next service
      }
    }

    print('🌐 Failed to retrieve IP address from all services');
    return {
      'success': false,
      'error': 'Failed to retrieve IP address from all services',
      'ip': null,
    };
  }

  /// Get detailed IP information including location data
  Future<Map<String, dynamic>> getDetailedIpInfo() async {
    try {
      print('🌐 Getting detailed IP information...');

      final response = await http
          .get(
            Uri.parse('https://ipapi.co/json/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'ip': data['ip'],
          'city': data['city'],
          'region': data['region'],
          'country': data['country_name'],
          'country_code': data['country_code'],
          'postal': data['postal'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'timezone': data['timezone'],
          'isp': data['org'],
          'full_data': data,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('🌐 Failed to get detailed IP info: $e');

      // Fallback to basic IP only
      final basicIp = await getCurrentIp();
      if (basicIp['success']) {
        return {
          'success': true,
          'ip': basicIp['ip'],
          'error': 'Detailed info unavailable: $e',
        };
      }

      return {'success': false, 'error': e.toString(), 'ip': null};
    }
  }
}
