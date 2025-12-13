import 'dart:io';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app-colors.config.dart';
import '../../utils/chat/preview-media.utils.dart';
import '../../db/repositories/message.repo.dart';
import '../../db/repositories/user.repo.dart';
import '../../providers/theme-color.provider.dart';

/// Configuration for MessageBubble widget
class MessageBubbleConfig {
  final MessageModel message;
  final bool isMyMessage;
  final bool isPinned;
  final bool isStarred;
  final bool isHighlighted;
  final String messageTime;
  final bool? shouldAnimate;
  final AnimationController? animationController;
  final Animation<double>? slideAnimation;
  final Animation<double>? fadeAnimation;
  final BuildContext context;

  // Callbacks for building child widgets
  final Widget Function(MessageModel message, bool isMyMessage)
  buildMessageContent;
  final Widget Function(MessageModel replyMessage, bool isMyMessage)?
  buildReplyPreview; // Optional, will use ReplyPreview widget if null
  final bool Function(MessageModel message) isMediaMessage;

  // ReplyPreview configuration (used if buildReplyPreview is null)
  final int? currentUserId;
  final int? conversationUserId; // For DM fallback logic
  final void Function(int messageId)? onReplyTap; // Scroll to message callback

  // Optional callbacks for DM-specific features
  final Widget Function(MessageModel message)? buildMessageStatusTicks;
  final void Function(MessageModel message)?
  onRetryFailedMessage; // Retry callback for failed messages

  // Configuration flags
  final bool isGroupChat; // true for group, false for DM
  final Color
  nonMyMessageBackgroundColor; // Colors.white for DM, Colors.grey[100] for group
  final bool useIntrinsicWidth; // true for DM, false for group
  final bool useStackContainer; // true for DM, false for group

  // Repositories for fetching reply data
  final MessageRepository? messagesRepo;
  final UserRepository? userRepo;

  MessageBubbleConfig({
    required this.message,
    required this.isMyMessage,
    required this.isPinned,
    required this.isStarred,
    required this.isHighlighted,
    required this.messageTime,
    this.shouldAnimate,
    this.animationController,
    this.slideAnimation,
    this.fadeAnimation,
    required this.context,
    required this.buildMessageContent,
    this.buildReplyPreview,
    required this.isMediaMessage,
    this.buildMessageStatusTicks,
    this.onRetryFailedMessage,
    required this.isGroupChat,
    required this.nonMyMessageBackgroundColor,
    required this.useIntrinsicWidth,
    required this.useStackContainer,
    this.currentUserId,
    this.conversationUserId,
    this.onReplyTap,
    this.messagesRepo,
    this.userRepo,
  });
}

/// Shared MessageBubble widget for both DM and group chats
class MessageBubble extends ConsumerWidget {
  final MessageBubbleConfig config;

  const MessageBubble({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    final isFailed = config.message.status == MessageStatusType.failed;
    final isUploading = config.message.metadata?['is_uploading'] == true;
    final showRetry = isFailed &&
        config.isMyMessage &&
        config.onRetryFailedMessage != null;

    Widget messageContent = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: config.isMyMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: config.isMyMessage ? 40 : 8,
                  right: config.isMyMessage ? 8 : 40,
                ),
                padding: config.isHighlighted
                    ? const EdgeInsets.all(10)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: config.isHighlighted
                      ? Colors.blue.withAlpha(100)
                      : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(config.isMyMessage ? 24 : 0),
                    bottomRight: Radius.circular(config.isMyMessage ? 0 : 24),
                  ),
                ),
                child: config.useStackContainer
                    ? _buildStackContainer(themeColor)
                    : _buildColumnContainer(themeColor),
              ),
            ),
            // Retry button on outer right side (like WhatsApp) - only for text messages
            if ((showRetry || (isUploading && config.isMyMessage)) &&
                !config.isMediaMessage(config.message)) ...[
              const SizedBox(width: 8),
              if (isUploading)
                _RotatingRefreshIcon(
                  size: 20,
                  color: config.isMyMessage
                      ? themeColor.primary
                      : Colors.grey[600] ?? Colors.grey,
                )
              else if (showRetry && config.onRetryFailedMessage != null)
                GestureDetector(
                  onTap: () => config.onRetryFailedMessage!(config.message),
                  child: Icon(
                    Icons.refresh,
                    size: 20,
                    color: config.isMyMessage
                        ? themeColor.primary
                        : Colors.grey[600] ?? Colors.grey,
                  ),
                )
              else if (showRetry)
                // Show disabled retry icon when automatic resend is in progress
                Icon(
                  Icons.refresh,
                  size: 20,
                  color: Colors.grey[400] ?? Colors.grey,
                ),
            ],
          ],
        ),
      ),
    );

    // Apply animation if available
    if (config.shouldAnimate != null &&
        config.slideAnimation != null &&
        config.fadeAnimation != null &&
        config.animationController != null) {
      return AnimatedBuilder(
        animation: config.animationController!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, config.slideAnimation!.value),
            child: Opacity(
              opacity: config.fadeAnimation!.value,
              child: messageContent,
            ),
          );
        },
      );
    }

    return messageContent;
  }

  /// Build container using Stack (for DM)
  Widget _buildStackContainer(ColorTheme themeColor) {
    return Stack(
      children: [
        // Check if this is a media message (image/video)
        config.isMediaMessage(config.message)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply message preview (if this is a reply)
                  if (config.message.isReply)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: config.isMyMessage
                            ? themeColor.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(0),
                          topRight: const Radius.circular(0),
                          bottomLeft: const Radius.circular(4),
                          bottomRight: const Radius.circular(4),
                        ),
                      ),
                      child: _buildReplyPreviewWithFetch(),
                    ),
                  // Media content without outer padding
                  config.buildMessageContent(
                    config.message,
                    config.isMyMessage,
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.only(
                  top: 5,
                  bottom: 2,
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: config.isMyMessage
                      ? themeColor.primary
                      : config.nonMyMessageBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
                    bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: config.useIntrinsicWidth
                    ? IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reply message preview (if this is a reply)
                            if (config.message.isReply)
                              _buildReplyPreviewWithFetch(),

                            // Message content (text, image, or video)
                            config.buildMessageContent(
                              config.message,
                              config.isMyMessage,
                            ),

                            // gap between content and time
                            const SizedBox(height: 1),
                            // Time and status row - aligned to right
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildTimeAndStatusRow(),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply message preview (if this is a reply)
                          if (config.message.isReply)
                            _buildReplyPreviewWithFetch(),

                          // Message content (text, image, or video)
                          config.buildMessageContent(
                            config.message,
                            config.isMyMessage,
                          ),

                          const SizedBox(height: 1),
                          // Time and status row
                          _buildTimeAndStatusRow(),
                        ],
                      ),
              ),
      ],
    );
  }

  /// Build container using Column (for Group)
  Widget _buildColumnContainer(ColorTheme themeColor) {
    return Column(
      crossAxisAlignment: config.isMyMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Check if this is a media message (image/video)
        config.isMediaMessage(config.message)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show sender name for group messages (non-my messages)
                  if (!config.isMyMessage) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        top: 8,
                        bottom: 4,
                      ),
                      child: Text(
                        config.message.senderName?.isNotEmpty ?? false
                            ? config.message.senderName ?? ''
                            : 'Unknown User',
                        style: TextStyle(
                          color: themeColor.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  // Reply message preview (if this is a reply)
                  if (config.message.isReply)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: config.isMyMessage
                            ? themeColor.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(0),
                          topRight: const Radius.circular(0),
                          bottomLeft: const Radius.circular(4),
                          bottomRight: const Radius.circular(4),
                        ),
                      ),
                      child: _buildReplyPreviewWithFetch(),
                    ),
                  // Media content without outer padding
                  config.buildMessageContent(
                    config.message,
                    config.isMyMessage,
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.only(
                  top: 5,
                  bottom: 2,
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: config.isMyMessage
                      ? themeColor.primary
                      : config.nonMyMessageBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(config.isMyMessage ? 14 : 0),
                    bottomRight: Radius.circular(config.isMyMessage ? 0 : 14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show sender name for group messages (non-my messages)
                    if (!config.isMyMessage) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Text(
                          config.message.senderName?.isNotEmpty ?? false
                              ? config.message.senderName ?? ''
                              : 'Unknown User',
                          style: TextStyle(
                            color: themeColor.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    // Reply message preview (if this is a reply)
                    if (config.message.isReply) _buildReplyPreviewWithFetch(),

                    // Message content (text, image, or video)
                    config.buildMessageContent(
                      config.message,
                      config.isMyMessage,
                    ),
                    const SizedBox(height: 1),
                    // Time and status row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _buildTimeAndStatusRowChildren(),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  /// Build time and status row (for DM with Align, for Group without)
  Widget _buildTimeAndStatusRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _buildTimeAndStatusRowChildren(),
    );
  }

  /// Build children for time and status row
  List<Widget> _buildTimeAndStatusRowChildren() {
    final isFailed = config.message.status == MessageStatusType.failed;
    // For text messages, retry button is shown outside the container
    // For media messages, they handle their own retry buttons

    return [
      if (config.isStarred) ...[
        Icon(
          Icons.star,
          size: 14,
          color: config.isMyMessage ? Colors.amber[600] : Colors.amber[600],
        ),
        const SizedBox(width: 4),
      ],
      Text(
        config.messageTime,
        style: TextStyle(
          color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      // Show delivery/read status ticks for own messages (DM only)
      // Don't show status ticks for failed messages
      if (config.isMyMessage &&
          !isFailed &&
          config.buildMessageStatusTicks != null) ...[
        const SizedBox(width: 4),
        config.buildMessageStatusTicks!(config.message),
      ],
    ];
  }

  /// Build reply preview widget using either callback or shared widget
  Widget _buildReplyPreviewWidget(MessageModel replyMessage, bool isMyMessage) {
    // Use custom callback if provided
    if (config.buildReplyPreview != null) {
      return config.buildReplyPreview!(replyMessage, isMyMessage);
    }

    // Use shared ReplyPreview widget
    if (config.onReplyTap != null) {
      return ReplyPreview(
        config: ReplyPreviewConfig(
          replyMessage: replyMessage,
          isMyMessage: isMyMessage,
          currentUserId: config.currentUserId,
          conversationUserId: config.conversationUserId,
          onTap: config.onReplyTap!,
          isGroupChat: config.isGroupChat,
          useFullWidth: !config.isGroupChat, // DM uses full width
          myMessageBackgroundColor: config.isGroupChat
              ? Colors.white.withAlpha(15)
              : Colors.white.withAlpha(20),
          otherMessageBackgroundColor: config.isGroupChat
              ? (Colors.grey[200] ?? Colors.grey.shade200)
              : (Colors.grey[100] ?? Colors.grey.shade100),
          myMessageTextColor: config.isGroupChat
              ? Colors.white
              : Colors.white.withOpacity(0.8),
          myMessageMediaColor: config.isGroupChat
              ? Colors.white.withAlpha(80)
              : Colors.white.withOpacity(0.8),
          mediaText: config.isGroupChat ? '📎 media' : '📎 media ',
        ),
      );
    }

    // Fallback if no callback provided
    return const SizedBox.shrink();
  }

  /// Build reply preview widget with async data fetching
  /// Uses a separate StatefulWidget to cache data and prevent re-fetching on rebuild
  Widget _buildReplyPreviewWithFetch() {
    // Use message ID as key to ensure widget identity is preserved
    return _ReplyPreviewWithFetch(
      key: ValueKey('reply_${config.message.id}'),
      message: config.message,
      isMyMessage: config.isMyMessage,
      messagesRepo: config.messagesRepo,
      userRepo: config.userRepo,
      buildReplyPreviewWidget: _buildReplyPreviewWidget,
      buildReplyPreview: config.buildReplyPreview,
      onReplyTap: config.onReplyTap,
      currentUserId: config.currentUserId,
      conversationUserId: config.conversationUserId,
      isGroupChat: config.isGroupChat,
    );
  }
}

/// Global static cache for reply data to persist across widget recreations
class _ReplyDataCache {
  static final Map<int, Map<String, dynamic>> _cache = {};

  static Map<String, dynamic>? get(int messageId) {
    return _cache[messageId];
  }

  static void set(int messageId, Map<String, dynamic> data) {
    _cache[messageId] = data;
  }
}

/// Separate StatefulWidget for reply preview that caches data to prevent flickering
class _ReplyPreviewWithFetch extends StatefulWidget {
  final MessageModel message;
  final bool isMyMessage;
  final MessageRepository? messagesRepo;
  final UserRepository? userRepo;
  final Widget Function(MessageModel replyMessage, bool isMyMessage)
  buildReplyPreviewWidget;
  final Widget Function(MessageModel replyMessage, bool isMyMessage)?
  buildReplyPreview;
  final void Function(int messageId)? onReplyTap;
  final int? currentUserId;
  final int? conversationUserId;
  final bool isGroupChat;

  const _ReplyPreviewWithFetch({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.messagesRepo,
    this.userRepo,
    required this.buildReplyPreviewWidget,
    this.buildReplyPreview,
    this.onReplyTap,
    this.currentUserId,
    this.conversationUserId,
    required this.isGroupChat,
  });

  @override
  State<_ReplyPreviewWithFetch> createState() => _ReplyPreviewWithFetchState();
}

class _ReplyPreviewWithFetchState extends State<_ReplyPreviewWithFetch>
    with AutomaticKeepAliveClientMixin {
  // Store the resolved reply data directly - no FutureBuilder
  MessageModel? _cachedReplyMessage;
  String? _cachedSenderName;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive to prevent re-fetching

  @override
  void initState() {
    super.initState();
    // Check global cache first
    final cachedData = _ReplyDataCache.get(widget.message.id);
    if (cachedData != null) {
      _cachedReplyMessage = cachedData['message'] as MessageModel?;
      _cachedSenderName = cachedData['senderName'] as String?;
    } else if (widget.message.isReply) {
      // Load reply data if not in cache
      _isLoading = true;
      _loadReplyData();
    }
  }

  @override
  void didUpdateWidget(_ReplyPreviewWithFetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-fetch if the message ID changed (new message)
    if (widget.message.id != oldWidget.message.id) {
      // Check global cache for new message
      final cachedData = _ReplyDataCache.get(widget.message.id);
      if (cachedData != null) {
        setState(() {
          _cachedReplyMessage = cachedData['message'] as MessageModel?;
          _cachedSenderName = cachedData['senderName'] as String?;
          _isLoading = false;
        });
      } else if (widget.message.isReply) {
        setState(() {
          _cachedReplyMessage = null;
          _cachedSenderName = null;
          _isLoading = true;
        });
        _loadReplyData();
      } else {
        setState(() {
          _cachedReplyMessage = null;
          _cachedSenderName = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReplyData() async {
    if (!widget.message.isReply || widget.message.metadata == null) {
      return;
    }

    final replyTo = widget.message.metadata!['reply_to'];
    if (replyTo == null || replyTo is! Map<String, dynamic>) {
      return;
    }

    final replyMessageId = replyTo['message_id'];
    final replySenderId = replyTo['sender_id'];

    if (replyMessageId == null || widget.messagesRepo == null) {
      return;
    }

    try {
      // Fetch the replied message
      final replyMessage = await widget.messagesRepo!.getMessageById(
        replyMessageId is int
            ? replyMessageId
            : int.tryParse(replyMessageId.toString()) ?? 0,
      );

      if (replyMessage == null) {
        return;
      }

      // Fetch sender name if sender_id is available
      String? senderName;
      if (replySenderId != null && widget.userRepo != null) {
        final senderId = replySenderId is int
            ? replySenderId
            : int.tryParse(replySenderId.toString());
        if (senderId != null) {
          final user = await widget.userRepo!.getUserById(senderId);
          senderName = user?.name;
        }
      }

      // Use sender name from reply_to metadata if available, otherwise use fetched name
      senderName = replyTo['sender_name'] as String? ?? senderName;

      // Store in global cache AND state - this persists across widget recreations
      final cacheData = {
        'message': replyMessage,
        'senderName': senderName ?? 'Unknown User',
      };
      _ReplyDataCache.set(widget.message.id, cacheData);

      // Store in state - this will trigger rebuild with actual data
      // Once stored, it will NEVER change unless message ID changes
      if (mounted) {
        setState(() {
          _cachedReplyMessage = replyMessage;
          _cachedSenderName = senderName ?? 'Unknown User';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Silently fail - don't show error, just don't show reply preview
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // If we have cached reply message, show it immediately - NO FLICKERING
    if (_cachedReplyMessage != null) {
      final replyMessageWithSender = _cachedReplyMessage!.copyWith(
        senderName: _cachedSenderName,
      );
      return widget.buildReplyPreviewWidget(
        replyMessageWithSender,
        widget.isMyMessage,
      );
    }

    // If still loading, show nothing (don't show empty/shrink if data will come)
    // This prevents flickering - once data is loaded, it will be cached and shown
    // Check global cache one more time in case it was set by another instance
    if (_isLoading) {
      final cachedData = _ReplyDataCache.get(widget.message.id);
      if (cachedData != null) {
        final replyMessage = cachedData['message'] as MessageModel?;
        final senderName = cachedData['senderName'] as String?;
        if (replyMessage != null) {
          // Update state from cache
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _cachedReplyMessage = replyMessage;
                _cachedSenderName = senderName;
                _isLoading = false;
              });
            }
          });
          // Return immediately with cached data
          final replyMessageWithSender = replyMessage.copyWith(
            senderName: senderName,
          );
          return widget.buildReplyPreviewWidget(
            replyMessageWithSender,
            widget.isMyMessage,
          );
        }
      }
    }

    return const SizedBox.shrink();
  }
}

/// Video thumbnail widget with caching support
///
/// Displays a video thumbnail with automatic generation and caching.
/// Shows a loading indicator while the thumbnail is being generated.
class VideoThumbnailWidget extends ConsumerStatefulWidget {
  final String videoUrl;
  final Map<String, String?> thumbnailCache;
  final Map<String, Future<String?>> thumbnailFutures;
  final VoidCallback onThumbnailGenerated;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    required this.thumbnailCache,
    required this.thumbnailFutures,
    required this.onThumbnailGenerated,
  });

  @override
  ConsumerState<VideoThumbnailWidget> createState() =>
      _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends ConsumerState<VideoThumbnailWidget> {
  @override
  void initState() {
    super.initState();
    // Trigger thumbnail generation if not already cached or generating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.thumbnailCache.containsKey(widget.videoUrl) &&
          !widget.thumbnailFutures.containsKey(widget.videoUrl)) {
        generateVideoThumbnailWithCache(
          widget.videoUrl,
          widget.thumbnailCache,
          widget.thumbnailFutures,
        ).then((_) {
          if (mounted) {
            widget.onThumbnailGenerated();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if we already have the thumbnail cached
    if (widget.thumbnailCache.containsKey(widget.videoUrl)) {
      final thumbnailPath = widget.thumbnailCache[widget.videoUrl];
      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        return Image.file(
          File(thumbnailPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.black87);
          },
        );
      } else {
        // Cached but path is null or file doesn't exist
        return Container(color: Colors.black87);
      }
    }

    // Show loading state while thumbnail is being generated
    final themeColor = ref.watch(themeColorProvider);
    return Container(
      color: Colors.black87,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(themeColor.primary),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

/// Configuration for ReplyPreview widget
class ReplyPreviewConfig {
  final MessageModel replyMessage;
  final bool isMyMessage;
  final int? currentUserId;
  final int? conversationUserId; // For DM fallback logic
  final void Function(int messageId) onTap; // Scroll to message callback
  final bool isGroupChat; // true for group, false for DM

  // Styling differences
  final bool useFullWidth; // true for DM, false for group
  final Color
  myMessageBackgroundColor; // Colors.white.withAlpha(20) for DM, Colors.white.withAlpha(15) for group
  final Color
  otherMessageBackgroundColor; // Colors.grey[100] for DM, Colors.grey[200] for group
  final Color
  myMessageTextColor; // Colors.white.withOpacity(0.8) for DM, Colors.white for group
  final Color
  myMessageMediaColor; // Colors.white.withOpacity(0.8) for DM, Colors.white.withAlpha(80) for group
  final String mediaText; // '📎 media ' for DM, '📎 media' for group

  ReplyPreviewConfig({
    required this.replyMessage,
    required this.isMyMessage,
    this.currentUserId,
    this.conversationUserId,
    required this.onTap,
    required this.isGroupChat,
    required this.useFullWidth,
    required this.myMessageBackgroundColor,
    required this.otherMessageBackgroundColor,
    required this.myMessageTextColor,
    required this.myMessageMediaColor,
    required this.mediaText,
  });
}

/// Shared ReplyPreview widget for both DM and group chats
class ReplyPreview extends ConsumerWidget {
  final ReplyPreviewConfig config;

  const ReplyPreview({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    // Determine if the replied-to message is from current user
    final isRepliedMessageMine = config.isGroupChat
        ? (config.currentUserId != null &&
              config.replyMessage.senderId == config.currentUserId)
        : (config.currentUserId != null
              ? config.replyMessage.senderId == config.currentUserId
              : (config.conversationUserId != null &&
                    config.replyMessage.senderId != config.conversationUserId));

    return GestureDetector(
      onTap: () => config.onTap(config.replyMessage.id),
      child: Container(
        width: config.useFullWidth ? double.infinity : null,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: config.isMyMessage
              ? config.myMessageBackgroundColor
              : config.otherMessageBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: config.isMyMessage ? Colors.white : themeColor.primary,
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRepliedMessageMine
                  ? 'You'
                  : (config.replyMessage.senderName ?? 'Unknown User'),
              style: TextStyle(
                color: config.isMyMessage ? Colors.white : themeColor.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            if (config.replyMessage.body?.isNotEmpty ?? false) ...[
              Text(
                (config.replyMessage.body?.length ?? 0) > 50
                    ? '${config.replyMessage.body?.substring(0, 50)}...'
                    : (config.replyMessage.body ?? ''),
                style: TextStyle(
                  color: config.isMyMessage
                      ? config.myMessageTextColor
                      : (Colors.grey[600] ?? Colors.grey.shade600),
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                config.mediaText,
                style: TextStyle(
                  color: config.isMyMessage
                      ? config.myMessageMediaColor
                      : (Colors.grey[600] ?? Colors.grey.shade600),
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rotating refresh icon widget for showing upload progress
class _RotatingRefreshIcon extends StatefulWidget {
  final double size;
  final Color color;

  const _RotatingRefreshIcon({required this.size, required this.color});

  @override
  State<_RotatingRefreshIcon> createState() => _RotatingRefreshIconState();
}

class _RotatingRefreshIconState extends State<_RotatingRefreshIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh, size: widget.size, color: widget.color),
    );
  }
}
