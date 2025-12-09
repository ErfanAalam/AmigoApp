import 'dart:async';
import 'dart:io';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/utils/snowflake.util.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../api/chat.api-client.dart';
import '../../db/repositories/conversation-member.repo.dart';
import '../../db/repositories/message-status.repo.dart';
import '../../models/group.model.dart';
import '../../models/user.model.dart';
import '../../providers/chat.provider.dart';
import '../../services/socket/websocket.service.dart';
import '../../types/socket.types.dart';

/// Unified model for displaying conversations (both DMs and Groups)
class ShareableConversation {
  final int id;
  final String displayName;
  final String? displayAvatar;
  final bool isGroup;
  final String? lastMessageBody;
  final String? lastMessageType;
  final String? lastMessageAt;
  final int? unreadCount;

  ShareableConversation({
    required this.id,
    required this.displayName,
    this.displayAvatar,
    required this.isGroup,
    this.lastMessageBody,
    this.lastMessageType,
    this.lastMessageAt,
    this.unreadCount,
  });

  factory ShareableConversation.fromDm(DmModel dm) {
    return ShareableConversation(
      id: dm.conversationId,
      displayName: dm.recipientName,
      displayAvatar: dm.recipientProfilePic,
      isGroup: false,
      lastMessageBody: dm.lastMessageBody,
      lastMessageType: dm.lastMessageType,
      lastMessageAt: dm.lastMessageAt,
      unreadCount: dm.unreadCount,
    );
  }

  factory ShareableConversation.fromGroup(GroupModel group) {
    return ShareableConversation(
      id: group.conversationId,
      displayName: group.title,
      displayAvatar: null, // Groups don't have avatars in this model
      isGroup: true,
      lastMessageBody: group.lastMessageBody,
      lastMessageType: group.lastMessageType,
      lastMessageAt: group.lastMessageAt,
      unreadCount: group.unreadCount,
    );
  }
}

/// A screen that handles incoming shared media (images and videos)
/// from the Android share sheet and allows selecting conversations to share to.
class ShareHandlerScreen extends ConsumerStatefulWidget {
  final List<SharedMediaFile>? initialFiles;

  const ShareHandlerScreen({super.key, this.initialFiles});

  @override
  ConsumerState<ShareHandlerScreen> createState() => _ShareHandlerScreenState();
}

class _ShareHandlerScreenState extends ConsumerState<ShareHandlerScreen>
    with SingleTickerProviderStateMixin {
  // List to store shared media files
  List<SharedMediaFile> _sharedFiles = [];

  // Subscriptions for receiving shared intents
  StreamSubscription? _intentDataStreamSubscription;

  // Conversations lists - separate for DMs and Groups
  List<ShareableConversation> _availableDms = [];
  List<ShareableConversation> _availableGroups = [];
  List<ShareableConversation> _filteredDms = [];
  List<ShareableConversation> _filteredGroups = [];
  bool _isLoadingConversations = false;

  // Tab controller
  late TabController _tabController;

  // Selected conversations to send media to
  final Set<int> _selectedConversations = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Current user details
  UserModel? _currentUserDetails;

  // Services
  final ChatsServices _chatsServices = ChatsServices();
  final WebSocketService _webSocket = WebSocketService();

  // Repositories
  final MessageRepository _messageRepo = MessageRepository();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();

  // Utils
  final UserUtils _userUtils = UserUtils();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeSharing();
    _loadAvailableConversations();
    _searchController.addListener(_onSearchChanged);
  }

  /// Initialize sharing intent listeners
  void _initializeSharing() {
    // If files were passed from main.dart, use them
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      setState(() {
        _sharedFiles = widget.initialFiles!;
      });
      return;
    }

    // Otherwise, try to get them from the intent (for when app is running)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              setState(() {
                _sharedFiles = value;
              });
            }
          },
          onError: (err) {
            debugPrint("Error receiving shared files: $err");
          },
        );

    // For sharing when the app is opened from the share sheet (app was closed)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        setState(() {
          _sharedFiles = value;
        });
      }
    });
  }

  /// Load available conversations (both DMs and groups)
  Future<void> _loadAvailableConversations() async {
    setState(() {
      _isLoadingConversations = true;
    });

    final userDetails = await _userUtils.getUserDetails();
    if (userDetails != null) {
      setState(() {
        _currentUserDetails = userDetails;
      });
    }

    try {
      // Load from local database for instant display
      try {
        final dmList = await ConversationRepository()
            .getAllDmsWithRecipientInfo();
        final groupList = await ConversationRepository()
            .getGroupListWithoutMembers();

        final localDms = dmList
            .map((dm) => ShareableConversation.fromDm(dm))
            .toList();
        final localGroups = groupList
            .map((group) => ShareableConversation.fromGroup(group))
            .toList();

        if (mounted) {
          setState(() {
            _availableDms = localDms;
            _availableGroups = localGroups;
            _filterDms();
            _filterGroups();
          });
        }
      } catch (localError) {
        debugPrint('⚠️ Error loading from local DB: $localError');
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      // If API fails and we don't have local conversations, show helpful message
      if (mounted && _availableDms.isEmpty && _availableGroups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load chats. Please check your connection.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadAvailableConversations,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
        });
      }
    }
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _filterDms();
        _filterGroups();
      });
    }
  }

  /// Filter DMs based on search query
  void _filterDms() {
    if (_searchQuery.isEmpty) {
      _filteredDms = List.from(_availableDms);
    } else {
      _filteredDms = _availableDms.where((conversation) {
        return conversation.displayName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  /// Filter Groups based on search query
  void _filterGroups() {
    if (_searchQuery.isEmpty) {
      _filteredGroups = List.from(_availableGroups);
    } else {
      _filteredGroups = _availableGroups.where((conversation) {
        return conversation.displayName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  /// Toggle conversation selection
  void _toggleConversationSelection(int conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  /// Send shared media to selected conversations
  Future<void> _sendToSelectedConversations() async {
    if (_selectedConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one chat'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sharedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files to share'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 16),
                Text('Sending ${_sharedFiles.length} file(s)...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      int successCount = 0;
      int failCount = 0;

      // Send each file to selected conversations
      for (final file in _sharedFiles) {
        try {
          // Upload the file first
          final fileToUpload = File(file.path);
          final uploadResponse = await _chatsServices.sendMediaMessage(
            fileToUpload,
          );

          final optimisticMessageId = Snowflake.generateNegative();

          if (uploadResponse['success'] == true &&
              uploadResponse['data'] != null) {
            final mediaData = uploadResponse['data'];

            // Send to each selected conversation via WebSocket
            for (final conversationId in _selectedConversations) {
              final newMsg = MessageModel(
                optimisticId: optimisticMessageId,
                conversationId: conversationId,
                senderId: _currentUserDetails!.id,
                senderName: _currentUserDetails!.name,
                senderProfilePic: _currentUserDetails!.profilePic,
                metadata: {},
                attachments: mediaData,
                type: file.type == SharedMediaType.image
                    ? MessageType.image
                    : MessageType.video,
                body: '',
                isReplied: false,
                status: MessageStatusType.sent,
                sentAt: DateTime.now().toUtc().toIso8601String(),
              );

              // storing the message into the local database
              await _messageRepo.insertMessage(newMsg);

              // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

              final messagePayload = ChatMessagePayload(
                optimisticId: optimisticMessageId,
                convId: conversationId,
                senderId: _currentUserDetails!.id,
                senderName: _currentUserDetails!.name,
                attachments: mediaData,
                convType: conversationId is GroupModel
                    ? ChatType.group
                    : ChatType.dm,
                msgType: file.type == SharedMediaType.image
                    ? MessageType.image
                    : MessageType.video,
                body: '',
                replyToMessageId: null,
                sentAt: DateTime.now().toUtc(),
              );

              final wsmsg = WSMessage(
                type: WSMessageType.messageNew,
                payload: messagePayload,
                wsTimestamp: DateTime.now(),
              ).toJson();

              await _webSocket.sendMessage(wsmsg).catchError((e) async {
                debugPrint('Error sending message: $e');
                // Mark message as failed in DB and UI
              });

              // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

              ref
                  .read(chatProvider.notifier)
                  .updateLastMessageOnSendingOwnMessage(conversationId, newMsg);

              final List<ConversationMemberModel> conversationMembers =
                  await ConversationMemberRepository()
                      .getMembersByConversationId(conversationId);
              final List<int> userIds = conversationMembers
                  .map((member) => member.userId)
                  .toList();

              // // store that message in the message status table
              await _messageStatusRepo.insertMessageStatusesWithMultipleUserIds(
                messageId: newMsg.id,
                conversationId: conversationId,
                userIds: userIds,
              );
            }

            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          debugPrint('❌ Error sending file: $e');
          failCount++;
        }
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent $successCount file(s) to ${_selectedConversations.length} chat(s)' +
                  (failCount > 0 ? ' ($failCount failed)' : ''),
            ),
            backgroundColor: successCount > 0 ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear and go back if successful
        if (successCount > 0) {
          // Reset the intent to prevent re-sharing
          ReceiveSharingIntent.instance.reset();
          // Go back to previous screen
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send files'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Media'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'DMs'),
            Tab(icon: Icon(Icons.group), text: 'Groups'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Shared Files Header
          _buildSharedFilesHeader(),

          // Search Bar
          _buildSearchBar(),

          // Conversations List with Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConversationsList(isDm: true),
                _buildConversationsList(isDm: false),
              ],
            ),
          ),

          // Send Button
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildSharedFilesHeader() {
    if (_sharedFiles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.red[50],
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No files received. Please try sharing again.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[900],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.teal[50],
      child: Row(
        children: [
          Icon(Icons.share, color: Colors.teal[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sharedFiles.length} file(s) to share',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _sharedFiles.map((f) => f.path.split('/').last).join(', '),
                  style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Show file types
          Row(
            children: [
              if (_sharedFiles.any((f) => f.type == SharedMediaType.image))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, size: 20, color: Colors.blue[700]),
                ),
              const SizedBox(width: 4),
              if (_sharedFiles.any((f) => f.type == SharedMediaType.video))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.videocam,
                    size: 20,
                    color: Colors.purple[700],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search chats...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList({required bool isDm}) {
    final conversations = isDm ? _filteredDms : _filteredGroups;

    if (_isLoadingConversations) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text('Loading chats...'),
            ],
          ),
        ),
      );
    }

    if (conversations.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isEmpty
                    ? (isDm ? Icons.person_outline : Icons.group_outlined)
                    : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? (isDm ? 'No DMs available' : 'No groups available')
                    : 'No ${isDm ? 'DMs' : 'groups'} found for "$_searchQuery"',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final isSelected = _selectedConversations.contains(conversation.id);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.teal.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.teal.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: ListTile(
              onTap: () => _toggleConversationSelection(conversation.id),
              leading: _buildConversationAvatar(conversation),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.displayName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 16,
                        color: isSelected ? Colors.teal[700] : Colors.black87,
                      ),
                    ),
                  ),
                  if (!isDm && conversation.isGroup)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange[300]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'GROUP',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: conversation.lastMessageBody != null
                  ? Text(
                      conversation.lastMessageBody!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.teal : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.teal : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationAvatar(ShareableConversation conversation) {
    if (conversation.isGroup) {
      // Group conversation - show group icon
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.orange[100],
        child: Icon(Icons.group, color: Colors.orange[700], size: 28),
      );
    } else {
      // DM conversation - show user avatar or initials
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.teal[100],
        backgroundImage: conversation.displayAvatar != null
            ? CachedNetworkImageProvider(conversation.displayAvatar!)
            : null,
        child: conversation.displayAvatar == null
            ? Text(
                _getInitials(conversation.displayName),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
      );
    }
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildSendButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected count indicator
            if (_selectedConversations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_selectedConversations.length} chat(s) selected',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedConversations.isEmpty
                    ? null
                    : _sendToSelectedConversations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send, size: 20),
                label: Text(
                  _selectedConversations.isEmpty
                      ? 'Select chats to send'
                      : 'Send to ${_selectedConversations.length} chat(s)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
