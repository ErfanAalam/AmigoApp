import 'package:flutter/material.dart';
import '../../models/contact.model.dart';
import '../../services/contact.service.dart';
import '../../providers/theme-color.provider.dart';
import '../../ui/snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contact selection widget for sharing contacts
class ContactSelectionWidget extends ConsumerStatefulWidget {
  final Function(List<ContactModel>) onContactsSelected;

  const ContactSelectionWidget({
    super.key,
    required this.onContactsSelected,
  });

  @override
  ConsumerState<ContactSelectionWidget> createState() =>
      _ContactSelectionWidgetState();
}

class _ContactSelectionWidgetState
    extends ConsumerState<ContactSelectionWidget> {
  final ContactService _contactService = ContactService();
  List<ContactModel> _contacts = [];
  Set<String> _selectedContactIds = {}; // Track selected contacts by phone number
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request permission first
      final hasPermission = await _contactService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          Snack.error('Contact permission is required to share contacts');
          Navigator.pop(context);
        }
        return;
      }

      // Fetch contacts
      final contacts = await _contactService.fetchContacts();
      
      // Filter out contacts without phone numbers
      final validContacts = contacts
          .where((contact) => contact.phoneNumber.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _contacts = validContacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Snack.error('Failed to load contacts: $e');
      }
    }
  }

  void _toggleContactSelection(ContactModel contact) {
    setState(() {
      if (_selectedContactIds.contains(contact.phoneNumber)) {
        _selectedContactIds.remove(contact.phoneNumber);
      } else {
        _selectedContactIds.add(contact.phoneNumber);
      }
    });
  }

  List<ContactModel> _getFilteredContacts() {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final phone = contact.phoneNumber.toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();
  }

  List<ContactModel> _getSelectedContacts() {
    return _contacts
        .where((contact) => _selectedContactIds.contains(contact.phoneNumber))
        .toList();
  }

  void _handleSend() {
    final selected = _getSelectedContacts();
    if (selected.isEmpty) {
      Snack.warning('Please select at least one contact');
      return;
    }

    widget.onContactsSelected(selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final filteredContacts = _getFilteredContacts();
    final selectedCount = _selectedContactIds.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: themeColor.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Contact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (selectedCount > 0)
              Text(
                '$selectedCount selected',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          if (selectedCount > 0)
            TextButton(
              onPressed: _handleSend,
              child: const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Contacts list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeColor.primary,
                      ),
                    ),
                  )
                : filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No contacts found'
                                  : 'No contacts match your search',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          final isSelected =
                              _selectedContactIds.contains(contact.phoneNumber);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: themeColor.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: themeColor.primary,
                              ),
                            ),
                            title: Text(
                              contact.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(contact.phoneNumber),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleContactSelection(contact),
                              activeColor: themeColor.primary,
                            ),
                            onTap: () => _toggleContactSelection(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

