import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service to manage shared media files globally across the app
class SharedMediaService {
  // Singleton pattern
  static final SharedMediaService _instance = SharedMediaService._internal();
  factory SharedMediaService() => _instance;
  SharedMediaService._internal();

  // Current shared files
  List<SharedMediaFile> _sharedFiles = [];

  // Stream controller for shared files
  final _sharedFilesController =
      StreamController<List<SharedMediaFile>>.broadcast();

  /// Get the stream of shared files
  Stream<List<SharedMediaFile>> get sharedFilesStream =>
      _sharedFilesController.stream;

  /// Get current shared files
  List<SharedMediaFile> get sharedFiles => List.unmodifiable(_sharedFiles);

  /// Check if there are any shared files
  bool get hasSharedFiles => _sharedFiles.isNotEmpty;

  /// Set shared files
  void setSharedFiles(List<SharedMediaFile> files) {
    _sharedFiles = files;
    _sharedFilesController.add(_sharedFiles);
  }

  /// Add shared files
  void addSharedFiles(List<SharedMediaFile> files) {
    _sharedFiles.addAll(files);
    _sharedFilesController.add(_sharedFiles);
  }

  /// Clear shared files
  void clearSharedFiles() {
    _sharedFiles.clear();
    _sharedFilesController.add(_sharedFiles);
  }

  /// Remove a specific file
  void removeFile(SharedMediaFile file) {
    _sharedFiles.remove(file);
    _sharedFilesController.add(_sharedFiles);
  }

  /// Dispose the service
  void dispose() {
    _sharedFilesController.close();
  }
}
