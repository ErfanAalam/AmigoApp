import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../models/contact.model.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/contact-selection.widget.dart';
import '../../../utils/chat/attachments.utils.dart' as attachments;
import '../image-editor.screen.dart';

/// Attachment-picker plumbing shared by DM and group messaging screens.
///
/// Owns `pendingContactMetadata` (set when the user picks contacts and read
/// by the message-send pipeline). Methods cover the bottom-sheet, the four
/// pickers, and a generic error dialog reused by the forward flow.
mixin ChatAttachmentMixin<T extends StatefulWidget> on State<T> {
  Map<String, dynamic>? pendingContactMetadata;

  ImagePicker get imagePicker;
  TextEditingController get messageController;
  Future<void> sendMediaMessageToServer(File file, MessageType type);
  void sendMessage(MessageType type);

  Future<void> handleCameraAttachment() async {
    await attachments.handleCameraAttachment(
      imagePicker: imagePicker,
      context: context,
      onImageSelected: (imageFile, source) async {
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );
        if (editedFile != null) {
          sendMediaMessageToServer(editedFile, MessageType.image);
        }
      },
      onError: showErrorDialog,
      onPermissionDenied: (permissionType) {
        openAppSettings();
      },
    );
  }

  Future<void> handleGalleryAttachment() async {
    await attachments.handleGalleryAttachment(
      context: context,
      onImageSelected: (imageFile, source) async {
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );
        if (editedFile != null) {
          sendMediaMessageToServer(editedFile, MessageType.image);
        }
      },
      onVideoSelected: (videoFile, source) {
        sendMediaMessageToServer(videoFile, MessageType.video);
      },
      onError: showErrorDialog,
    );
  }

  Future<void> handleDocumentAttachment() async {
    await attachments.handleDocumentAttachment(
      context: context,
      onDocumentSelected: (documentFile, fileName, extension) {
        sendMediaMessageToServer(documentFile, MessageType.document);
      },
      onError: showErrorDialog,
    );
  }

  Future<void> handleContactAttachment() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactSelectionWidget(
          onContactsSelected: (List<ContactModel> contacts) {
            if (contacts.isEmpty) return;

            final contactsMetadata = contacts
                .map(
                  (contact) => {
                    'name': contact.displayName,
                    'displayName': contact.displayName,
                    'firstName': contact.firstName,
                    'lastName': contact.lastName,
                    'phone': contact.phoneNumber,
                    'phoneNumber': contact.phoneNumber,
                  },
                )
                .toList();

            final contactText = contacts
                .map(
                  (contact) => '${contact.displayName}: ${contact.phoneNumber}',
                )
                .join(',\n');

            messageController.text = contactText;

            pendingContactMetadata = {
              'contacts': contactsMetadata,
            };

            sendMessage(MessageType.contact);
          },
        ),
      ),
    );
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
