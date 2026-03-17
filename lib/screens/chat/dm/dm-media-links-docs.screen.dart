import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app-colors.config.dart';
import '../../../utils/animations.utils.dart';
import '../../../db/repositories/message.repo.dart';
import '../../../models/message.model.dart';
import '../../../models/conversations.model.dart';
import '../../../models/group.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../utils/chat/preview-media.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/thumbnail-cache.service.dart';

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
    with TickerProviderStateMixin {
  final MessageRepository _messagesRepo = MessageRepository();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  final ThumbnailCacheService _thumbnailCacheService = ThumbnailCacheService();

  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  List<MessageModel> _allMessages = [];
  List<MessageModel> _mediaMessages = [];
  List<MessageModel> _linkMessages = [];
  List<MessageModel> _documentMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
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
      _fadeController.forward();
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      setState(() => _isLoading = false);
      _fadeController.forward();
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
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Media, Links & Docs',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.primaryDark,
                themeColor.primary,
                themeColor.primaryLight,
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: themeColor.primaryDark,
              unselectedLabelColor: Colors.white.withOpacity(0.85),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              labelPadding: EdgeInsets.zero,
              tabs: [
                _buildTab(Icons.photo_library_rounded, 'Media', _mediaMessages.length),
                _buildTab(Icons.link_rounded, 'Links', _linkMessages.length),
                _buildTab(Icons.description_rounded, 'Docs', _documentMessages.length),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(themeColor)
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMediaTab(themeColor),
                    _buildLinksTab(themeColor),
                    _buildDocumentsTab(themeColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTab(IconData icon, String label, int count) {
    return Tab(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(label),
          if (count > 0 && !_isLoading) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorTheme themeColor) {
    return Column(
      children: [
        // Spacer for AppBar + TabBar
        SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 56),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              return _AnimatedSkeletonTile(index: index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String message, ColorTheme themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColor.primary.withOpacity(0.08),
                  themeColor.primaryLight.withOpacity(0.15),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 48,
              color: themeColor.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Items will appear here once shared',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(ColorTheme themeColor) {
    if (_mediaMessages.isEmpty) {
      return _buildEmptyState(
        Icons.photo_library_outlined,
        'No media shared',
        themeColor,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12 + kToolbarHeight + 56 + MediaQuery.of(context).padding.top, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _mediaMessages.length,
      // Increase cache extent to keep more images in memory
      cacheExtent: 1000, // Keep images within 1000px offscreen
      itemBuilder: (context, index) {
        final message = _mediaMessages[index];
        return StaggeredScaleFadeTile(
          index: index,
          child: _buildMediaItem(message),
        );
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

    // Wrap in RepaintBoundary to prevent unnecessary repaints
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: isImage
            ? _buildImageItem(mediaUrl, localPath, message)
            : isVideo
                ? _buildVideoItem(mediaUrl, localPath, message)
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildImageItem(String? imageUrl, String? localPath, MessageModel message) {
    return _CachedImageGridItem(
      imageUrl: imageUrl,
      localPath: localPath,
      onTap: imageUrl != null ? () => _previewImage(imageUrl, message) : null,
    );
  }

  Widget _buildVideoItem(String? videoUrl, String? localPath, MessageModel message) {
    return _CachedVideoGridItem(
      videoUrl: videoUrl,
      localPath: localPath,
      thumbnailCacheService: _thumbnailCacheService,
      onTap: videoUrl != null ? () => _previewVideo(videoUrl, message) : null,
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

  Widget _buildLinksTab(ColorTheme themeColor) {
    if (_linkMessages.isEmpty) {
      return _buildEmptyState(
        Icons.link_off_rounded,
        'No links shared',
        themeColor,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16 + kToolbarHeight + 56 + MediaQuery.of(context).padding.top, 16, 16),
      itemCount: _linkMessages.length,
      itemBuilder: (context, index) {
        final message = _linkMessages[index];
        final urls = _extractUrls(message.body!);
        return StaggeredSlideFadeItem(
          index: index,
          child: _buildLinkItem(message, urls, themeColor),
        );
      },
    );
  }

  Widget _buildLinkItem(MessageModel message, List<String> urls, ColorTheme themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openLink(urls.first),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        themeColor.primary.withOpacity(0.12),
                        themeColor.primaryLight.withOpacity(0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: themeColor.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urls.first,
                        style: TextStyle(
                          color: themeColor.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: themeColor.primary.withOpacity(0.4),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.body != null && message.body!.length > urls.first.length) ...[
                        const SizedBox(height: 6),
                        Text(
                          message.body!.replaceAll(urls.first, '').trim(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        ChatHelpers.formatMessageTime(message.sentAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Colors.grey[350],
                  ),
                ),
              ],
            ),
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

  Widget _buildDocumentsTab(ColorTheme themeColor) {
    if (_documentMessages.isEmpty) {
      return _buildEmptyState(
        Icons.description_outlined,
        'No documents shared',
        themeColor,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16 + kToolbarHeight + 56 + MediaQuery.of(context).padding.top, 16, 16),
      itemCount: _documentMessages.length,
      itemBuilder: (context, index) {
        final message = _documentMessages[index];
        return StaggeredSlideFadeItem(
          index: index,
          child: _buildDocumentItem(message, themeColor),
        );
      },
    );
  }

  Widget _buildDocumentItem(MessageModel message, ColorTheme themeColor) {
    final attachments = message.attachments;

    if (attachments == null) {
      return const SizedBox.shrink();
    }

    final documentUrl = attachments['url'] as String?;
    final fileName = attachments['file_name'] as String? ?? 'Document';
    final fileSize = attachments['file_size'] as int?;
    final mimeType = attachments['mime_type'] as String?;

    IconData docIcon = Icons.description_rounded;
    Color iconBgColor = themeColor.primary;
    if (mimeType != null) {
      if (mimeType.contains('pdf')) {
        docIcon = Icons.picture_as_pdf_rounded;
        iconBgColor = const Color(0xFFE53935);
      } else if (mimeType.contains('word') || mimeType.contains('doc')) {
        docIcon = Icons.description_rounded;
        iconBgColor = const Color(0xFF1976D2);
      } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
        docIcon = Icons.table_chart_rounded;
        iconBgColor = const Color(0xFF388E3C);
      } else if (mimeType.contains('powerpoint') ||
          mimeType.contains('presentation')) {
        docIcon = Icons.slideshow_rounded;
        iconBgColor = const Color(0xFFE64A19);
      } else if (mimeType.contains('zip') || mimeType.contains('rar')) {
        docIcon = Icons.archive_rounded;
        iconBgColor = const Color(0xFF7B1FA2);
      }
    }

    // Build metadata line: size · time
    final metaParts = <String>[];
    if (fileSize != null) {
      metaParts.add(ChatHelpers.formatFileSize(fileSize));
    }
    metaParts.add(ChatHelpers.formatMessageTime(message.sentAt));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: documentUrl != null
              ? () => _previewDocument(documentUrl, fileName, message.body, fileSize)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    docIcon,
                    color: iconBgColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        metaParts.join('  ·  '),
                        style: TextStyle(
                          color: Colors.grey[450],
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[350],
                ),
              ],
            ),
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

// ─── Animated Wrappers ──────────────────────────────────────────────────────

/// Shimmer loading skeleton tile
class _AnimatedSkeletonTile extends StatefulWidget {
  final int index;

  const _AnimatedSkeletonTile({required this.index});

  @override
  State<_AnimatedSkeletonTile> createState() => _AnimatedSkeletonTileState();
}

class _AnimatedSkeletonTileState extends State<_AnimatedSkeletonTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.4 + (_controller.value * 0.5);
        return Opacity(
          opacity: opacity,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }
}

// ─── Cached Grid Items (unchanged) ─────────────────────────────────────────

/// Optimized image grid item that keeps images alive when scrolling
class _CachedImageGridItem extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final VoidCallback? onTap;

  const _CachedImageGridItem({
    required this.imageUrl,
    required this.localPath,
    required this.onTap,
  });

  @override
  State<_CachedImageGridItem> createState() => _CachedImageGridItemState();
}

class _CachedImageGridItemState extends State<_CachedImageGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep widget alive when scrolling away

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.localPath != null && File(widget.localPath!).existsSync())
            Image.file(
              File(widget.localPath!),
              fit: BoxFit.cover,
              cacheWidth: 400, // Optimize memory by limiting decode size
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorPlaceholder();
              },
            )
          else if (widget.imageUrl != null)
            CachedNetworkImage(
              imageUrl: widget.imageUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 400, // Limit memory cache size for grid
              maxWidthDiskCache: 400, // Limit disk cache size
              // Reduce fade duration for instant appearance
              fadeInDuration: const Duration(milliseconds: 50),
              fadeOutDuration: const Duration(milliseconds: 50),
              // Use a minimal placeholder that doesn't flash
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
              ),
              errorWidget: (context, url, error) => _buildErrorPlaceholder(),
            )
          else
            _buildErrorPlaceholder(),
        ],
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
}

/// Optimized video grid item that keeps thumbnails alive when scrolling
class _CachedVideoGridItem extends StatefulWidget {
  final String? videoUrl;
  final String? localPath;
  final ThumbnailCacheService thumbnailCacheService;
  final VoidCallback? onTap;

  const _CachedVideoGridItem({
    required this.videoUrl,
    required this.localPath,
    required this.thumbnailCacheService,
    required this.onTap,
  });

  @override
  State<_CachedVideoGridItem> createState() => _CachedVideoGridItemState();
}

class _CachedVideoGridItemState extends State<_CachedVideoGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep widget alive when scrolling away

  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final videoPath = widget.localPath ?? widget.videoUrl;
    if (videoPath == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final thumbnailPath =
          await widget.thumbnailCacheService.getThumbnail(videoPath);

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading video thumbnail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          if (_thumbnailPath != null && File(_thumbnailPath!).existsSync())
            Image.file(
              File(_thumbnailPath!),
              fit: BoxFit.cover,
              cacheWidth: 400, // Optimize memory
              errorBuilder: (context, error, stackTrace) {
                return _buildVideoPlaceholder();
              },
            )
          else
            _buildVideoPlaceholder(),
          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            )
          : const Icon(
              Icons.videocam,
              color: Colors.white70,
              size: 32,
            ),
    );
  }
}
