import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../utils/chat/chat_helpers.dart';
import '../../utils/chat/cachedImage_widget.dart';
import '../../utils/chat/preview_media.utils.dart';
import '../../utils/chat/audio_playback.utils.dart';
import '../../widgets/chat/messagewidget.dart';
import '../../widgets/chat/voice_recording_widget.dart';

/// Configuration class for media message widgets
class MediaMessageConfig {
  final MessageModel message;
  final bool isMyMessage;
  final bool isStarred;
  final bool Function() mounted;
  final void Function() setState;
  final void Function(String) showErrorDialog;
  final Widget Function(MessageModel) buildMessageStatusTicks;

  // Image-specific
  final void Function(String, String?) onImagePreview;
  final void Function(File, String, {MessageModel? failedMessage}) onRetryImage;
  final void Function(String, int) onCacheImage;

  // Video-specific
  final void Function(String, String?, String?) onVideoPreview;
  final void Function(File, String, {MessageModel? failedMessage}) onRetryVideo;
  final Map<String, String?> videoThumbnailCache;
  final Map<String, Future<String?>> videoThumbnailFutures;

  // Document-specific
  final void Function(String, String?, String?, int?) onDocumentPreview;
  final void Function(File, String, String, {MessageModel? failedMessage})
  onRetryDocument;

  // Audio-specific
  final AudioPlaybackManager audioPlaybackManager;
  final void Function({MessageModel? failedMessage}) onRetryAudio;

  MediaMessageConfig({
    required this.message,
    required this.isMyMessage,
    required this.isStarred,
    required this.mounted,
    required this.setState,
    required this.showErrorDialog,
    required this.buildMessageStatusTicks,
    required this.onImagePreview,
    required this.onRetryImage,
    required this.onCacheImage,
    required this.onVideoPreview,
    required this.onRetryVideo,
    required this.videoThumbnailCache,
    required this.videoThumbnailFutures,
    required this.onDocumentPreview,
    required this.onRetryDocument,
    required this.audioPlaybackManager,
    required this.onRetryAudio,
  });
}

/// Reusable Image Message Widget
Widget buildImageMessage(MediaMessageConfig config) {
  if (config.message.attachments == null) {
    return Text(
      'Image not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  final imageData = config.message.attachments as Map<String, dynamic>;
  final imageUrl = imageData['url'] as String?;
  final localPath = imageData['local_path'] as String?;

  // Check upload status from metadata
  final metadata = config.message.metadata ?? {};
  final isUploading = metadata['is_uploading'] == true;
  final isFailed = metadata['upload_failed'] == true;

  // Use local path if available (for uploading/failed messages)
  final displayImagePath = localPath ?? imageUrl;

  if (displayImagePath == null || displayImagePath.isEmpty) {
    return Text(
      'Image not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  return ClipRRect(
    child: Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF008080), width: 4),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
          bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(config.isMyMessage ? 10 : 0),
                  bottomRight: Radius.circular(config.isMyMessage ? 0 : 10),
                ),
                child: GestureDetector(
                  onTap: imageUrl != null
                      ? () =>
                            config.onImagePreview(imageUrl, config.message.body)
                      : null,
                  child: Hero(
                    tag: imageUrl ?? displayImagePath,
                    child: localPath != null && File(localPath).existsSync()
                        ? Image.file(
                            File(localPath),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        : imageUrl != null
                        ? buildCachedImage(
                            imageUrl: imageUrl,
                            localPath: config.message.localMediaPath,
                            messageId: config.message.id,
                            onCacheMedia: config.onCacheImage,
                          )
                        : Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                ),
              ),
              if (config.message.body.isNotEmpty)
                Container(
                  width: 200,
                  padding: const EdgeInsets.only(
                    bottom: 20.0,
                    left: 8.0,
                    right: 8.0,
                    top: 4.0,
                  ),
                  child: Text(
                    config.message.body,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
          // Timestamp overlay positioned at bottom right
          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (isFailed && config.isMyMessage)
                    GestureDetector(
                      onTap: () {
                        final localFilePath =
                            imageData['local_path'] as String?;
                        if (localFilePath != null &&
                            File(localFilePath).existsSync()) {
                          config.onRetryImage(
                            File(localFilePath),
                            'image',
                            failedMessage: config.message,
                          );
                        } else {
                          config.showErrorDialog(
                            'Original file not found. Please select the image again.',
                          );
                        }
                      },
                      child: Icon(Icons.refresh, size: 16, color: Colors.white),
                    )
                  else ...[
                    Text(
                      ChatHelpers.formatMessageTime(config.message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (config.isMyMessage) ...[
                      const SizedBox(width: 4),
                      config.buildMessageStatusTicks(config.message),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (config.isStarred)
            Positioned(
              bottom: 4,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.star, size: 14, color: Colors.yellow)],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Reusable Video Message Widget
Widget buildVideoMessage(MediaMessageConfig config) {
  if (config.message.attachments == null) {
    return Text(
      'Video not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  final videoData = config.message.attachments as Map<String, dynamic>;
  final videoUrl = videoData['url'] as String?;
  final localPath = videoData['local_path'] as String?;

  // Check upload status from metadata
  final metadata = config.message.metadata ?? {};
  final isUploading = metadata['is_uploading'] == true;
  final isFailed = metadata['upload_failed'] == true;

  // Use local path if available (for uploading/failed messages)
  final displayVideoPath = localPath ?? videoUrl;

  if (displayVideoPath == null || displayVideoPath.isEmpty) {
    return Text(
      'Video not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  return ClipRRect(
    child: Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF008080), width: 4),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
          bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: videoUrl != null
                    ? () => config.onVideoPreview(
                        videoUrl,
                        config.message.body,
                        videoData['file_name'] as String?,
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(config.isMyMessage ? 10 : 0),
                    bottomRight: Radius.circular(config.isMyMessage ? 0 : 10),
                  ),
                  child: Container(
                    width: 220,
                    height: 220,
                    color: Colors.black87,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Show local video thumbnail if uploading/failed, otherwise use cached version
                        if (localPath != null &&
                            File(localPath).existsSync() &&
                            (isUploading || isFailed))
                          FutureBuilder<String?>(
                            future: generateVideoThumbnailWithCache(
                              localPath,
                              config.videoThumbnailCache,
                              config.videoThumbnailFutures,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.hasData &&
                                  snapshot.data != null) {
                                return Image.file(
                                  File(snapshot.data!),
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 220,
                                height: 220,
                                color: Colors.grey[800],
                                child: Icon(
                                  Icons.videocam,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        else if (videoUrl != null)
                          VideoThumbnailWidget(
                            videoUrl: videoUrl,
                            thumbnailCache: config.videoThumbnailCache,
                            thumbnailFutures: config.videoThumbnailFutures,
                            onThumbnailGenerated: () {
                              if (config.mounted()) {
                                config.setState();
                              }
                            },
                          )
                        else
                          Container(
                            width: 220,
                            height: 220,
                            color: Colors.grey[800],
                            child: Icon(
                              Icons.videocam,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                          ),
                        // Loading overlay (only when uploading)
                        if (isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(10),
                                  topRight: const Radius.circular(10),
                                  bottomLeft: Radius.circular(
                                    config.isMyMessage ? 10 : 0,
                                  ),
                                  bottomRight: Radius.circular(
                                    config.isMyMessage ? 0 : 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Play button overlay (only if not uploading)
                        if (!isUploading)
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.play_circle_filled,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (config.message.body.isNotEmpty)
                Container(
                  width: 200,
                  padding: const EdgeInsets.only(
                    bottom: 20.0,
                    left: 8.0,
                    right: 8.0,
                    top: 4.0,
                  ),
                  child: Text(
                    config.message.body,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
          // Timestamp overlay positioned at bottom right
          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (isFailed && config.isMyMessage)
                    GestureDetector(
                      onTap: () {
                        final localFilePath =
                            videoData['local_path'] as String?;
                        if (localFilePath != null &&
                            File(localFilePath).existsSync()) {
                          config.onRetryVideo(
                            File(localFilePath),
                            'video',
                            failedMessage: config.message,
                          );
                        } else {
                          config.showErrorDialog(
                            'Original file not found. Please select the video again.',
                          );
                        }
                      },
                      child: Icon(Icons.refresh, size: 16, color: Colors.white),
                    )
                  else ...[
                    Text(
                      ChatHelpers.formatMessageTime(config.message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (config.isMyMessage) ...[
                      const SizedBox(width: 4),
                      config.buildMessageStatusTicks(config.message),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (config.isStarred)
            Positioned(
              bottom: 4,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(60),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.star, size: 14, color: Colors.yellow)],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Reusable Document Message Widget
Widget buildDocumentMessage(MediaMessageConfig config) {
  if (config.message.attachments == null) {
    return Text(
      'Document not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.teal : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  final documentData = config.message.attachments as Map<String, dynamic>;
  final documentUrl = documentData['url'] as String?;
  final fileName = documentData['file_name'] as String?;
  final fileSize = documentData['file_size'] as int?;
  final mimeType = documentData['mime_type'] as String?;
  final localPath = documentData['local_path'] as String?;

  // Check upload status from metadata
  final metadata = config.message.metadata ?? {};
  final isUploading = metadata['is_uploading'] == true;
  final isFailed = metadata['upload_failed'] == true;

  // Use local path if available (for uploading/failed messages)
  final displayDocumentPath = localPath ?? documentUrl;

  if (displayDocumentPath == null || displayDocumentPath.isEmpty) {
    return Text(
      'Document not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  IconData docIcon = Icons.description;
  if (mimeType != null) {
    if (mimeType.contains('pdf')) {
      docIcon = Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('doc')) {
      docIcon = Icons.description;
    } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      docIcon = Icons.table_chart;
    } else if (mimeType.contains('powerpoint') ||
        mimeType.contains('presentation')) {
      docIcon = Icons.slideshow;
    } else if (mimeType.contains('zip') || mimeType.contains('rar')) {
      docIcon = Icons.archive;
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: documentUrl != null
            ? () => config.onDocumentPreview(
                documentUrl,
                fileName,
                config.message.body,
                fileSize,
              )
            : null,
        child: Stack(
          children: [
            Container(
              width: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: config.isMyMessage ? Colors.teal : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
                  bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
                ),
                border: Border.all(
                  color: config.isMyMessage ? Colors.teal : Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: config.isMyMessage
                          ? Colors.teal.withAlpha(25)
                          : Colors.teal.withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      docIcon,
                      size: 24,
                      color: config.isMyMessage
                          ? Colors.white
                          : Colors.teal[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (fileName != null && fileName.isNotEmpty)
                              ? fileName
                              : 'Document',
                          style: TextStyle(
                            color: config.isMyMessage
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (fileSize != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            ChatHelpers.formatFileSize(fileSize),
                            style: TextStyle(
                              color: config.isMyMessage
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ] else if (isUploading) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    config.isMyMessage
                                        ? Colors.white70
                                        : Colors.teal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Uploading...',
                                style: TextStyle(
                                  color: config.isMyMessage
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ] else if (isFailed) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Upload failed',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Show loading, retry, or view icon
                  if (isUploading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          config.isMyMessage ? Colors.white70 : Colors.teal,
                        ),
                      ),
                    )
                  else if (isFailed && config.isMyMessage)
                    GestureDetector(
                      onTap: () {
                        final localFilePath =
                            documentData['local_path'] as String?;
                        final fileName = documentData['file_name'] as String?;
                        final extension =
                            documentData['file_extension'] as String?;

                        if (localFilePath != null &&
                            File(localFilePath).existsSync() &&
                            fileName != null &&
                            extension != null) {
                          config.onRetryDocument(
                            File(localFilePath),
                            fileName,
                            extension,
                            failedMessage: config.message,
                          );
                        } else {
                          config.showErrorDialog(
                            'Original file not found. Please select the document again.',
                          );
                        }
                      },
                      child: Icon(
                        Icons.refresh,
                        size: 22,
                        color: config.isMyMessage
                            ? Colors.white
                            : Colors.teal[600],
                      ),
                    )
                  else
                    Icon(
                      Icons.visibility,
                      size: 22,
                      color: config.isMyMessage
                          ? Colors.white
                          : Colors.teal[600],
                    ),
                ],
              ),
            ),
            // Timestamp overlay positioned at bottom right
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: config.isMyMessage
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUploading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else if (isFailed && config.isMyMessage)
                      Text(
                        ChatHelpers.formatMessageTime(config.message.createdAt),
                        style: TextStyle(
                          color: config.isMyMessage
                              ? Colors.white
                              : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else ...[
                      Text(
                        ChatHelpers.formatMessageTime(config.message.createdAt),
                        style: TextStyle(
                          color: config.isMyMessage
                              ? Colors.white
                              : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (config.isMyMessage) ...[
                        const SizedBox(width: 4),
                        config.buildMessageStatusTicks(config.message),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (config.isStarred)
              Positioned(
                bottom: 4,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.yellow),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      if (config.message.body.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          config.message.body,
          style: TextStyle(
            color: config.isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    ],
  );
}

/// Reusable Audio Message Widget
Widget buildAudioMessage(MediaMessageConfig config) {
  if (config.message.attachments == null) {
    return Text(
      'Audio not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  final audioData = config.message.attachments as Map<String, dynamic>;
  final audioUrl = audioData['url'] as String?;
  final fileSize = audioData['file_size'] as int?;
  final localPath = audioData['local_path'] as String?;

  // Check upload status from metadata
  final metadata = config.message.metadata ?? {};
  final isUploading = metadata['is_uploading'] == true;
  final isFailed = metadata['upload_failed'] == true;

  // Use local path if available (for uploading/failed messages)
  final displayAudioPath = localPath ?? audioUrl;

  if (displayAudioPath == null || displayAudioPath.isEmpty) {
    return Text(
      'Audio not available',
      style: TextStyle(
        color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // For uploading messages, use local path for audio key; otherwise use URL
  final audioKey = isUploading || isFailed
      ? '${config.message.id}_${localPath ?? audioUrl}'
      : '${config.message.id}_$audioUrl';
  final isPlaying = audioUrl != null
      ? config.audioPlaybackManager.isPlaying(audioKey)
      : false;
  final duration = isUploading || isFailed
      ? (audioData['duration'] != null
            ? Duration(seconds: audioData['duration'] as int)
            : Duration.zero)
      : (config.audioPlaybackManager.getDuration(audioKey) ?? Duration.zero);
  final position =
      config.audioPlaybackManager.getPosition(audioKey) ?? Duration.zero;

  // Get animation for this audio (create if needed)
  var animation = config.audioPlaybackManager.getAnimation(audioKey);
  if (animation == null) {
    animation = const AlwaysStoppedAnimation<double>(1.0);
  }

  // If we don't have duration yet, schedule it to be estimated after build
  if (duration == Duration.zero && !isPlaying) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      config.audioPlaybackManager.estimateDuration(audioKey, fileSize);
    });
  }

  // Calculate progress for the progress bar
  double progressValue = 0.0;
  if (duration.inMilliseconds > 0) {
    progressValue = position.inMilliseconds / duration.inMilliseconds;
    progressValue = progressValue.clamp(0.0, 1.0);
  }

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 250,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: config.isMyMessage ? Colors.teal : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
                bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: audioUrl != null && !isUploading && !isFailed
                      ? () {
                          config.audioPlaybackManager.togglePlayback(
                            audioKey,
                            audioUrl,
                            onError: (error) {
                              config.showErrorDialog(error);
                            },
                          );
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? (config.isMyMessage
                                ? Colors.white.withAlpha(40)
                                : Colors.blue.withAlpha(30))
                          : (config.isMyMessage
                                ? Colors.white.withAlpha(20)
                                : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: isPlaying
                          ? [
                              BoxShadow(
                                color:
                                    (config.isMyMessage
                                            ? Colors.white
                                            : Colors.blue)
                                        .withAlpha(30),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Transform.scale(
                      scale: isPlaying ? (animation?.value ?? 1.0) : 1.0,
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 20,
                        color: isPlaying
                            ? (config.isMyMessage
                                  ? Colors.white
                                  : Colors.blue[700])
                            : (config.isMyMessage
                                  ? Colors.white
                                  : Colors.grey[700]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPlaying && animation != null)
                            buildAnimatedWaveform(config.isMyMessage, animation)
                          else
                            Icon(
                              Icons.audiotrack,
                              size: 16,
                              color: config.isMyMessage
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: config.isMyMessage
                                    ? Colors.white30
                                    : Colors.grey[300],
                              ),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  config.isMyMessage
                                      ? Colors.white
                                      : Colors.blue,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          if (config.isStarred)
                            Icon(Icons.star, size: 14, color: Colors.yellow),
                          if (isUploading)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  config.isMyMessage
                                      ? Colors.white70
                                      : Colors.teal,
                                ),
                              ),
                            )
                          else if (isFailed && config.isMyMessage)
                            GestureDetector(
                              onTap: () {
                                final localFilePath =
                                    audioData['local_path'] as String?;

                                if (localFilePath != null &&
                                    File(localFilePath).existsSync()) {
                                  config.onRetryAudio(
                                    failedMessage: config.message,
                                  );
                                } else {
                                  config.showErrorDialog(
                                    'Original file not found. Please record again.',
                                  );
                                }
                              },
                              child: Icon(
                                Icons.refresh,
                                size: 14,
                                color: config.isMyMessage
                                    ? Colors.white70
                                    : Colors.teal[600],
                              ),
                            )
                          else ...[
                            Text(
                              AudioPlaybackManager.formatDuration(
                                isPlaying ? position : duration,
                              ),
                              style: TextStyle(
                                color: config.isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (!isUploading && !isFailed) ...[
                            Text(
                              ChatHelpers.formatMessageTime(
                                config.message.createdAt,
                              ),
                              style: TextStyle(
                                color: config.isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (config.isMyMessage) ...[
                              const SizedBox(width: 4),
                              config.buildMessageStatusTicks(config.message),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (config.message.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              config.message.body,
              style: TextStyle(
                color: config.isMyMessage ? Colors.white : Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ],
        ],
      );
    },
  );
}
