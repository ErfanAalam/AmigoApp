import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Build a cached image widget that loads from local storage when available
Widget buildCachedImage({
  required String imageUrl,
  String? localPath,
  required int messageId,
  required Function(String, int) onCacheMedia,
  double width = 200,
  double height = 200,
}) {
  // If we have a local path and the file exists, use it
  if (localPath != null && io.File(localPath).existsSync()) {
    return Image.file(
      io.File(localPath),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // If local file fails, fall back to network
        return buildNetworkImage(
          imageUrl: imageUrl,
          messageId: messageId,
          onCacheMedia: onCacheMedia,
          width: width,
          height: height,
        );
      },
    );
  }

  // Otherwise load from network and cache
  return buildNetworkImage(
    imageUrl: imageUrl,
    messageId: messageId,
    onCacheMedia: onCacheMedia,
    width: width,
    height: height,
  );
}

/// Build network image widget with caching
Widget buildNetworkImage({
  required String imageUrl,
  required int messageId,
  required Function(String, int) onCacheMedia,
  double width = 200,
  double height = 200,
}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 30, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            'Failed to load',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    ),
    // Cache the image and save path to database
    imageBuilder: (context, imageProvider) {
      // Try to cache the media file
      onCacheMedia(imageUrl, messageId);
      return Image(
        image: imageProvider,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    },
  );
}
