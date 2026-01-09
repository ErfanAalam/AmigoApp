import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final CancelToken _cancelToken = CancelToken();

  /// Downloads a file from URL and saves it to device storage
  /// Returns the local file path if successful, null if failed
  Future<String?> downloadFile({
    required String url,
    String? fileName,
    required String fileType, // 'image', 'video', 'document'
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      // Request storage permission with detailed feedback
      final permissionResult = await _requestStoragePermissionWithFeedback();
      if (!permissionResult['granted']) {
        onError?.call(
          permissionResult['message'] ?? 'Storage permission denied',
        );
        return null;
      }

      // Get the appropriate directory for the file type
      Directory? directory = await _getDirectoryForFileType(fileType);
      if (directory == null) {
        onError?.call('Failed to get storage directory');
        return null;
      }

      // Generate filename if not provided
      String finalFileName = fileName ?? _generateFileName(url, fileType);

      // Ensure directory exists
      try {
        if (!await directory.exists()) {
          debugPrint('Creating directory: ${directory.path}');
          await directory.create(recursive: true);
          debugPrint('Directory created successfully');
        } else {
          debugPrint('Directory already exists: ${directory.path}');
        }

        // Verify directory is writable
        if (!await directory.exists()) {
          onError?.call('Failed to create storage directory');
          return null;
        }
      } catch (e) {
        debugPrint('Error creating directory: $e');
        onError?.call('Failed to create storage directory: $e');
        return null;
      }

      String filePath = path.join(directory.path, finalFileName);
      debugPrint('Final file path: $filePath');

      // Check if file already exists
      if (await File(filePath).exists()) {
        debugPrint('File already exists, generating unique name');
        // Generate unique filename
        finalFileName = _generateUniqueFileName(finalFileName);
        filePath = path.join(directory.path, finalFileName);
        debugPrint('New file path: $filePath');
      }

      // Download the file
      debugPrint('Starting download from: $url');
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            double progress = received / total;
            onProgress(progress);
            debugPrint(
              'Download progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
        cancelToken: _cancelToken,
        options: Options(
          headers: {'User-Agent': 'Amigo-App/1.0'},
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      // Verify file was downloaded successfully
      final downloadedFile = File(filePath);
      if (await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();
        debugPrint(
          'Download completed successfully. File size: $fileSize bytes',
        );
        debugPrint('File saved to: $filePath');
        return filePath;
      } else {
        onError?.call('Download completed but file not found');
        return null;
      }
    } catch (e) {
      onError?.call('Download failed: ${e.toString()}');
      return null;
    }
  }

  /// Requests storage permission with detailed feedback
  Future<Map<String, dynamic>> _requestStoragePermissionWithFeedback() async {
    if (Platform.isAndroid) {
      try {
        // Check current Android SDK version
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        debugPrint('Android SDK Version: $sdkInt');

        // For Android 11+ (API 30+), use granular media permissions
        if (sdkInt >= 30) {
          // Android 11+ uses granular media permissions for photos, videos, and audio
          debugPrint('Requesting granular media permissions for Android 11+');

          Map<Permission, PermissionStatus> statuses = await [
            Permission.photos,
            Permission.videos,
            Permission.audio,
          ].request();

          debugPrint('Permission statuses: $statuses');

          // Check if any permission was granted
          bool anyGranted = statuses.values.any(
            (status) => status == PermissionStatus.granted,
          );

          if (anyGranted) {
            return {'granted': true, 'message': 'Permissions granted'};
          } else {
            // Check if permissions were permanently denied
            bool anyPermanentlyDenied = statuses.values.any(
              (status) => status == PermissionStatus.permanentlyDenied,
            );
            if (anyPermanentlyDenied) {
              return {
                'granted': false,
                'message':
                    'Storage permissions are permanently denied. Please enable them in app settings.',
              };
            }
            return {'granted': false, 'message': 'Storage permissions denied'};
          }
        } else {
          // For older Android versions (API < 30), use storage permission
          debugPrint(
            'Requesting storage permission for older Android versions',
          );

          PermissionStatus status = await Permission.storage.request();
          debugPrint('Storage permission status: $status');

          if (status == PermissionStatus.granted) {
            return {'granted': true, 'message': 'Storage permission granted'};
          } else if (status == PermissionStatus.permanentlyDenied) {
            return {
              'granted': false,
              'message':
                  'Storage permission is permanently denied. Please enable it in app settings.',
            };
          }
          return {'granted': false, 'message': 'Storage permission denied'};
        }
      } catch (e) {
        debugPrint('Error requesting permissions: $e');
        return {
          'granted': false,
          'message': 'Error requesting storage permissions: $e',
        };
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require storage permission for app documents
      return {'granted': true, 'message': 'No permissions required for iOS'};
    }
    return {
      'granted': true,
      'message': 'No permissions required for this platform',
    };
  }

  /// Gets the appropriate directory for the file type
  Future<Directory?> _getDirectoryForFileType(String fileType) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        try {
          // Check Android version to determine storage strategy
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          final sdkInt = androidInfo.version.sdkInt;

          debugPrint('Android SDK Version for storage: $sdkInt');

          // Try multiple storage strategies in order of preference
          List<Directory> candidateDirectories = [];

          // Strategy 1: Try to use external storage directory (app-specific)
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              switch (fileType) {
                case 'image':
                  candidateDirectories.add(
                    Directory(path.join(externalDir.path, 'Pictures', 'Amigo')),
                  );
                  candidateDirectories.add(
                    Directory('/storage/emulated/0/Pictures/Amigo'),
                  );
                  break;
                case 'video':
                  candidateDirectories.add(
                    Directory(path.join(externalDir.path, 'Movies', 'Amigo')),
                  );
                  candidateDirectories.add(
                    Directory('/storage/emulated/0/Movies/Amigo'),
                  );
                  break;
                case 'document':
                  candidateDirectories.add(
                    Directory(path.join(externalDir.path, 'Download', 'Amigo')),
                  );
                  candidateDirectories.add(
                    Directory('/storage/emulated/0/Download/Amigo'),
                  );
                  break;
                default:
                  candidateDirectories.add(
                    Directory(path.join(externalDir.path, 'Download', 'Amigo')),
                  );
                  candidateDirectories.add(
                    Directory('/storage/emulated/0/Download/Amigo'),
                  );
              }
            }
          } catch (e) {
            debugPrint('Error getting external storage directory: $e');
          }

          // Strategy 2: Try Downloads folder directly (works on most Android versions)
          try {
            switch (fileType) {
              case 'image':
                candidateDirectories.add(
                  Directory('/storage/emulated/0/Download/Amigo/Images'),
                );
                break;
              case 'video':
                candidateDirectories.add(
                  Directory('/storage/emulated/0/Download/Amigo/Videos'),
                );
                break;
              case 'document':
                candidateDirectories.add(
                  Directory('/storage/emulated/0/Download/Amigo/Documents'),
                );
                break;
              default:
                candidateDirectories.add(
                  Directory('/storage/emulated/0/Download/Amigo'),
                );
            }
          } catch (e) {
            debugPrint('Error creating Downloads directory path: $e');
          }

          // Strategy 3: Fallback to app documents directory (always works)
          try {
            Directory appDocDir = await getApplicationDocumentsDirectory();
            switch (fileType) {
              case 'image':
                candidateDirectories.add(
                  Directory(path.join(appDocDir.path, 'Images')),
                );
                break;
              case 'video':
                candidateDirectories.add(
                  Directory(path.join(appDocDir.path, 'Videos')),
                );
                break;
              case 'document':
                candidateDirectories.add(
                  Directory(path.join(appDocDir.path, 'Documents')),
                );
                break;
              default:
                candidateDirectories.add(
                  Directory(path.join(appDocDir.path, 'Downloads')),
                );
            }
          } catch (e) {
            debugPrint('Error getting app documents directory: $e');
          }

          // Try each directory until we find one that works
          for (Directory candidateDir in candidateDirectories) {
            try {
              debugPrint('Trying directory: ${candidateDir.path}');

              // Try to create the directory
              if (!await candidateDir.exists()) {
                await candidateDir.create(recursive: true);
              }

              // Test if we can write to it
              final testFile = File(
                path.join(candidateDir.path, 'test_write.tmp'),
              );
              await testFile.writeAsString('test');
              await testFile.delete();

              // If we get here, this directory works
              directory = candidateDir;
              debugPrint('Successfully using directory: ${candidateDir.path}');
              break;
            } catch (e) {
              debugPrint('Directory ${candidateDir.path} failed: $e');
              continue;
            }
          }

          // If all directories failed, use the last fallback (app documents)
          if (directory == null) {
            debugPrint('All directories failed, using app documents fallback');
            Directory appDocDir = await getApplicationDocumentsDirectory();
            directory = Directory(path.join(appDocDir.path, 'Downloads'));
            await directory.create(recursive: true);
          }
        } catch (e) {
          debugPrint('Error getting Android storage directory: $e');
          // Final fallback
          Directory appDocDir = await getApplicationDocumentsDirectory();
          directory = Directory(path.join(appDocDir.path, 'Downloads'));
        }
      } else if (Platform.isIOS) {
        // For iOS, use app documents directory
        Directory appDocDir = await getApplicationDocumentsDirectory();
        switch (fileType) {
          case 'image':
            directory = Directory(path.join(appDocDir.path, 'Images'));
            break;
          case 'video':
            directory = Directory(path.join(appDocDir.path, 'Videos'));
            break;
          case 'document':
            directory = Directory(path.join(appDocDir.path, 'Documents'));
            break;
          default:
            directory = Directory(path.join(appDocDir.path, 'Downloads'));
        }
      } else {
        // For other platforms, use app documents directory
        Directory appDocDir = await getApplicationDocumentsDirectory();
        directory = Directory(path.join(appDocDir.path, 'Downloads'));
      }

      debugPrint('Selected directory for $fileType: ${directory.path}');
      return directory;
    } catch (e) {
      debugPrint('Error getting directory: $e');
      return null;
    }
  }

  /// Generates filename from URL and file type
  String _generateFileName(String url, String fileType) {
    try {
      String extension = path.extension(url).toLowerCase();

      // If no extension in URL, add default extension based on file type
      if (extension.isEmpty) {
        switch (fileType) {
          case 'image':
            extension = '.jpg';
            break;
          case 'video':
            extension = '.mp4';
            break;
          case 'document':
            extension = '.pdf';
            break;
        }
      }

      // Generate filename with timestamp
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String baseName = path.basenameWithoutExtension(url);

      if (baseName.isEmpty || baseName.length > 50) {
        baseName = 'amigo_${fileType}_$timestamp';
      }

      return '$baseName$extension';
    } catch (e) {
      // Fallback filename
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String extension = fileType == 'image'
          ? '.jpg'
          : fileType == 'video'
          ? '.mp4'
          : '.pdf';
      return 'amigo_${fileType}_$timestamp$extension';
    }
  }

  /// Generates unique filename if file already exists
  String _generateUniqueFileName(String fileName) {
    String nameWithoutExt = path.basenameWithoutExtension(fileName);
    String extension = path.extension(fileName);
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '${nameWithoutExt}_$timestamp$extension';
  }

  /// Opens a file with the system default application
  Future<bool> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error opening file: $e');
      return false;
    }
  }

  /// Shares a file
  Future<void> shareFile(String filePath, {String? text}) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: text);
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }

  /// Cancels ongoing download
  void cancelDownload() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
  }

  /// Opens app settings for permission management
  Future<void> openAppSettingsForPermissions() async {
    try {
      // Open app settings to allow user to manually enable permissions
      await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  /// Checks if storage permissions are granted
  Future<bool> areStoragePermissionsGranted() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 30) {
          // Check granular media permissions for Android 11+
          Map<Permission, PermissionStatus> statuses = await [
            Permission.photos,
            Permission.videos,
            Permission.audio,
          ].request();

          return statuses.values.any(
            (status) => status == PermissionStatus.granted,
          );
        } else {
          // Check storage permission for older versions
          return await Permission.storage.isGranted;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require storage permission for app documents
      return true;
    }
    return true;
  }

  /// Checks if a file exists at the given path
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Gets file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  /// Formats file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Gets the download directory path for a specific file type
  Future<String?> getDownloadDirectoryPath(String fileType) async {
    try {
      final directory = await _getDirectoryForFileType(fileType);
      return directory?.path;
    } catch (e) {
      debugPrint('Error getting download directory path: $e');
      return null;
    }
  }

  /// Lists all downloaded files in the specified directory
  Future<List<FileSystemEntity>> listDownloadedFiles(String fileType) async {
    try {
      final directory = await _getDirectoryForFileType(fileType);
      if (directory != null && await directory.exists()) {
        return directory.listSync();
      }
      return [];
    } catch (e) {
      debugPrint('Error listing downloaded files: $e');
      return [];
    }
  }

  /// Downloads file to Downloads folder using system directory
  Future<String?> downloadToDownloadsFolder({
    required String url,
    String? fileName,
    required String fileType,
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      // Request storage permission with detailed feedback
      final permissionResult = await _requestStoragePermissionWithFeedback();
      if (!permissionResult['granted']) {
        onError?.call(
          permissionResult['message'] ?? 'Storage permission denied',
        );
        return null;
      }

      // Use system Downloads directory
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        try {
          // Try to get system Downloads directory
          downloadsDir = Directory('/storage/emulated/0/Download');

          // Create Amigo subfolder
          downloadsDir = Directory(path.join(downloadsDir.path, 'Amigo'));

          // Create subfolder based on file type
          switch (fileType) {
            case 'image':
              downloadsDir = Directory(path.join(downloadsDir.path, 'Images'));
              break;
            case 'video':
              downloadsDir = Directory(path.join(downloadsDir.path, 'Videos'));
              break;
            case 'document':
              downloadsDir = Directory(
                path.join(downloadsDir.path, 'Documents'),
              );
              break;
            default:
              downloadsDir = Directory(path.join(downloadsDir.path, 'Files'));
          }

          debugPrint('Using Downloads directory: ${downloadsDir.path}');
        } catch (e) {
          debugPrint('Error getting Downloads directory: $e');
          onError?.call('Failed to access Downloads folder');
          return null;
        }
      } else {
        // For iOS and other platforms, use app documents
        Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(appDocDir.path, 'Downloads'));
      }

      // Generate filename if not provided
      String finalFileName = fileName ?? _generateFileName(url, fileType);

      // Ensure directory exists
      try {
        if (!await downloadsDir.exists()) {
          debugPrint('Creating Downloads directory: ${downloadsDir.path}');
          await downloadsDir.create(recursive: true);
          debugPrint('Downloads directory created successfully');
        }

        // Verify directory is writable
        if (!await downloadsDir.exists()) {
          onError?.call('Failed to create Downloads directory');
          return null;
        }
      } catch (e) {
        debugPrint('Error creating Downloads directory: $e');
        onError?.call('Failed to create Downloads directory: $e');
        return null;
      }

      String filePath = path.join(downloadsDir.path, finalFileName);
      debugPrint('Final file path: $filePath');

      // Check if file already exists
      if (await File(filePath).exists()) {
        debugPrint('File already exists, generating unique name');
        finalFileName = _generateUniqueFileName(finalFileName);
        filePath = path.join(downloadsDir.path, finalFileName);
        debugPrint('New file path: $filePath');
      }

      // Download the file
      debugPrint('Starting download from: $url');
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            double progress = received / total;
            onProgress(progress);
            debugPrint(
              'Download progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
        cancelToken: _cancelToken,
        options: Options(
          headers: {'User-Agent': 'Amigo-App/1.0'},
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      // Verify file was downloaded successfully
      final downloadedFile = File(filePath);
      if (await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();
        debugPrint(
          'Download completed successfully. File size: $fileSize bytes',
        );
        debugPrint('File saved to: $filePath');
        return filePath;
      } else {
        onError?.call('Download completed but file not found');
        return null;
      }
    } catch (e) {
      onError?.call('Download failed: ${e.toString()}');
      return null;
    }
  }
}
