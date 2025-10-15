import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/conversation_model.dart';
import '../api/user.service.dart';
import '../api/chats.services.dart';
import '../services/websocket_service.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/groups_repository.dart';

/// A screen that handles incoming shared media (images and videos)
/// from the Android share sheet and allows selecting conversations to share to.
class ShareHandlerScreen extends StatefulWidget {
  final List<SharedMediaFile>? initialFiles;

  const ShareHandlerScreen({super.key, this.initialFiles});

  @override
  State<ShareHandlerScreen> createState() => _ShareHandlerScreenState();
}

class _ShareHandlerScreenState extends State<ShareHandlerScreen> {
  // List to store shared media files
  List<SharedMediaFile> _sharedFiles = [];

  // Subscriptions for receiving shared intents
  StreamSubscription? _intentDataStreamSubscription;

  // Conversations list
  List<ConversationModel> _availableConversations = [];
  List<ConversationModel> _filteredConversations = [];
  bool _isLoadingConversations = false;

  // Selected conversations to send media to
  final Set<int> _selectedConversations = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Services
  final UserService _userService = UserService();
  final ChatsServices _chatsServices = ChatsServices();
  final WebSocketService _websocketService = WebSocketService();
  final ConversationsRepository _conversationsRepo = ConversationsRepository();
  final GroupsRepository _groupsRepo = GroupsRepository();
  @override
  void initState() {
    super.initState();
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
      debugPrint(
        "Shared files received from main.dart: ${_sharedFiles.length} files",
      );
      debugPrint("Files: ${_sharedFiles.map((f) => f.path).join(", ")}");
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

              debugPrint(
                "Shared files received while running: ${value.map((f) => f.path).join(", ")}",
              );
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

        debugPrint(
          "Shared files received on app start: ${value.map((f) => f.path).join(", ")}",
        );
      }
    });
  }

  /// Load available conversations (both DMs and groups)
  Future<void> _loadAvailableConversations() async {
    setState(() {
      _isLoadingConversations = true;
    });

    try {
      // FIRST: Try to load from local database for instant display
      debugPrint('🔍 Share Handler - Loading from local DB first...');
      try {
        final chatConversations = await _conversationsRepo
            .getAllConversations();

        print('chatConversations');
        print(chatConversations);

        final groupConversations = await _groupsRepo.getAllGroups();

        print('groupConversations');
        print(groupConversations);

        final localConversations = [
          ...chatConversations,
          ...groupConversations,
        ];

        print('localConversations');
        print(localConversations);

        if (localConversations.isNotEmpty) {
          debugPrint(
            '✅ Share Handler - Loaded ${localConversations.length} conversations from local DB',
          );
          if (mounted) {
            setState(() {
              _availableConversations =
                  localConversations as List<ConversationModel>;
              _filteredConversations = localConversations;
            });
          }
        } else {
          debugPrint('ℹ️ Share Handler - No conversations in local DB');
        }
      } catch (localError) {
        debugPrint('⚠️ Error loading from local DB: $localError');
      }

      // SECOND: Load from API to get latest data
      debugPrint('🔍 Share Handler - Requesting conversations from API...');
      final response = await _userService.GetChatList('all');
      debugPrint('🔍 Share Handler - API response success: ${response}');

      if (response['success'] == true && response['data'] != null) {
        final dynamic responseData = response['data'];
        debugPrint(
          '🔍 Share Handler - responseData type: ${responseData.runtimeType}',
        );

        List<dynamic> conversationsList = [];

        if (responseData is List) {
          conversationsList = responseData;
          debugPrint(
            '🔍 Share Handler - Direct list, length: ${conversationsList.length}',
          );
        } else if (responseData is Map<String, dynamic>) {
          debugPrint(
            '🔍 Share Handler - Map response, keys: ${responseData.keys}',
          );

          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            conversationsList = responseData['data'] as List<dynamic>;
            debugPrint(
              '🔍 Share Handler - Found in data key, length: ${conversationsList.length}',
            );
          } else {
            for (var key in responseData.keys) {
              if (responseData[key] is List) {
                conversationsList = responseData[key] as List<dynamic>;
                debugPrint(
                  '🔍 Share Handler - Found at key $key, length: ${conversationsList.length}',
                );
                break;
              }
            }
          }
        }

        if (conversationsList.isNotEmpty) {
          final conversations = <ConversationModel>[];

          for (int i = 0; i < conversationsList.length; i++) {
            final json = conversationsList[i];
            try {
              final conversation = ConversationModel.fromJson(
                json as Map<String, dynamic>,
              );
              conversations.add(conversation);
            } catch (e) {
              debugPrint('⚠️ Error parsing conversation $i: $e');
              continue;
            }
          }

          if (mounted) {
            setState(() {
              _availableConversations = conversations;
              _filteredConversations = conversations;
            });
          }

          debugPrint('✅ Loaded ${conversations.length} conversations from API');
        } else {
          debugPrint('⚠️ Share Handler - API returned empty conversation list');
        }
      } else {
        debugPrint('❌ Share Handler - API call not successful');
        debugPrint('  Response: $response');
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations from API: $e');

      // If API fails and we don't have local conversations, show helpful message
      if (mounted && _availableConversations.isEmpty) {
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

        debugPrint(
          '🔍 Share Handler - Final state: ${_availableConversations.length} conversations available',
        );
      }
    }
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _filterConversations();
      });
    }
  }

  /// Filter conversations based on search query
  void _filterConversations() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_availableConversations);
    } else {
      _filteredConversations = _availableConversations.where((conversation) {
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

          if (uploadResponse['success'] == true &&
              uploadResponse['data'] != null) {
            final mediaData = uploadResponse['data'];

            // Send to each selected conversation via WebSocket
            for (final conversationId in _selectedConversations) {
              await _websocketService.sendMessage({
                'type': 'media',
                'data': {
                  ...mediaData,
                  'conversation_id': conversationId,
                  'message_type': file.type == SharedMediaType.image
                      ? 'image'
                      : 'video',
                },
                'conversation_id': conversationId,
              });
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
      debugPrint('❌ Error in send process: $e');

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
      ),
      body: Column(
        children: [
          // Shared Files Header
          _buildSharedFilesHeader(),

          // Search Bar
          _buildSearchBar(),

          // Conversations List
          Expanded(child: _buildConversationsList()),

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

  Widget _buildConversationsList() {
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

    if (_filteredConversations.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isEmpty
                    ? Icons.chat_bubble_outline
                    : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'No chats available'
                    : 'No chats found for "$_searchQuery"',
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
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          final isSelected = _selectedConversations.contains(
            conversation.conversationId,
          );

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // color: Colors.white,
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
              onTap: () =>
                  _toggleConversationSelection(conversation.conversationId),
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
                  if (conversation.isGroup)
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
              subtitle: conversation.metadata?.lastMessage.body != null
                  ? Text(
                      conversation.metadata!.lastMessage.body,
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

  Widget _buildConversationAvatar(ConversationModel conversation) {
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
