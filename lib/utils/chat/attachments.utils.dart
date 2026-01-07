import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/contact.model.dart';

/// Callbacks for attachment handling
typedef OnImageSelected = void Function(File imageFile, String source);
typedef OnVideoSelected = void Function(File videoFile, String source);
typedef OnDocumentSelected =
    void Function(File documentFile, String fileName, String extension);
typedef OnError = void Function(String message);
typedef OnPermissionDenied = void Function(String permissionType);

/// Handles camera attachment selection
Future<void> handleCameraAttachment({
  required ImagePicker imagePicker,
  required BuildContext context,
  required OnImageSelected onImageSelected,
  required OnError onError,
  required OnPermissionDenied onPermissionDenied,
}) async {
  // Check and request camera permission
  PermissionStatus cameraStatus = await Permission.camera.status;

  // If permission is not granted, request it
  if (!cameraStatus.isGranted) {
    cameraStatus = await Permission.camera.request();
  }

  if (!cameraStatus.isGranted) {
    if (cameraStatus.isPermanentlyDenied) {
      onPermissionDenied('Camera');
    } else {
      onError('Camera permission is required to take photos.');
    }
    return;
  }

  try {
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, // Compress to reduce file size
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null) {
      // Print image details
      final File imageFile = File(image.path);
      if (await imageFile.exists()) {
        onImageSelected(imageFile, 'camera');
      }
    } else {
      debugPrint('📸 Camera capture cancelled by user');
    }
  } catch (e) {
    debugPrint('❌ Error capturing image from camera: $e');
    if (e.toString().contains('permission')) {
      onError(
        'Camera permission is required to take photos. Please grant permission in your device settings.',
      );
    } else {
      onError('Failed to capture image from camera');
    }
  }
}

/// Handles gallery attachment selection (images and videos)
Future<void> handleGalleryAttachment({
  required BuildContext context,
  required OnImageSelected onImageSelected,
  required OnVideoSelected onVideoSelected,
  required OnError onError,
}) async {
  try {
    // Use file picker to allow both images and videos with multiple selection
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true, // Allow multiple image selection
      allowCompression: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Process all selected files
      for (final PlatformFile file in result.files) {
        if (file.path == null) continue;

        final File mediaFile = File(file.path!);
        final String extension = file.extension?.toLowerCase() ?? '';

        // Check if it's a video file
        final bool isVideo = [
          'mp4',
          'mov',
          'avi',
          'mkv',
          '3gp',
          'webm',
          'flv',
          'wmv',
        ].contains(extension);

        if (isVideo) {
          onVideoSelected(mediaFile, 'gallery');
        } else {
          onImageSelected(mediaFile, 'gallery');
        }
      }
    } else {
      debugPrint('🖼️ Gallery selection cancelled');
    }
  } catch (e) {
    debugPrint('❌ Error selecting from gallery: $e');
    if (e.toString().contains('permission')) {
      onError(
        'Gallery permission is required to select media. Please grant permission in your device settings.',
      );
    } else {
      onError('Failed to select from gallery');
    }
  }
}

/// Handles document attachment selection
Future<void> handleDocumentAttachment({
  required BuildContext context,
  required OnDocumentSelected onDocumentSelected,
  required OnError onError,
}) async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      allowCompression: true,
      withData: false, // Don't load file data into memory for large files
      withReadStream: true, // Use stream for large files
    );

    if (result != null && result.files.single.path != null) {
      final PlatformFile file = result.files.first;
      final File documentFile = File(file.path!);

      onDocumentSelected(documentFile, file.name, file.extension ?? '');
    } else {
      debugPrint('📄 Document selection cancelled');
    }
  } catch (e) {
    debugPrint('❌ Error selecting document: $e');
    if (e.toString().contains('permission')) {
      onError(
        'Storage permission is required to access documents. Please grant permission in your device settings.',
      );
    } else {
      onError('Failed to select document');
    }
  }
}

/// Format selected contacts into a message string
/// Format: name: contact number,\nname2: contact number
String formatContactsForMessage(List<ContactModel> contacts) {
  if (contacts.isEmpty) return '';
  
  return contacts
      .map((contact) => '${contact.displayName}: ${contact.phoneNumber}')
      .join(',\n');
}
