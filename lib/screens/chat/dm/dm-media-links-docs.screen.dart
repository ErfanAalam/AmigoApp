import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../db/repositories/message.repo.dart';
import '../../../models/message.model.dart';
import '../../../models/conversations.model.dart';
import '../../../models/group.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../utils/chat/preview-media.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../services/media-cache.service.dart';

class DmMediaLinksDocsScreen extends ConsumerStatefulWidget {
  final DmModel? dm;
  final GroupModel? group;

  const DmMediaLinksDocsScreen({
    super.key,
    this.dm,
    this.group,
  }) : assert(dm != null || group != null, 'Either dm or group must be provided');

  int get conversationId => dm?.conversationId ?? group!.conversationId;

  @override
  ConsumerState<DmMediaLinksDocsScreen> createState() =>
      _DmMediaLinksDocsScreenState();
}

class _DmMediaLinksDocsScreenState
    extends ConsumerState<DmMediaLinksDocsScreen>
    with SingleTickerProviderStateMixin {
  final MessageRepository _messagesRepo = MessageRepository();
  final MediaCacheService _mediaCacheService = MediaCacheService();

  late TabController _tabController;
  List<MessageModel> _allMessages = [];
  List<MessageModel> _mediaMessages = [];
  List<MessageModel> _linkMessages = [];
  List<MessageModel> _documentMessages = [];
  bool _isLoading = true;

  // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      // Get all messages for this conversation (no limit to get all media)
      _allMessages = await _messagesRepo.getMessagesByConversation(
        widget.conversationId,
        includeDeleted: false,
        // No limit passed - will return all messages
      );

      // Filter messages by type - check both message type and attachment category
      _mediaMessages = _allMessages.where((msg) {
        // Check message type first
        if (msg.isImage || msg.isVideo) {
          return true;
        }
        
        // Check attachment category if type doesn't match
        if (msg.attachments != null) {
          final attachments = msg.attachments as Map<String, dynamic>;
          final category = attachments['category']?.toString().toLowerCase();
          final mimeType = attachments['mime_type']?.toString().toLowerCase();
          final url = attachments['url'] as String?;
          
          // Must have a URL to be valid media
          if (url == null || url.isEmpty) {
            return false;
          }
          
          // Check category
          if (category == 'images' || category == 'image') {
            return true;
          }
          if (category == 'videos' || category == 'video') {
            return true;
          }
          
          // Check mime type as fallback
          if (mimeType != null) {
            if (mimeType.startsWith('image/')) {
              return true;
            }
            if (mimeType.startsWith('video/')) {
              return true;
            }
          }
        }
        
        return false;
      }).toList();

      _documentMessages = _allMessages.where((msg) {
        // Check message type first
        if (msg.isFile) {
          return true;
        }
        
        // Check attachment category if type doesn't match
        if (msg.attachments != null) {
          final attachments = msg.attachments as Map<String, dynamic>;
          final category = attachments['category']?.toString().toLowerCase();
          final mimeType = attachments['mime_type']?.toString().toLowerCase();
          final url = attachments['url'] as String?;
          
          // Must have a URL to be valid document
          if (url == null || url.isEmpty) {
            return false;
          }
          
          // Check category
          if (category == 'docs' || category == 'document' || category == 'file') {
            return true;
          }
          
          // Check mime type as fallback - exclude images and videos
          if (mimeType != null) {
            if (!mimeType.startsWith('image/') && 
                !mimeType.startsWith('video/') && 
                !mimeType.startsWith('audio/')) {
              // It's a document if it's not image, video, or audio
              return true;
            }
          }
          
          // If it has a file_name but no category, it might be a document
          final fileName = attachments['file_name'] as String?;
          if (fileName != null && fileName.isNotEmpty) {
            // Check file extension
            final extension = fileName.split('.').last.toLowerCase();
            final documentExtensions = [
              'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
              'txt', 'rtf', 'odt', 'ods', 'odp',
              'zip', 'rar', '7z', 'tar', 'gz'
            ];
            if (documentExtensions.contains(extension)) {
              return true;
            }
          }
        }
        
        return false;
      }).toList();

      // Extract links from text messages
      _linkMessages = _allMessages.where((msg) {
        if (msg.body == null || msg.body!.isEmpty) return false;
        return _extractUrls(msg.body!).isNotEmpty;
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Extract URLs from text using regex
  List<String> _extractUrls(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media, Links & Docs'),
        backgroundColor: themeColor.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.photo_library),
              text: 'Media',
            ),
            Tab(
              icon: Icon(Icons.link),
              text: 'Links',
            ),
            Tab(
              icon: Icon(Icons.description),
              text: 'Docs',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaTab(),
                _buildLinksTab(),
                _buildDocumentsTab(),
              ],
            ),
    );
  }

  Widget _buildMediaTab() {
    if (_mediaMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No media shared',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _mediaMessages.length,
      itemBuilder: (context, index) {
        final message = _mediaMessages[index];
        return _buildMediaItem(message);
      },
    );
  }

  Widget _buildMediaItem(MessageModel message) {
    final attachments = message.attachments;
    if (attachments == null) {
      return const SizedBox.shrink();
    }

    final mediaUrl = attachments['url'] as String?;
    final localPath = attachments['local_path'] as String?;
    final category = attachments['category']?.toString().toLowerCase();
    final mimeType = attachments['mime_type']?.toString().toLowerCase();

    // Determine if it's an image or video
    bool isImage = false;
    bool isVideo = false;

    // Check message type first
    if (message.isImage) {
      isImage = true;
    } else if (message.isVideo) {
      isVideo = true;
    } else if (category != null) {
      // Check category
      if (category == 'images' || category == 'image') {
        isImage = true;
      } else if (category == 'videos' || category == 'video') {
        isVideo = true;
      }
    } else if (mimeType != null) {
      // Check mime type as fallback
      if (mimeType.startsWith('image/')) {
        isImage = true;
      } else if (mimeType.startsWith('video/')) {
        isVideo = true;
      }
    }

    if (isImage) {
      return _buildImageItem(mediaUrl, localPath, message);
    } else if (isVideo) {
      return _buildVideoItem(mediaUrl, localPath, message);
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageItem(String? imageUrl, String? localPath, MessageModel message) {
    return GestureDetector(
      onTap: imageUrl != null
          ? () => _previewImage(imageUrl, message)
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (localPath != null && File(localPath).existsSync())
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorPlaceholder();
              },
            )
          else if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => _buildErrorPlaceholder(),
            )
          else
            _buildErrorPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildVideoItem(String? videoUrl, String? localPath, MessageModel message) {
    return GestureDetector(
      onTap: videoUrl != null
          ? () => _previewVideo(videoUrl, message)
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: _getVideoThumbnail(videoUrl, localPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildVideoPlaceholder();
                  },
                );
              }
              return _buildVideoPlaceholder();
            },
          ),
          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getVideoThumbnail(String? videoUrl, String? localPath) async {
    final videoPath = localPath ?? videoUrl;
    if (videoPath == null) return null;

    // Check cache first
    if (_videoThumbnailCache.containsKey(videoPath)) {
      return _videoThumbnailCache[videoPath];
    }

    // Check if already generating
    if (_videoThumbnailFutures.containsKey(videoPath)) {
      return await _videoThumbnailFutures[videoPath];
    }

    // Generate thumbnail
    final future = generateVideoThumbnail(videoPath);
    _videoThumbnailFutures[videoPath] = future;

    try {
      final thumbnailPath = await future;
      _videoThumbnailCache[videoPath] = thumbnailPath;
      _videoThumbnailFutures.remove(videoPath);
      return thumbnailPath;
    } catch (e) {
      _videoThumbnailFutures.remove(videoPath);
      _videoThumbnailCache[videoPath] = null;
      return null;
    }
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.videocam,
        color: Colors.white70,
        size: 32,
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  Future<void> _previewImage(String imageUrl, MessageModel message) async {
    await openImagePreview(
      context: context,
      imageUrl: imageUrl,
      caption: message.body,
      messages: _mediaMessages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
    );
  }

  Future<void> _previewVideo(String videoUrl, MessageModel message) async {
    final attachments = message.attachments;
    final fileName = attachments?['file_name'] as String?;

    await openVideoPreview(
      context: context,
      videoUrl: videoUrl,
      caption: message.body,
      fileName: fileName,
      messages: _mediaMessages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
    );
  }

  Widget _buildLinksTab() {
    if (_linkMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No links shared',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _linkMessages.length,
      itemBuilder: (context, index) {
        final message = _linkMessages[index];
        final urls = _extractUrls(message.body!);
        return _buildLinkItem(message, urls);
      },
    );
  }

  Widget _buildLinkItem(MessageModel message, List<String> urls) {
    final themeColor = ref.watch(themeColorProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _openLink(urls.first),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link,
                    color: themeColor.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      urls.first,
                      style: TextStyle(
                        color: themeColor.primary,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (message.body != null && message.body!.length > urls.first.length) ...[
                const SizedBox(height: 8),
                Text(
                  message.body!.replaceAll(urls.first, '').trim(),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                ChatHelpers.formatMessageTime(message.sentAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    try {
      // Add https:// if missing
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }

      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open URL: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error opening link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  Widget _buildDocumentsTab() {
    if (_documentMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No documents shared',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _documentMessages.length,
      itemBuilder: (context, index) {
        final message = _documentMessages[index];
        return _buildDocumentItem(message);
      },
    );
  }

  Widget _buildDocumentItem(MessageModel message) {
    final themeColor = ref.watch(themeColorProvider);
    final attachments = message.attachments;

    if (attachments == null) {
      return const SizedBox.shrink();
    }

    final documentUrl = attachments['url'] as String?;
    final fileName = attachments['file_name'] as String? ?? 'Document';
    final fileSize = attachments['file_size'] as int?;
    final mimeType = attachments['mime_type'] as String?;

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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: documentUrl != null
            ? () => _previewDocument(documentUrl, fileName, message.body, fileSize)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  docIcon,
                  color: themeColor.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fileSize != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ChatHelpers.formatFileSize(fileSize),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      ChatHelpers.formatMessageTime(message.sentAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewDocument(
    String documentUrl,
    String? fileName,
    String? caption,
    int? fileSize,
  ) {
    openDocumentPreview(
      context: context,
      documentUrl: documentUrl,
      fileName: fileName,
      caption: caption,
      fileSize: fileSize,
    );
  }
}

