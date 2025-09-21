class ContactModel {
  final String displayName;
  final String firstName;
  final String lastName;
  final String phoneNumber;

  ContactModel({
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
  });

  factory ContactModel.fromFlutterContacts(dynamic contact) {
    try {
      String displayName = contact.displayName?.toString() ?? '';
      String firstName = contact.name?.first?.toString() ?? '';
      String lastName = contact.name?.last?.toString() ?? '';

      // Get the first phone number
      String phoneNumber = '';
      if (contact.phones != null && contact.phones.isNotEmpty) {
        phoneNumber = contact.phones.first.number?.toString() ?? '';
      }

      return ContactModel(
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      // Return a safe fallback contact if conversion fails
      return ContactModel(
        displayName: 'Unknown Contact',
        firstName: '',
        lastName: '',
        phoneNumber: '',
      );
    }
  }

  @override
  String toString() {
    return 'ContactModel(displayName: $displayName, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber)';
  }
}
