import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service to handle downloading and caching media files locally
/// Supports images, videos, and audio files
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  final Dio _dio = Dio();
  final Map<String, Future<String?>> _downloadingFiles = {};

  /// Get the cache directory for media files
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/media_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a unique filename from URL using MD5 hash
  String _generateCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    final extension = path
        .extension(url)
        .split('?')
        .first; // Remove query params
    return '$digest$extension';
  }

  /// Check if a media file is already cached locally
  Future<String?> getCachedFilePath(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        debugPrint('✅ Media cache hit: $fileName');
        return file.path;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking cache: $e');
      return null;
    }
  }

  /// Download and cache a media file
  /// Returns the local file path on success, null on failure
  Future<String?> downloadAndCacheMedia(
    String url, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // Check if already cached
      final cachedPath = await getCachedFilePath(url);
      if (cachedPath != null) {
        return cachedPath;
      }

      // Check if already downloading
      if (_downloadingFiles.containsKey(url)) {
        debugPrint('⏳ Already downloading: $url');
        return await _downloadingFiles[url];
      }

      // Start download
      final downloadFuture = _performDownload(url, onProgress: onProgress);
      _downloadingFiles[url] = downloadFuture;

      final result = await downloadFuture;
      _downloadingFiles.remove(url);

      return result;
    } catch (e) {
      debugPrint('❌ Error downloading media: $e');
      _downloadingFiles.remove(url);
      return null;
    }
  }

  Future<String?> _performDownload(
    String url, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateCacheFileName(url);
      final filePath = '${cacheDir.path}/$fileName';
      final tempFilePath = '$filePath.tmp';

      debugPrint('📥 Downloading media: $url');
      debugPrint('💾 Saving to: $filePath');

      // Download to temporary file first
      await _dio.download(
        url,
        tempFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received, total);
          }
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      // Rename temp file to final file
      final tempFile = File(tempFilePath);
      final finalFile = await tempFile.rename(filePath);

      return finalFile.path;
    } catch (e) {
      debugPrint('❌ Error in _performDownload: $e');
      // Clean up temp file if it exists
      final tempFile = File(
        '${await _getCacheDirectory()}.path/${_generateCacheFileName(url)}.tmp',
      );
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    }
  }

  /// Get or download media file
  /// First checks cache, then downloads if needed
  Future<String?> getMediaFile(String url) async {
    // Check cache first
    final cachedPath = await getCachedFilePath(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    // Download if not cached
    return await downloadAndCacheMedia(url);
  }

  /// Delete a specific cached file
  Future<bool> deleteCachedFile(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted cached file: $fileName');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting cached file: $e');
      return false;
    }
  }

  /// Clear all cached media files
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
        debugPrint('🗑️ All media cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  /// Format bytes to human-readable size
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Pre-cache media for a message (background download)
  Future<void> preCacheMessageMedia(String url) async {
    // Fire and forget - don't wait for completion
    downloadAndCacheMedia(url)
        .then((path) {
          if (path != null) {
            debugPrint('✅ Pre-cached media: $url');
          }
        })
        .catchError((e) {
          debugPrint('❌ Error pre-caching media: $e');
        });
  }

  /// Pre-cache multiple media files
  Future<void> preCacheMultipleMedia(List<String> urls) async {
    for (final url in urls) {
      await preCacheMessageMedia(url);
    }
  }
}
