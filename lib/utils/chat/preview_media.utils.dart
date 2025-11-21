import 'dart:io' as io;
import 'package:amigo/models/message.model.dart';
import 'package:amigo/utils/chat/chat_helpers.utils.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/repositories/message.repo.dart';
import '../../services/media_cache_service.dart';
import '../../widgets/media_preview_widgets.dart';

/// Opens an image preview screen with caching support
///
/// [context] - BuildContext for navigation
/// [imageUrl] - URL of the image to preview
/// [caption] - Optional caption for the image
/// [messages] - List of messages to find the message with this image
/// [mediaCacheService] - Service for caching media files
/// [messagesRepo] - Repository for message operations
/// [mounted] - Whether the widget is still mounted
/// [checkExistingCache] - Whether to check existing cache (default: true)
/// [debugPrefix] - Optional debug prefix for logging
Future<void> openImagePreview({
  required BuildContext context,
  required String imageUrl,
  String? caption,
  required List<MessageModel> messages,
  required MediaCacheService mediaCacheService,
  required MessageRepository messagesRepo,
  required bool mounted,
  bool checkExistingCache = true,
  String? debugPrefix,
}) async {
  try {
    // Find the message to get localMediaPath
    final message = messages.firstWhere(
      (msg) =>
          msg.attachments != null &&
          (msg.attachments as Map<String, dynamic>)['url'] == imageUrl,
      orElse: () => messages.first,
    );

    // Get local path or download if needed
    String? localPath = message.localMediaPath;

    // Check if local file exists
    if (localPath != null && io.File(localPath).existsSync()) {
      debugPrint('✅ Local image file exists: $localPath');
    } else {
      // Try to get from cache first
      localPath = await mediaCacheService.getCachedFilePath(imageUrl);

      if (localPath == null) {
        // Start caching in background (don't wait for it)
        ChatHelpers.cacheMediaForMessage(
          url: imageUrl,
          messageId: message.canonicalId!,
          mediaCacheService: mediaCacheService,
          checkExistingCache: checkExistingCache,
          debugPrefix: debugPrefix,
        );
      } else {
        // Update database with local path if not already set
        if (message.localMediaPath == null) {
          await messagesRepo.updateLocalMediaPath(
            message.canonicalId!,
            localPath,
          );
        }
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImagePreviewScreen(
          imageUrls: [imageUrl],
          initialIndex: 0,
          captions: caption != null && caption.isNotEmpty ? [caption] : null,
          localPaths: localPath != null ? [localPath] : null,
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ Error opening image preview: $e');

    // Show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Opens a video preview screen with caching support
///
/// [context] - BuildContext for navigation
/// [videoUrl] - URL of the video to preview
/// [caption] - Optional caption for the video
/// [fileName] - Optional file name
/// [messages] - List of messages to find the message with this video
/// [mediaCacheService] - Service for caching media files
/// [messagesRepo] - Repository for message operations
/// [mounted] - Whether the widget is still mounted
/// [onMessageUpdated] - Optional callback to update message in state (for setState)
Future<void> openVideoPreview({
  required BuildContext context,
  required String videoUrl,
  String? caption,
  String? fileName,
  required List<MessageModel> messages,
  required MediaCacheService mediaCacheService,
  required MessageRepository messagesRepo,
  required bool mounted,
  void Function(MessageModel updatedMessage)? onMessageUpdated,
}) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

  try {
    // Find the message to get localMediaPath and cache if needed
    final message = messages.firstWhere(
      (msg) =>
          msg.attachments != null &&
          (msg.attachments as Map<String, dynamic>)['url'] == videoUrl,
      orElse: () => messages.first,
    );

    // Get local path or download if needed
    String? localPath = message.localMediaPath;

    // Check if local file exists
    if (localPath != null && io.File(localPath).existsSync()) {
    } else {
      // Try to get from cache first
      localPath = await mediaCacheService.getCachedFilePath(videoUrl);

      if (localPath == null) {
        // Download and wait for completion
        localPath = await mediaCacheService.downloadAndCacheMedia(videoUrl);

        if (localPath != null) {
          // Update database with local path
          await messagesRepo.updateLocalMediaPath(
            message.canonicalId!,
            localPath,
          );

          // Update the message in memory if callback provided
          if (onMessageUpdated != null && mounted) {
            final updatedMessage = message.copyWith(localMediaPath: localPath);
            onMessageUpdated(updatedMessage);
          }
        } else {
          debugPrint('⚠️ Video download failed, will use network URL');
        }
      } else {
        debugPrint('✅ Video found in cache: $localPath');
      }
    }

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(
          videoUrl: videoUrl,
          caption: caption,
          fileName: fileName,
          localPath: localPath,
        ),
      ),
    );
  } catch (e) {
    // Close loading dialog
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Opens a document preview screen
///
/// [context] - BuildContext for navigation
/// [documentUrl] - URL of the document to preview
/// [fileName] - Optional file name
/// [caption] - Optional caption
/// [fileSize] - Optional file size in bytes
void openDocumentPreview({
  required BuildContext context,
  required String documentUrl,
  String? fileName,
  String? caption,
  int? fileSize,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => DocumentPreviewScreen(
        documentUrl: documentUrl,
        fileName: fileName,
        caption: caption,
        fileSize: fileSize,
      ),
    ),
  );
}

/// Generate video thumbnail from video URL
///
/// [videoUrl] - URL or local path of the video file
/// Returns the path to the generated thumbnail file, or null if generation fails
Future<String?> generateVideoThumbnail(String videoUrl) async {
  try {
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.PNG,
      maxWidth: 220,
      quality: 75,
    );
    return thumbnailPath;
  } catch (e) {
    debugPrint('❌ Error generating video thumbnail: $e');
    return null;
  }
}

/// Generate video thumbnail with caching support
///
/// [videoUrl] - URL or local path of the video file
/// [thumbnailCache] - Map to cache thumbnail paths by video URL
/// [thumbnailFutures] - Map to track ongoing thumbnail generation futures
/// Returns the path to the generated thumbnail file, or null if generation fails
Future<String?> generateVideoThumbnailWithCache(
  String videoUrl,
  Map<String, String?> thumbnailCache,
  Map<String, Future<String?>> thumbnailFutures,
) async {
  // Check if thumbnail is already cached
  if (thumbnailCache.containsKey(videoUrl)) {
    return thumbnailCache[videoUrl];
  }

  // Check if thumbnail is currently being generated
  if (thumbnailFutures.containsKey(videoUrl)) {
    return await thumbnailFutures[videoUrl];
  }

  // Generate new thumbnail
  final future = generateVideoThumbnail(videoUrl);
  thumbnailFutures[videoUrl] = future;

  try {
    final thumbnailPath = await future;
    thumbnailCache[videoUrl] = thumbnailPath;
    thumbnailFutures.remove(videoUrl);
    return thumbnailPath;
  } catch (e) {
    thumbnailFutures.remove(videoUrl);
    thumbnailCache[videoUrl] = null;
    return null;
  }
}
