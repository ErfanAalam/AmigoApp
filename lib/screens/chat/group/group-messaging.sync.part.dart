part of 'group-messaging.screen.dart';

extension _GroupSync on _InnerGroupChatPageState {
  Future<void> getAllConversationMembers() async {
    final members = await _conversationMemberRepo
        .getMembersWithUserDetailsByConversationId(widget.group.chatId);
    _safeSetState(() {
      _conversationMembers = members;
    });
    debugPrint(
      '-------conversation members: ${_conversationMembers.length}-------',
    );
    debugPrint(
      '-------conversation members: ${widget.group.chatId}-------',
    );
  }

  /// Load draft message when opening conversation

  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(widget.group.chatId);
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.group.chatId, draft);
    }
  }

  // Future<void> _updateIsAdminOrStaff() async {
  //   // Load directly from service for immediate access

  //   if (widget.group.role == 'admin') {
  //     _safeSetState(() {
  //       _isAdminOrStaff = true;
  //     });
  //   } else {
  //     // Check if user role is 'staff'
  //     try {
  //       final currentUser = await _userRepo.getFirstUser();
  //       if (currentUser != null && currentUser.role == 'staff') {
  //         _safeSetState(() {
  //           _isAdminOrStaff = true;
  //         });
  //       }
  //     } catch (e) {
  //       debugPrint('❌ Error checking user role: $e');
  //     }
  //   }
  // }

  /// Handle message text changes with debouncing for draft saving

  bool _isValidPinnedMessage(MessageModel msg) {
    if (msg.id.isEmpty) return false;
    return (msg.body != null && msg.body!.isNotEmpty) ||
        msg.type != MessageType.text;
  }

  /// Load pinned message from database
  /// Check whether the current user has been removed from this group.
  /// `_handleConversationAction` in chat.provider sets deletedAt on the chat
  /// when the current user is in the removed members list.

  Future<void> _checkRemovedState() async {
    final conv = await _conversationRepo.getConversationById(
      widget.group.chatId,
    );
    final removed = conv?.deletedAt != null;
    if (mounted && _isRemovedFromGroup != removed) {
      _safeSetState(() => _isRemovedFromGroup = removed);
    }
  }

  Future<void> _loadPinnedMessage() async {
    final conversation = await _conversationRepo.getConversationById(
      widget.group.chatId,
    );
    final currentPinnedMessageId = conversation?.pinnedMsgId;

    if (currentPinnedMessageId != null) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        currentPinnedMessageId,
      );
      if (pinnedMessage != null && _isValidPinnedMessage(pinnedMessage)) {
        _safeSetState(() {
          _pinnedMessage = pinnedMessage;
          final isInMessages = _messages.any(
            (msg) => msg.id == pinnedMessage.id,
          );
          if (!isInMessages) {
            _messages.add(pinnedMessage);
            _sortMessagesBySentAt();
          }
        });
      } else {
        await _conversationRepo.updatePinnedMessage(
          widget.group.chatId,
          null,
        );
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    } else {
      _safeSetState(() {
        _pinnedMessage = null;
      });
    }
  }

  Future<void> _initializeChat() async {
    // get the current user details
    final currentUser = await _userUtils.getUserDetails();
    if (currentUser != null) {
      _safeSetState(() {
        _currentUserDetails = currentUser;
      });
    }

    ref
        .read(chatProvider.notifier)
        .setActiveConversation(widget.group.chatId, ChatType.group);

    // Check initial membership state
    _checkRemovedState();

    // --- Parallel: independent reads that don't depend on each other ---
    // Start message stream (synchronous subscription setup)
    _messagesStreamSub?.cancel();
    _messagesStreamSub = _messagesRepo
        .watchMessages(widget.group.chatId)
        .listen(
          (msgs) {
            if (!mounted) return;
            _safeSetState(() {
              _messages = msgs;
              _sortMessagesBySentAt();
              _isLoading = false;
            });
            // Re-check removed state after each message batch (memberRemoved
            // WS events trigger the provider to soft-delete the chat).
            _checkRemovedState();
          },
          onError: (e) {
            debugPrint('Group messages stream error: $e');
          },
        );

    // Start reactions stream (synchronous subscription setup)
    _reactionsSubscription?.cancel();
    _reactionsSubscription = _messageStatusRepo
        .watchReactionsByConversation(widget.group.chatId)
        .listen(
          (reactions) {
            if (!mounted) return;
            _safeSetState(() => _reactionsByMessage = reactions);
          },
          onError: (e) {
            debugPrint('Reactions stream error: $e');
          },
        );

    // Start delivery/read status stream
    _deliveryStatusSubscription?.cancel();
    _deliveryStatusSubscription = _messageStatusRepo
        .watchDeliveryStatusByConversation(widget.group.chatId)
        .listen(
          (statuses) {
            if (!mounted) return;
            _safeSetState(() => _deliveryStatusByMessage = statuses);
          },
          onError: (e) {
            debugPrint('Delivery status stream error: $e');
          },
        );

    // Run independent async operations in parallel:
    // - clear unread count
    // - load pinned message
    await Future.wait([
      _conversationRepo.updateUnreadCount(widget.group.chatId, 0),
      _loadPinnedMessage(),
    ]);

    // Clear via provider to update UI state (synchronous, no await needed)
    ref
        .read(chatProvider.notifier)
        .clearUnreadCount(widget.group.chatId, ChatType.group);

    // Fire-and-forget: don't block chat opening for these
    unawaited(_sendConversationJoin().catchError(
      (e) => debugPrint('Error joining conversation: $e'),
    ));
    unawaited(_syncMessagesFromServer().catchError(
      (e) => debugPrint('Error syncing messages: $e'),
    ));

    // resend any failed messages
    // final failedMessages = messaagesFromLocal
    //     .where(
    //       (msg) =>
    //           msg.metadata != null &&
    //           msg.metadata!['upload_failed'] == true &&
    //           msg.senderId == _currentUserDetails?.id,
    //     )
    //     .toList();
    // if (failedMessages.isNotEmpty) {
    //   // Set flag to indicate automatic resend is in progress
    //   if (mounted) {
    //     _safeSetState(() {
    //       _isResendingFailedMessages = true;
    //     });
    //   }
    //
    //   // Update UI to show loading state for all failed messages before resending
    //   if (mounted) {
    //     _safeSetState(() {
    //       for (final failedMessage in failedMessages) {
    //         final msgIndex = _messages.indexWhere(
    //           (msg) =>
    //               msg.id == failedMessage.id ||
    //               msg.optimisticId == failedMessage.optimisticId,
    //         );
    //         if (msgIndex != -1) {
    //           final uploadingMetadata = Map<String, dynamic>.from(
    //             failedMessage.metadata ?? {},
    //           );
    //           uploadingMetadata.remove('upload_failed');
    //           uploadingMetadata['is_uploading'] = true;
    //           _messages[msgIndex] = failedMessage.copyWith(
    //             status: MessageStatusType.sent,
    //             metadata: uploadingMetadata,
    //           );
    //         }
    //       }
    //     });
    //   }
    //
    //   // Now resend each failed message
    //   for (final failedMessage in failedMessages) {
    //     await _resendFailedMessage(failedMessage);
    //   }
    //
    //   // Wait a bit for WebSocket handlers to process the responses
    //   await Future.delayed(const Duration(milliseconds: 500));
    //
    //   // Reload messages from DB to ensure UI reflects latest state
    //   final updatedMessages = await _messagesRepo.getMessagesByConversation(
    //     widget.group.chatId,
    //     limit: 100,
    //     offset: 0,
    //   );
    //
    //   // Clear flag after all automatic resends are complete
    //   if (mounted) {
    //     _safeSetState(() {
    //       _messages = updatedMessages;
    //       _sortMessagesBySentAt();
    //       _isResendingFailedMessages = false;
    //     });
    //   }
    // } else {
    //   // No failed messages - enable manual resend immediately
    //   if (mounted) {
    //     _safeSetState(() {
    //       _isResendingFailedMessages = false;
    //     });
    //   }
    // }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreOnServer) return;

    _safeSetState(() {
      _isLoadingMore = true;
    });

    try {
      // Use cursor-based pagination: fetch messages older than the oldest we have.
      final oldestMsgId = _messages.isNotEmpty ? _messages.first.id : null;
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.group.chatId,
        beforeMessageId: oldestMsgId,
        limit: 100,
      );

      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(result.data!);
        if (history.messages.isNotEmpty) {
          await _messagesRepo.insertMessages(history.messages);
          // Drift stream fires automatically — no setState for _messages needed
          _hasMoreOnServer = history.hasMore;
        } else {
          _hasMoreOnServer = false;
        }
      } else {
        _hasMoreOnServer = false;
      }
    } catch (e) {
      debugPrint('[Group] Error loading more messages: $e');
    } finally {
      if (mounted)
        _safeSetState(() {
          _isLoadingMore = false;
        });
    }
  }

  /// One-shot: fetch chat members from server and upsert to
  /// local chat_members + users tables. Called on first chat open only.

  Future<void> _fetchAndSaveChatMembers() async {
    try {
      final result = await apiService.chat.getChatMembers(
        conversationId: widget.group.chatId,
      );
      if (!result.isSuccess || result.data == null) return;

      final data = result.data as Map<String, dynamic>;
      final List<dynamic> raw = (data['members'] ?? []) as List<dynamic>;
      if (raw.isEmpty) return;

      final members = raw
          .map(
            (e) => ConversationMemberModel(
              id: e['id']?.toString(),
              chatId: widget.group.chatId,
              userId: (e['user_id'] ?? '').toString(),
              role: (e['role'] ?? 'member').toString(),
              joinedAt: e['joined_at']?.toString(),
              removedAt: e['removed_at']?.toString(),
              lastReadMsgId: e['last_read_msg_id']?.toString(),
              lastDeliveredMsgId: e['last_delivered_msg_id']?.toString(),
            ),
          )
          .toList();

      final users = raw
          .map(
            (e) => UserModel(
              id: (e['user_id'] ?? '').toString(),
              name: (e['name'] ?? '').toString(),
              phone: (e['phone'] ?? '').toString(),
              profilePic: e['profile_pic']?.toString(),
              role: e['user_role']?.toString(),
            ),
          )
          .toList();

      await _conversationMemberRepo.insertOrUpdateConversationMembers(members);
      await _userRepo.insertOrUpdateUsers(users);
    } catch (e) {
      debugPrint('[Group] Error fetching chat members: $e');
    }
  }

  /// Sync all messages from server to local DB
  /// This is called when user visits the conversation for the first time
  /// Sync messages from server — lightweight gap detection.
  /// First open: bulk fetch up to 300 messages.
  /// Subsequent opens: only fetch if local is behind server's lastMsgId.

  Future<void> _syncMessagesFromServer() async {
    final needSync = await _conversationRepo.getNeedSyncStatus(
      widget.group.chatId,
    );

    if (needSync == false) {
      // Subsequent open: gap-check only
      final localLatestId = _messages.isNotEmpty ? _messages.last.id : null;
      final serverLatestId = widget.group.lastMsgId;

      if (localLatestId == null || localLatestId == serverLatestId || serverLatestId == null) {
        _hasMoreOnServer = true;
        return;
      }

      debugPrint('[Sync] Gap detected: local=$localLatestId server=$serverLatestId');
      final gapResponse = await apiService.chat.getConversationHistory(
        conversationId: widget.group.chatId,
        afterMessageId: localLatestId,
        limit: 100,
      );

      if (gapResponse.isSuccess && gapResponse.data != null) {
        final gapHistory = ConversationHistoryResponse.fromJson(gapResponse.data!);
        if (gapHistory.messages.isNotEmpty) {
          await _messagesRepo.insertMessages(gapHistory.messages);
          debugPrint('[Sync] Gap filled: ${gapHistory.messages.length} messages');
        }
      }

      _hasMoreOnServer = true;
      return;
    }

    // First open: fetch chat members once, then fetch up to 3 batches of 100 = 300 messages
    await _fetchAndSaveChatMembers();

    const int firstOpenMaxBatches = 3;
    const int limit = 100;
    int batch = 0;
    bool hasMore = true;
    String? beforeCursor;

    if (mounted)
      _safeSetState(() {
        _isSyncingMessages = true;
      });

    try {
      while (batch < firstOpenMaxBatches && hasMore && mounted && !_isDisposed) {
        final result = await apiService.chat.getConversationHistory(
          conversationId: widget.group.chatId,
          beforeMessageId: beforeCursor,
          limit: limit,
        );

        if (!result.isSuccess || result.data == null) break;

        final history = ConversationHistoryResponse.fromJson(result.data!);

        if (history.messages.isEmpty) break;

        await _messagesRepo.insertMessages(history.messages);

        beforeCursor = history.messages.first.id;
        hasMore = history.hasMore;
        batch++;
        await Future.delayed(const Duration(milliseconds: 30));
      }

      _hasMoreOnServer = hasMore;

      if (mounted)
        _safeSetState(() {
          _isSyncingMessages = false;
        });

      // First open only: sync statuses from server (no local data to overwrite)
      await _syncMessageStatuses();
      await _conversationRepo.updateNeedSyncStatus(
        widget.group.chatId,
        false,
      );
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      if (mounted)
        _safeSetState(() {
          _isSyncingMessages = false;
        });
    }
  }

  /// Sync message statuses from server to local DB

  Future<void> _syncMessageStatuses() async {
    try {
      int page = 1;
      const int limit = 1000; // Fetch up to 1000 statuses per page
      bool hasMorePages = true;

      while (hasMorePages && mounted && !_isDisposed) {
        final result = await apiService.chat.getMessageStatuses(
          conversationId: widget.group.chatId,
          page: page,
          limit: limit,
        );

        if (result.isSuccess && result.data != null) {
          final statusesData = result.data!;
          final List<dynamic> statuses = statusesData['statuses'] ?? [];

          if (statuses.isEmpty) {
            break; // No more statuses
          }

          if (statuses.isNotEmpty) {
            debugPrint('[StatusSync] Sample status: ${statuses.first}');
          }

          // Convert to format expected by repository (Drizzle returns camelCase)
          final List<Map<String, dynamic>> statusesToInsert = statuses.map((
            status,
          ) {
            return {
              'id': status['id'],
              'conversationId': status['chatId'] ?? status['chat_id'] ?? status['conv_id'],
              'messageId': status['messageId'] ?? status['message_id'],
              'userId': status['userId'] ?? status['user_id'],
              'deliveredAt': status['deliveredAt'] ?? status['delivered_at'],
              'readAt': status['readAt'] ?? status['read_at'],
              'reaction': status['reaction'],
            };
          }).toList();

          // Insert statuses into local DB
          await _messageStatusRepo.insertMessageStatuses(statusesToInsert);

          // Check if there are more pages
          final pagination = statusesData['pagination'];
          hasMorePages = pagination?['hasNextPage'] ?? false;
          page++;

          // Small delay to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing message statuses: $e');
      // Don't fail the entire sync if status sync fails
    }
  }

  /// Sort messages by sentAt timestamp to maintain consistent order
  /// This prevents messages from flipping when setState is called

  void _sortMessagesBySentAt() {
    _messages.sort((a, b) {
      try {
        final aTime = DateTime.parse(a.sentAt);
        final bTime = DateTime.parse(b.sentAt);
        return aTime.compareTo(bTime);
      } catch (e) {
        // If parsing fails, fall back to string comparison
        return a.sentAt.compareTo(b.sentAt);
      }
    });
  }

  // int _  parseToInt(dynamic value) {
  //   if (value == null) return 0;
  //   if (value is int) return value;
  //   if (value is String) return int.tryParse(value) ?? 0;
  //   return 0;
  // }

  /// Load pinned message from storage or conversation metadata
  // /// The above code snippet contains commented-out functions related to loading, validating, and
  /// cleaning up pinned and starred messages in a chat application.
  // Future<void> _loadPinnedMessageFromStorage() async {
  //   final conversationId = widget.group.chatId;

  //   // First check if group metadata has pinned message
  //   if (widget.group.metadata?.pinnedMessage != null) {
  //     final pinnedMessage = widget.group.metadata!.pinnedMessage!;
  //     if (mounted) {
  //       _safeSetState(() {
  //         _pinnedMessage = pinnedMessage;
  //       });
  //       return;
  //     }
  //   }

  //   // Fallback to local storage
  //   final pinnedMessageId =
  //       await MessageStorageHelpers.loadPinnedMessageFromStorage(
  //         conversationId,
  //       );

  //   if (pinnedMessageId != null && mounted) {
  //     _safeSetState(() {
  //       _pinnedMessageId = pinnedMessageId;
  //     });
  //   }
  // }

  // /// Load starred messages from storage
  // Future<void> _loadStarredMessagesFromStorage() async {
  //   final conversationId = widget.group.chatId;
  //   final starredMessages =
  //       await MessageStorageHelpers.loadStarredMessagesFromStorage(
  //         conversationId,
  //       );

  //   if (starredMessages.isNotEmpty && mounted) {
  //     _safeSetState(() {
  //       _starredMessages.clear();
  //       _starredMessages.addAll(starredMessages);
  //     });
  //   }
  // }

  // /// Validate pinned message exists in current messages and clean up if not
  // void _validatePinnedMessage() {
  //   // Don't validate if we don't have a full message set yet
  //   // Only validate if we've loaded a significant number of messages
  //   // This prevents clearing pinned messages during initial load or pagination
  //   if (_pinnedMessageId != null && _messages.length > 20) {
  //     final messageExists = _messages.any((msg) => msg.id == _pinnedMessageId);
  //     if (!messageExists && mounted) {
  //       debugPrint(
  //         '⚠️ Pinned message $_pinnedMessageId not found in current group messages, but keeping it (might be paginated)',
  //       );
  //       // Don't clear the pinned message - it might just be in a different page
  //       // Only clear if we explicitly receive an unpin action via WebSocket
  //     }
  //   }
  // }

  // /// Validate starred messages exist in current messages and clean up invalid ones
  // void _validateStarredMessages() {
  //   if (_starredMessages.isNotEmpty && _messages.isNotEmpty) {
  //     final currentMessageIds = _messages.map((msg) => msg.id).toSet();
  //     final invalidStarredMessages = _starredMessages
  //         .where((starredId) => !currentMessageIds.contains(starredId))
  //         .toList();

  //     if (invalidStarredMessages.isNotEmpty && mounted) {
  //       debugPrint(
  //         '⚠️ ${invalidStarredMessages.length} starred messages not found in current group messages, cleaning up',
  //       );

  //       _safeSetState(() {
  //         _starredMessages.removeAll(invalidStarredMessages);
  //       });

  //       // Update storage with cleaned up starred messages
  //       _messagesRepo.saveStarredMessages(
  //         conversationId: widget.group.chatId,
  //         starredMessageIds: _starredMessages,
  //       );
  //     }
  //   }
  // }

  /// Validate reply messages are properly loaded and structured
  // void _validateReplyMessages() {
  //   if (_messages.isEmpty) return;

  //   Future.microtask(() async {
  //     try {
  //       // Count reply messages in current UI
  //       final replyMessagesInUI = _messages
  //           .where(
  //             (msg) =>
  //                 msg.replyToMessage != null || msg.replyToMessageId != null,
  //           )
  //           .toList();

  //       debugPrint(
  //         '🔍 Found ${replyMessagesInUI.length} reply messages in group cache',
  //       );

  //       // Validate each reply message
  //       for (final message in replyMessagesInUI) {
  //         if (message.replyToMessage != null) {
  //           debugPrint(
  //             '✅ Group reply message ${message.id} has complete reply data: "${message.replyToMessage!.body}" by ${message.replyToMessage!.senderName}',
  //           );
  //         } else if (message.replyToMessageId != null) {
  //           // Try to find the referenced message in current messages
  //           MessageModel? referencedMessage;
  //           try {
  //             referencedMessage = _messages.firstWhere(
  //               (msg) => msg.id == message.replyToMessageId,
  //             );
  //           } catch (e) {
  //             referencedMessage = null;
  //           }
  //           if (referencedMessage != null) {
  //             debugPrint(
  //               '🔗 Group reply message ${message.id} references existing message ${message.replyToMessageId}',
  //             );
  //           } else {
  //             debugPrint(
  //               '⚠️ Group reply message ${message.id} references missing message ${message.replyToMessageId}',
  //             );
  //           }
  //         }
  //       }

  //       // Validate storage
  //       await _messagesRepo.validateReplyMessageStorage(
  //         widget.group.chatId,
  //       );
  //     } catch (e) {
  //       debugPrint('❌ Error validating group reply messages: $e');
  //     }
  //   });
  // }

  /// Cache user info from conversation metadata to local DB
  // Future<void> _cacheUsersFromMetadata() async {
  //   if (_conversationMeta == null || _conversationMeta!.members.isEmpty) return;

  //   try {
  //     for (final member in _conversationMeta!.members) {
  //       final userId = member['user_id'] as int?;
  //       final userName = member['name'] as String?;
  //       final profilePic = member['profile_pic'] as String?;

  //       if (userId != null && userName != null) {
  //         // Cache in memory
  //         _userInfoCache[userId] = {
  //           'name': userName,
  //           'profile_pic': profilePic,
  //         };

  //         // Save to group_members table (not users table) for offline access
  //         final memberInfo = GroupMemberInfo(
  //           userId: userId,
  //           userName: userName,
  //           profilePic: profilePic,
  //           role: 'member', // Default role from metadata
  //           joinedAt: null,
  //         );
  //         await _groupMembersRepo.insertOrUpdateGroupMember(
  //           widget.group.chatId,
  //           memberInfo,
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Error caching users from metadata: $e');
  //   }
  // }

  /// Show ReadBy modal for a specific message
}
