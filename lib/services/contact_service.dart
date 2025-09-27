import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  bool _hasPermission = false;

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;

  /// Request contacts permission
  Future<bool> requestPermission() async {
    try {
      final status = await FlutterContacts.requestPermission();
      _hasPermission = status;
      return _hasPermission;
    } catch (e) {
      print('Error requesting contacts permission: $e');
      return false;
    }
  }

  /// Check if contacts permission is granted
  Future<bool> checkPermission() async {
    try {
      // For flutter_contacts, we'll try to get contacts and catch permission errors
      // This is a workaround since there's no direct checkPermission method
      final status = await FlutterContacts.requestPermission();
      _hasPermission = status;
      return _hasPermission;
    } catch (e) {
      print('Error checking contacts permission: $e');
      _hasPermission = false;
      return false;
    }
  }

  /// Fetch all contacts from device
  Future<List<ContactModel>> fetchContacts() async {
    if (_isLoading) return _contacts;

    _isLoading = true;

    try {
      // Request permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        return [];
      }

      // Fetch contacts
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      print('Fetched ${contacts.length} contacts from device');
      // Convert to our model
      _contacts = contacts
          .where((contact) => contact.displayName.isNotEmpty)
          .map((contact) {
            try {
              return ContactModel.fromFlutterContacts(contact);
            } catch (e) {
              print('Error converting contact ${contact.displayName}: $e');
              return null;
            }
          })
          .where((contact) => contact != null)
          .cast<ContactModel>()
          .toList();

      // Sort contacts alphabetically
      _contacts.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      _isLoading = false;

      return _contacts;
    } catch (e) {
      print('Error fetching contacts: $e');
      _isLoading = false;
      return [];
    }
  }

  /// Search contacts by query
  List<ContactModel> searchContacts(String query) {
    if (query.isEmpty) return _contacts;

    final lowercaseQuery = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(lowercaseQuery) ||
          contact.firstName.toLowerCase().contains(lowercaseQuery) ||
          contact.lastName.toLowerCase().contains(lowercaseQuery) ||
          contact.phoneNumber.contains(query);
    }).toList();
  }

  /// Clear contacts cache
  void clearContacts() {
    _contacts.clear();
  }

  /// Clear contact cache (for logout)
  void clearCache() {
    _contacts.clear();
    _isLoading = false;
    _hasPermission = false;
    print('✅ Contact cache cleared');
  }

  /// Refresh contacts
  Future<List<ContactModel>> refreshContacts() async {
    clearContacts();
    return await fetchContacts();
  }
}
