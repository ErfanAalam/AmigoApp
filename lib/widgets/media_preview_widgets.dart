import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class ImagePreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final List<String>? captions;

  const ImagePreviewScreen({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.captions,
  }) : super(key: key);

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadImage(widget.imageUrls[_currentIndex]),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareImage(widget.imageUrls[_currentIndex]),
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(widget.imageUrls[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.5,
                maxScale: PhotoViewComputedScale.covered * 2.0,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: widget.imageUrls[index],
                ),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: _pageController,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          if (widget.captions != null &&
              widget.captions!.isNotEmpty &&
              _currentIndex < widget.captions!.length &&
              widget.captions![_currentIndex].isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Text(
                  widget.captions![_currentIndex],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _downloadImage(String imageUrl) {
    // TODO: Implement image download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality to be implemented')),
    );
  }

  void _shareImage(String imageUrl) {
    // TODO: Implement image sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality to be implemented')),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final String videoUrl;
  final String? caption;
  final String? fileName;

  const VideoPreviewScreen({
    Key? key,
    required this.videoUrl,
    this.caption,
    this.fileName,
  }) : super(key: key);

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController.initialize();

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.teal,
            handleColor: Colors.teal,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.lightGreen,
          ),
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          errorBuilder: (context, errorMessage) {
            return Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load video',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );

        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.fileName ?? 'Video',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadVideo(),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareVideo(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _hasError
                  ? Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load video',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : _isInitialized && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Text(
                widget.caption!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _downloadVideo() {
    // TODO: Implement video download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality to be implemented')),
    );
  }

  void _shareVideo() {
    // TODO: Implement video sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality to be implemented')),
    );
  }
}

class DocumentPreviewScreen extends StatefulWidget {
  final String documentUrl;
  final String? fileName;
  final String? caption;
  final int? fileSize;

  const DocumentPreviewScreen({
    Key? key,
    required this.documentUrl,
    this.fileName,
    this.caption,
    this.fileSize,
  }) : super(key: key);

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  String get _fileExtension {
    if (widget.fileName != null) {
      return path.extension(widget.fileName!).toLowerCase();
    }
    return path.extension(widget.documentUrl).toLowerCase();
  }

  IconData get _documentIcon {
    switch (_fileExtension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.txt':
        return Icons.text_snippet;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _documentColor {
    switch (_fileExtension) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.xls':
      case '.xlsx':
        return Colors.green;
      case '.ppt':
      case '.pptx':
        return Colors.orange;
      case '.txt':
        return Colors.grey;
      case '.zip':
      case '.rar':
      case '.7z':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Document Preview',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.black87),
            onPressed: () => _downloadDocument(),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () => _shareDocument(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _documentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _documentColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(_documentIcon, size: 64, color: _documentColor),
              ),
              const SizedBox(height: 24),
              Text(
                widget.fileName ?? 'Document',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.fileSize != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatFileSize(widget.fileSize!),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openDocument(),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _documentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _downloadDocument(),
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _documentColor,
                        side: BorderSide(color: _documentColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.caption != null && widget.caption!.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caption',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.caption!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument() async {
    try {
      final Uri uri = Uri.parse(widget.documentUrl);

      // First try to launch with external application
      bool launched = false;

      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Failed to launch with external application: $e');
      }

      // If external application failed, try with platform default
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e) {
          debugPrint('Failed to launch with platform default: $e');
        }
      }

      // If platform default failed, try with in-app web view
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (e) {
          debugPrint('Failed to launch with in-app web view: $e');
        }
      }

      // If all methods failed, show options dialog
      if (!launched && mounted) {
        _showDocumentOpenOptions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening document: $e')));
      }
    }
  }

  void _showDocumentOpenOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Open Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose how to open this document:'),
              const SizedBox(height: 16),
              Text(
                'File: ${widget.fileName ?? 'Document'}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'URL: ${widget.documentUrl}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _copyUrlToClipboard();
              },
              child: const Text('Copy URL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openInBrowser();
              },
              child: const Text('Open in Browser'),
            ),
          ],
        );
      },
    );
  }

  void _copyUrlToClipboard() async {
    try {
      // Import clipboard functionality
      await Clipboard.setData(ClipboardData(text: widget.documentUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document URL copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to copy URL: $e')));
      }
    }
  }

  void _openInBrowser() async {
    try {
      final Uri uri = Uri.parse(widget.documentUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open in browser: $e')),
        );
      }
    }
  }

  void _downloadDocument() {
    // TODO: Implement document download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality to be implemented')),
    );
  }

  void _shareDocument() {
    // TODO: Implement document sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality to be implemented')),
    );
  }
}
