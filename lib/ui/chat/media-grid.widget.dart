import 'dart:io';
import 'package:amigo/models/message.model.dart';
import 'package:flutter/material.dart';
import 'chached-image.widget.dart';

/// Widget to display a grid of media messages (images/videos)
class MediaGridWidget extends StatelessWidget {
  final List<MessageModel> mediaMessages;
  final bool isMyMessage;
  final Function(List<MessageModel>, int) onTap;
  final Function(String, int) onCacheImage;
  final Map<String, String?> videoThumbnailCache;
  final Map<String, Future<String?>> videoThumbnailFutures;
  final Future<String?> Function(String, String) generateVideoThumbnail;

  const MediaGridWidget({
    super.key,
    required this.mediaMessages,
    required this.isMyMessage,
    required this.onTap,
    required this.onCacheImage,
    required this.videoThumbnailCache,
    required this.videoThumbnailFutures,
    required this.generateVideoThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaMessages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Always show maximum 4 items in a 2x2 grid
    final count = mediaMessages.length;
    final crossAxisCount = 2; // Always 2 columns for 2x2 grid
    final aspectRatio = 1.0; // Square items
    final maxItemsToShow = 4; // Always show max 4 items

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey[400]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 0, // No spacing - borders will create lines
            mainAxisSpacing: 0, // No spacing - borders will create lines
            childAspectRatio: aspectRatio,
          ),
          itemCount: count > maxItemsToShow ? maxItemsToShow : count,
          itemBuilder: (context, index) {
            // If there are more than 4 items, show "+X more" overlay on the 4th item (index 3)
            if (count > maxItemsToShow && index == 3) {
              return _buildMoreOverlay(
                context,
                mediaMessages[3], // Show 4th image
                count - maxItemsToShow + 1, // Number of remaining items
              );
            }
            // Otherwise show the image normally
            return _buildGridItem(context, mediaMessages[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    MessageModel message,
    int index,
  ) {
    final isImage = message.type.value.toLowerCase() == 'image' ||
        (message.attachments != null &&
            (message.attachments as Map<String, dynamic>)['category']
                    ?.toString()
                    .toLowerCase() ==
                'images');
    final isVideo = message.type.value.toLowerCase() == 'video' ||
        (message.attachments != null &&
            (message.attachments as Map<String, dynamic>)['category']
                    ?.toString()
                    .toLowerCase() ==
                'videos');

    final attachments = message.attachments as Map<String, dynamic>?;
    final mediaUrl = attachments?['url'] as String?;
    final localPath = attachments?['local_path'] as String?;

    // Calculate position in grid (2 columns, 2 rows max)
    final column = index % 2; // 0 or 1
    final row = index ~/ 2;
    final isLastColumn = column == 1; // Rightmost column
    final isLastRow = row == 1; // Bottom row (always row 1 for 2x2 grid)

    return GestureDetector(
      onTap: () => onTap(mediaMessages, index),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            // Right border: show on all items except last column
            right: isLastColumn
                ? BorderSide.none
                : BorderSide(
                    color: Colors.grey[400]!,
                    width: 2,
                  ),
            // Bottom border: show on all items except last row
            bottom: isLastRow
                ? BorderSide.none
                : BorderSide(
                    color: Colors.grey[400]!,
                    width: 2,
                  ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media thumbnail
            _buildThumbnail(mediaUrl, localPath, isImage, isVideo),
            // Video play icon overlay
            if (isVideo)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            // Upload status overlay
            if (message.metadata?['is_uploading'] == true)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: (message.metadata?['upload_progress'] as int?) != null
                              ? (message.metadata!['upload_progress'] as int) / 100.0
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      if ((message.metadata?['upload_progress'] as int?) != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${message.metadata!['upload_progress']}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    String? mediaUrl,
    String? localPath,
    bool isImage,
    bool isVideo,
  ) {
    if (localPath != null && File(localPath).existsSync()) {
      // Use local file
      if (isImage) {
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        );
      } else if (isVideo) {
        // For video, try to get thumbnail
        return FutureBuilder<String?>(
          future: videoThumbnailFutures[localPath] ??
              Future.value(videoThumbnailCache[localPath]),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.file(
                File(snapshot.data!),
                fit: BoxFit.cover,
              );
            }
            return Container(
              color: Colors.grey[800],
              child: const Icon(Icons.videocam, color: Colors.white54),
            );
          },
        );
      }
    }

    if (mediaUrl != null) {
      if (isImage) {
        return buildCachedImage(
          imageUrl: mediaUrl,
          localPath: null,
          messageId: 0,
          onCacheMedia: (url, id) => onCacheImage(url, id),
        );
      } else if (isVideo) {
        // For video, try to get thumbnail from cache or generate
        final thumbnail = videoThumbnailCache[mediaUrl];
        if (thumbnail != null) {
          return Image.file(
            File(thumbnail),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[800],
                child: const Icon(Icons.videocam, color: Colors.white54),
              );
            },
          );
        } else {
          // Generate thumbnail if not cached
          if (!videoThumbnailFutures.containsKey(mediaUrl)) {
            videoThumbnailFutures[mediaUrl] =
                generateVideoThumbnail(mediaUrl, '');
          }
          return FutureBuilder<String?>(
            future: videoThumbnailFutures[mediaUrl],
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                videoThumbnailCache[mediaUrl] = snapshot.data;
                return Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.videocam, color: Colors.white54),
                    );
                  },
                );
              }
              return Container(
                color: Colors.grey[800],
                child: const Icon(Icons.videocam, color: Colors.white54),
              );
            },
          );
        }
      }
    }

    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildMoreOverlay(
    BuildContext context,
    MessageModel message,
    int remainingCount,
  ) {
    final isImage = message.type.value.toLowerCase() == 'image' ||
        (message.attachments != null &&
            (message.attachments as Map<String, dynamic>)['category']
                    ?.toString()
                    .toLowerCase() ==
                'images');
    final isVideo = message.type.value.toLowerCase() == 'video' ||
        (message.attachments != null &&
            (message.attachments as Map<String, dynamic>)['category']
                    ?.toString()
                    .toLowerCase() ==
                'videos');

    final attachments = message.attachments as Map<String, dynamic>?;
    final mediaUrl = attachments?['url'] as String?;
    final localPath = attachments?['local_path'] as String?;

    // This is always the 4th item (index 3) in a 2x2 grid
    // Position: column 1, row 1 (bottom right) - no borders needed

    return GestureDetector(
      onTap: () => onTap(mediaMessages, 3), // Always index 3 for 4th item
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            // No right border (last column)
            right: BorderSide.none,
            // No bottom border (last row)
            bottom: BorderSide.none,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show the 4th image as background
            _buildThumbnail(mediaUrl, localPath, isImage, isVideo),
            // Video play icon overlay (if it's a video)
            if (isVideo)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            // "+X more" overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
              ),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

