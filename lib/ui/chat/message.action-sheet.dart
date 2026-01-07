import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable message action sheet widget
class MessageActionSheet extends StatelessWidget {
  final MessageModel message;
  final bool isMyMessage;
  final bool isPinned;
  final bool isAdmin;
  final bool isStarred;
  final bool showReadBy;
  final VoidCallback onReply;
  // final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onStar;
  final VoidCallback onForward;
  final VoidCallback onSelect;
  final VoidCallback? onReadBy;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  const MessageActionSheet({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.isPinned,
    required this.isStarred,
    this.isAdmin = false,
    this.showReadBy = false,
    required this.onReply,
    required this.onPin,
    required this.onStar,
    required this.onForward,
    required this.onSelect,
    this.onReadBy,
    this.onDelete,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.audiotrack;
      case MessageType.document:
        return Icons.insert_drive_file;
      case MessageType.attachment:
        return Icons.attach_file;
      case MessageType.reply:
        return Icons.reply;
      case MessageType.forwarded:
        return Icons.forward;
      case MessageType.reaction:
        return Icons.emoji_emotions;
      case MessageType.system:
        return Icons.info;
      case MessageType.text:
        return Icons.message;
    }
  }

  String _getMessageTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.document:
        return 'Document';
      case MessageType.attachment:
        return 'Attachment';
      case MessageType.reply:
        return 'Reply';
      case MessageType.forwarded:
        return 'Forwarded';
      case MessageType.reaction:
        return 'Reaction';
      case MessageType.system:
        return 'System message';
      case MessageType.text:
        return 'Text message';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Message preview
              Container(
                constraints: const BoxConstraints(maxHeight: 62),
                margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    if (message.body != null &&
                        message.body!.trim().isNotEmpty) ...[
                      Icon(Icons.message, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message.body!.length > 50
                              ? '${message.body!.substring(0, 50)}...'
                              : message.body!,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    if (message.body == null ||
                        message.body!.trim().isEmpty) ...[
                      Icon(
                        _getMessageTypeIcon(message.type),
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getMessageTypeLabel(message.type),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action buttons
              Column(
                children: [
                  MessageActionButton(
                    icon: Icons.reply,
                    label: 'Reply',
                    onTap: () {
                      Navigator.pop(context);
                      onReply();
                    },
                  ),
                  MessageActionButton(
                    icon: Icons.copy,
                    label: 'Copy',
                    onTap: () async {
                      Navigator.pop(context);
                      // onCopy();
                      await Clipboard.setData(
                        ClipboardData(text: message.body!),
                      );
                    },
                  ),
                  MessageActionButton(
                    icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    label: isPinned ? 'Unpin' : 'Pin',
                    onTap: () {
                      Navigator.pop(context);
                      onPin();
                    },
                  ),
                  MessageActionButton(
                    icon: isStarred ? Icons.star : Icons.star_border,
                    label: isStarred ? 'Unstar' : 'Star',
                    onTap: () {
                      Navigator.pop(context);
                      onStar();
                    },
                  ),
                  MessageActionButton(
                    icon: Icons.forward,
                    label: 'Forward',
                    onTap: () {
                      Navigator.pop(context);
                      onForward();
                    },
                  ),
                  MessageActionButton(
                    icon: Icons.select_all,
                    label: 'Select',
                    onTap: () {
                      Navigator.pop(context);
                      onSelect();
                    },
                  ),
                  if (showReadBy && onReadBy != null)
                    MessageActionButton(
                      icon: Icons.mark_chat_read_rounded,
                      label: 'ReadBy',
                      onTap: () {
                        Navigator.pop(context);
                        onReadBy!();
                      },
                    ),
                  // Delete options - show different options based on context
                  if (onDeleteForMe != null || onDeleteForEveryone != null || (isAdmin && onDelete != null))
                    _buildDeleteOptions(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteOptions(BuildContext context) {
    // If both delete options are available, show a delete button that opens a dialog
    if (onDeleteForMe != null && onDeleteForEveryone != null) {
      return MessageActionButton(
        icon: Icons.delete_outline,
        label: 'Delete',
        color: Colors.red,
        onTap: () {
          Navigator.pop(context);
          _showDeleteOptionsDialog(context);
        },
      );
    }
    
    // If only delete for me is available
    if (onDeleteForMe != null) {
      return MessageActionButton(
        icon: Icons.delete_outline,
        label: 'Delete',
        color: Colors.red,
        onTap: () {
          Navigator.pop(context);
          onDeleteForMe!();
        },
      );
    }
    
    // If only delete for everyone is available
    if (onDeleteForEveryone != null) {
      return MessageActionButton(
        icon: Icons.delete_outline,
        label: 'Delete for everyone',
        color: Colors.red,
        onTap: () {
          Navigator.pop(context);
          onDeleteForEveryone!();
        },
      );
    }
    
    // Admin delete (for groups)
    if (isAdmin && onDelete != null) {
      return MessageActionButton(
        icon: Icons.delete_outline,
        label: 'Delete',
        color: Colors.red,
        onTap: () {
          Navigator.pop(context);
          onDelete!();
        },
      );
    }
    
    return const SizedBox.shrink();
  }

  void _showDeleteOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('How would you like to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDeleteForMe?.call();
              },
              child: const Text('Delete for me'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDeleteForEveryone?.call();
              },
              child: const Text('Delete for everyone'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

/// Reusable action button widget
class MessageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const MessageActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0x02404040),
          borderRadius: BorderRadius.all(Radius.circular(10)),
          border: Border.fromBorderSide(
            BorderSide(width: 0.5, color: Color.fromARGB(20, 64, 64, 64)),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.grey[700], size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
