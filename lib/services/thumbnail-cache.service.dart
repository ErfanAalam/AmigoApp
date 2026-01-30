import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service to handle persistent caching of video thumbnails
/// Stores thumbnails in permanent storage to avoid regeneration
class ThumbnailCacheService {
  static final ThumbnailCacheService _instance = ThumbnailCacheService._internal();
  factory ThumbnailCacheService() => _instance;
  ThumbnailCacheService._internal();

  // In-memory cache for quick access
  final Map<String, String?> _memoryCache = {};
  
  // Track ongoing thumbnail generation to prevent duplicates
  final Map<String, Future<String?>> _generatingThumbnails = {};

  /// Get the cache directory for thumbnails
  Future<Directory> _getThumbnailCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/thumbnail_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a unique filename from video URL using MD5 hash
  String _generateThumbnailFileName(String videoUrl) {
    final bytes = utf8.encode(videoUrl);
    final digest = md5.convert(bytes);
    return 'thumb_$digest.png';
  }

  /// Check if a thumbnail is already cached
  /// Returns the local path if cached, null otherwise
  Future<String?> getCachedThumbnailPath(String videoUrl) async {
    try {
      // Check memory cache first (fastest)
      if (_memoryCache.containsKey(videoUrl)) {
        final cachedPath = _memoryCache[videoUrl];
        if (cachedPath != null && await File(cachedPath).exists()) {
          return cachedPath;
        } else {
          // Cached path is invalid, remove from memory cache
          _memoryCache.remove(videoUrl);
        }
      }

      // Check disk cache
      final cacheDir = await _getThumbnailCacheDirectory();
      final fileName = _generateThumbnailFileName(videoUrl);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        debugPrint('✅ Thumbnail cache hit: $fileName');
        _memoryCache[videoUrl] = file.path; // Update memory cache
        return file.path;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking thumbnail cache: $e');
      return null;
    }
  }

  /// Generate and cache a video thumbnail
  /// Returns the local path of the cached thumbnail
  Future<String?> generateAndCacheThumbnail(String videoUrl) async {
    try {
      // Check if already cached
      final cachedPath = await getCachedThumbnailPath(videoUrl);
      if (cachedPath != null) {
        return cachedPath;
      }

      // Check if already generating
      if (_generatingThumbnails.containsKey(videoUrl)) {
        debugPrint('⏳ Already generating thumbnail for: $videoUrl');
        return await _generatingThumbnails[videoUrl];
      }

      // Start generation
      final generationFuture = _performThumbnailGeneration(videoUrl);
      _generatingThumbnails[videoUrl] = generationFuture;

      final result = await generationFuture;
      _generatingThumbnails.remove(videoUrl);

      return result;
    } catch (e) {
      debugPrint('❌ Error generating thumbnail: $e');
      _generatingThumbnails.remove(videoUrl);
      return null;
    }
  }

  Future<String?> _performThumbnailGeneration(String videoUrl) async {
    try {
      final cacheDir = await _getThumbnailCacheDirectory();
      final fileName = _generateThumbnailFileName(videoUrl);
      final targetPath = '${cacheDir.path}/$fileName';

      debugPrint('🎬 Generating thumbnail for: $videoUrl');

      // Generate thumbnail directly to our cache directory
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: cacheDir.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 220,
        quality: 75,
      );

      if (thumbnailPath == null) {
        debugPrint('❌ Thumbnail generation returned null');
        return null;
      }

      // If the generated file has a different name, rename it
      final generatedFile = File(thumbnailPath);
      if (thumbnailPath != targetPath && await generatedFile.exists()) {
        final renamedFile = await generatedFile.rename(targetPath);
        debugPrint('✅ Thumbnail cached: $fileName');
        _memoryCache[videoUrl] = renamedFile.path;
        return renamedFile.path;
      }

      debugPrint('✅ Thumbnail cached: $fileName');
      _memoryCache[videoUrl] = thumbnailPath;
      return thumbnailPath;
    } catch (e) {
      debugPrint('❌ Error in thumbnail generation: $e');
      return null;
    }
  }

  /// Get thumbnail path, generating if needed
  /// This is the main method to use throughout the app
  Future<String?> getThumbnail(String videoUrl) async {
    // Try to get from cache first
    final cachedPath = await getCachedThumbnailPath(videoUrl);
    if (cachedPath != null) {
      return cachedPath;
    }

    // Generate if not cached
    return await generateAndCacheThumbnail(videoUrl);
  }

  /// Pre-generate thumbnail in background (fire and forget)
  void preGenerateThumbnail(String videoUrl) {
    generateAndCacheThumbnail(videoUrl)
        .then((path) {
          if (path != null) {
            debugPrint('✅ Pre-generated thumbnail: $videoUrl');
          }
        })
        .catchError((e) {
          debugPrint('❌ Error pre-generating thumbnail: $e');
        });
  }

  /// Clear a specific thumbnail from cache
  Future<bool> clearThumbnail(String videoUrl) async {
    try {
      final cacheDir = await _getThumbnailCacheDirectory();
      final fileName = _generateThumbnailFileName(videoUrl);
      final file = File('${cacheDir.path}/$fileName');

      _memoryCache.remove(videoUrl);

      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted thumbnail: $fileName');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting thumbnail: $e');
      return false;
    }
  }

  /// Clear all cached thumbnails
  Future<void> clearAllThumbnails() async {
    try {
      final cacheDir = await _getThumbnailCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
        _memoryCache.clear();
        debugPrint('🗑️ All thumbnails cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing thumbnails: $e');
    }
  }

  /// Get total thumbnail cache size in bytes
  Future<int> getThumbnailCacheSize() async {
    try {
      final cacheDir = await _getThumbnailCacheDirectory();
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
      debugPrint('❌ Error calculating thumbnail cache size: $e');
      return 0;
    }
  }

  /// Clear memory cache (useful when memory is tight)
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('🧹 Memory cache cleared');
  }

  /// Get memory cache statistics
  Map<String, dynamic> getMemoryCacheStats() {
    return {
      'entries': _memoryCache.length,
      'generating': _generatingThumbnails.length,
    };
  }
}
