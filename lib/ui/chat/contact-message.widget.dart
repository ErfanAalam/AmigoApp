import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact.model.dart';
import '../../models/message.model.dart';
import '../../config/app-colors.config.dart';
import '../../providers/theme-color.provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget to display shared contacts in a message
class ContactMessageWidget extends ConsumerWidget {
  final List<ContactModel> contacts;
  final bool isMyMessage;

  const ContactMessageWidget({
    super.key,
    required this.contacts,
    required this.isMyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);

    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        // color: isMyMessage
        //     ? themeColor.primaryLight.withAlpha(50)
        //     : themeColor.primary.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header with contact icon
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //   decoration: BoxDecoration(
          //     // color: isMyMessage
          //     //     ? themeColor.primaryLight.withAlpha(50)
          //     //     : themeColor.primary.withAlpha(50),
          //     borderRadius: const BorderRadius.only(
          //       topLeft: Radius.circular(12),
          //       topRight: Radius.circular(12),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(
          //         Icons.contacts,
          //         size: 18,
          //         color: isMyMessage ? Colors.white : themeColor.primary,
          //       ),
          //       const SizedBox(width: 8),
          //       Text(
          //         contacts.length == 1
          //             ? 'Contact'
          //             : '${contacts.length} Contacts',
          //         style: TextStyle(
          //           fontSize: 13,
          //           fontWeight: FontWeight.w600,
          //           color: isMyMessage ? Colors.white : themeColor.primary,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          // Contact cards
          Container(
            decoration: BoxDecoration(
              // color: isMyMessage
              //     ? themeColor.primaryLight.withAlpha(50)
              //     : themeColor.primary.withAlpha(50),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              spacing: 5,
              children: contacts.asMap().entries.map((entry) {
                final index = entry.key;
                final contact = entry.value;
                final isLast = index == contacts.length - 1;

                return _buildContactCard(
                  contact: contact,
                  themeColor: themeColor,
                  isMyMessage: isMyMessage,
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required ContactModel contact,
    required ColorTheme themeColor,
    required bool isMyMessage,
    required bool isLast,
  }) {
    return InkWell(
      onTap: () => _makePhoneCall(contact.phoneNumber),
      child: Container(
        // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMyMessage
              ? Colors.white.withAlpha(30)
              : themeColor.primary.withAlpha(50),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          spacing: 12,
          children: [
            // Contact avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMyMessage
                    ? Colors.white.withAlpha(35)
                    : themeColor.primary.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 22,
                color: isMyMessage ? Colors.white : themeColor.primaryDark,
              ),
            ),
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isMyMessage ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14,
                        color: isMyMessage
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contact.phoneNumber,
                          style: TextStyle(
                            fontSize: 13,
                            color: isMyMessage
                                ? Colors.white.withOpacity(0.9)
                                : Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Call icon
            Icon(
              Icons.phone_outlined,
              size: 18,
              color: isMyMessage ? Colors.white : themeColor.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Parse contacts from message attachments
List<ContactModel> parseContactsFromMessage(MessageModel message) {
  final attachments = message.attachments;
  if (attachments is Map<String, dynamic>) {
    final contactsData = attachments['contacts'];
    if (contactsData != null && contactsData is List) {
      return contactsData
          .map((contactJson) {
            try {
              return ContactModel(
                displayName:
                    contactJson['name'] ?? contactJson['displayName'] ?? '',
                firstName: contactJson['firstName'] ?? '',
                lastName: contactJson['lastName'] ?? '',
                phoneNumber:
                    contactJson['phone'] ?? contactJson['phoneNumber'] ?? '',
              );
            } catch (e) {
              return null;
            }
          })
          .where((contact) => contact != null && contact.phoneNumber.isNotEmpty)
          .cast<ContactModel>()
          .toList();
    }
  }

  return [];
}
