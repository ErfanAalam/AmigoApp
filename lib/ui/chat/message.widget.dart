import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:amigo/ui/chat/emoji-reaction.widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app-colors.config.dart';
import '../../db/repositories/message.repo.dart';
import '../../db/repositories/user.repo.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/thumbnail-cache.service.dart';

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
  final String? currentUserId;
  final String? conversationUserId; // For DM fallback logic
  final void Function(String messageId)?
  onReplyTap; // Scroll to message callback

  // Optional callbacks for DM-specific features
  final Widget Function(MessageModel message)? buildMessageStatusTicks;
  final void Function(MessageModel message)?
  onRetryFailedMessage; // Retry callback for failed messages
  final bool
  isResendingMessage; // Whether this message is currently being resent
  final void Function(String messageId)? onResendFailedMessage;
  final void Function(String messageId)? onDeleteFailedMessage;

  // Configuration flags
  final bool isGroupChat; // true for group, false for DM
  final Color
  nonMyMessageBackgroundColor; // Colors.white for DM, Colors.grey[100] for group
  final bool useIntrinsicWidth; // true for DM, false for group
  final bool useStackContainer; // true for DM, false for group

  // Repositories for fetching reply data
  final MessageRepository? messagesRepo;
  final UserRepository? userRepo;

  // Reaction callbacks
  final void Function(String emoji)? onReact;
  final void Function(Map<String, dynamic> reactions)? onShowReactionUsers;
  final Map<String, dynamic> reactions;

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
    this.isResendingMessage = false,
    this.onResendFailedMessage,
    this.onDeleteFailedMessage,
    required this.isGroupChat,
    required this.nonMyMessageBackgroundColor,
    required this.useIntrinsicWidth,
    required this.useStackContainer,
    this.currentUserId,
    this.conversationUserId,
    this.onReplyTap,
    this.messagesRepo,
    this.userRepo,
    this.onReact,
    this.onShowReactionUsers,
    this.reactions = const {},
  });
}

/// Show failed message options dialog
void _showFailedMessageDialog(
  BuildContext context, {
  required void Function()? onResend,
  required void Function()? onDelete,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (BuildContext dialogContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Message Failed',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: const Text('What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onResend?.call();
              },
              child: const Text('Resend'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDelete?.call();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    },
  );
}

/// Shared MessageBubble widget for both DM and group chats
class MessageBubble extends ConsumerWidget {
  final MessageBubbleConfig config;

  const MessageBubble({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);

    Widget messageContent = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: config.isMyMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: config.isMyMessage ? 40 : 0,
                  right: config.isMyMessage ? 0 : 40,
                ),
                child: config.useStackContainer
                    ? _buildStackContainer(themeColor)
                    : _buildColumnContainer(themeColor),
              ),
            ),
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

  /// Build the emoji reaction row (shown below the bubble)
  Widget _buildReactionRow() {
    final reactions = config.reactions;
    if (reactions.isEmpty) return const SizedBox.shrink();
    debugPrint('[ReactionRow] Rendering for msg=${config.message.id} isMyMsg=${config.isMyMessage} emojis=${reactions.keys.toList()}');
    return Transform.translate(
      offset: const Offset(0, -5),
      child: Padding(
        padding: EdgeInsets.only(
          left: config.isMyMessage ? 0 : 2,
          right: config.isMyMessage ? 2 : 0,
        ),
        child: MessageReactionRow(
          reactions: reactions,
          onTap: () => config.onShowReactionUsers?.call(reactions),
        ),
      ),
    );
  }

  /// Build container using Stack (for DM)
  Widget _buildStackContainer(ColorTheme themeColor) {
    final bubbleContent = Stack(
      children: [
        // Check if this is a media message (image/video)
        config.isMediaMessage(config.message)
            ? IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: config.message.isReply
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.end,
                  children: [
                    // Reply message preview (if this is a reply)
                    if (config.message.isReply)
                      Transform.translate(
                        offset: const Offset(0, 12),
                        child: Container(
                          padding: const EdgeInsets.only(
                            top: 5,
                            left: 8,
                            right: 8,
                            bottom: 10,
                          ),
                          decoration: BoxDecoration(
                            color: config.isMyMessage
                                ? themeColor.primary
                                : Colors.grey[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: _buildReplyPreviewWithFetch(),
                        ),
                      ),
                    // Media content without outer padding
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: config.message.isReply
                            ? Radius.zero
                            : const Radius.circular(14),
                        topRight: config.message.isReply
                            ? Radius.zero
                            : const Radius.circular(14),
                        bottomLeft: Radius.circular(
                          config.isMyMessage ? 14 : 0,
                        ),
                        bottomRight: Radius.circular(
                          config.isMyMessage ? 0 : 14,
                        ),
                      ),
                      child: config.buildMessageContent(
                        config.message,
                        config.isMyMessage,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                constraints: config.message.isReply
                    ? const BoxConstraints(minWidth: 146)
                    : const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.only(
                  top: 7,
                  bottom: 4,
                  left: 9,
                  right: 8,
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
                            // const SizedBox(height: 1),
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

    return Column(
      crossAxisAlignment: config.isMyMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [bubbleContent, _buildReactionRow()],
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
                constraints: config.message.isReply
                    ? const BoxConstraints(minWidth: 160)
                    : const BoxConstraints(minWidth: 100),
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
                    // if (!config.isMyMessage) ...[
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: 4, bottom: 2),
                    //     child: Text(
                    //       config.message.senderName?.isNotEmpty ?? false
                    //           ? config.message.senderName ?? ''
                    //           : 'Unknown User',
                    //       style: TextStyle(
                    //         color: themeColor.primary,
                    //         fontSize: 12,
                    //         fontWeight: FontWeight.w700,
                    //       ),
                    //     ),
                    //   ),
                    // ],
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
        // Reactions row below the bubble
        _buildReactionRow(),
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
    final isFailed = config.message.isFailed;
    final isMyMessage = config.isMyMessage;

    return [
      if (config.isStarred) ...[
        Icon(
          Icons.star,
          size: 14,
          color: config.isMyMessage ? Colors.amber[600] : Colors.amber[600],
        ),
        const SizedBox(width: 4),
      ],
      if (isFailed && isMyMessage)
        Builder(
          builder: (context) => GestureDetector(
            onTap: () {
              _showFailedMessageDialog(
                context,
                onResend: config.onResendFailedMessage != null
                    ? () => config.onResendFailedMessage!(config.message.id)
                    : null,
                onDelete: config.onDeleteFailedMessage != null
                    ? () => config.onDeleteFailedMessage!(config.message.id)
                    : null,
              );
            },
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Colors.red,
            ),
          ),
        )
      else ...[
        Text(
          config.messageTime.toLowerCase(),
          style: TextStyle(
            color: config.isMyMessage ? Colors.white70 : Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
        // Show delivery/read status ticks for own messages (DM only)
        // Don't show status ticks for failed messages
        if (config.isMyMessage && config.buildMessageStatusTicks != null) ...[
          const SizedBox(width: 4),
          config.buildMessageStatusTicks!(config.message),
        ],
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
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Map<String, dynamic>? get(String messageId) {
    return _cache[messageId];
  }

  static void set(String messageId, Map<String, dynamic> data) {
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
  final void Function(String messageId)? onReplyTap;
  final String? currentUserId;
  final String? conversationUserId;
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
    final replyMessageId = widget.message.repliedTo;
    if (replyMessageId == null ||
        replyMessageId.isEmpty ||
        widget.messagesRepo == null) {
      return;
    }

    try {
      // Fetch the replied message
      final replyMessage = await widget.messagesRepo!.getMessageById(
        replyMessageId,
      );

      // Fetch sender name from users table if we have the reply message
      String? senderName;
      if (replyMessage != null &&
          replyMessage.senderId != null &&
          widget.userRepo != null) {
        final user = await widget.userRepo!.getUserById(replyMessage.senderId!);
        senderName = user?.displayName ?? user?.name;
      }
      senderName ??= replyMessage?.senderName;

      // If the replied message isn't in the local DB yet, keep it null so the
      // reply preview simply won't render.
      final effectiveReplyMessage = replyMessage;
      if (effectiveReplyMessage == null) {
        return;
      }

      // Store in global cache AND state - this persists across widget recreations
      final cacheData = {
        'message': effectiveReplyMessage,
        'senderName': senderName ?? 'Unknown User',
      };
      _ReplyDataCache.set(widget.message.id, cacheData);

      // Store in state - this will trigger rebuild with actual data
      // Once stored, it will NEVER change unless message ID changes
      if (mounted) {
        setState(() {
          _cachedReplyMessage = effectiveReplyMessage;
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
  final ThumbnailCacheService _thumbnailCache = ThumbnailCacheService();
  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      // Use persistent cache service
      final thumbnailPath = await _thumbnailCache.getThumbnail(widget.videoUrl);

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });

        // Update the old cache for backwards compatibility
        widget.thumbnailCache[widget.videoUrl] = thumbnailPath;
        widget.onThumbnailGenerated();
      }
    } catch (e) {
      debugPrint('❌ Error loading thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show thumbnail if available
    if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) {
      return Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black87,
            child: const Icon(Icons.videocam, color: Colors.white70, size: 32),
          );
        },
      );
    }

    // Show loading state while thumbnail is being generated
    if (_isLoading) {
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

    // Show placeholder if thumbnail generation failed
    return Container(
      color: Colors.black87,
      child: const Icon(Icons.videocam, color: Colors.white70, size: 32),
    );
  }
}

/// Configuration for ReplyPreview widget
class ReplyPreviewConfig {
  final MessageModel replyMessage;
  final bool isMyMessage;
  final String? currentUserId;
  final String? conversationUserId; // For DM fallback logic
  final void Function(String messageId) onTap; // Scroll to message callback
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
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: config.isMyMessage
              ? config.myMessageBackgroundColor
              : config.otherMessageBackgroundColor,
          borderRadius: BorderRadius.circular(12),
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
