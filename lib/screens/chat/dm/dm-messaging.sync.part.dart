part of 'dm-messaging.screen.dart';

extension _DmSync on _InnerChatPageState {
  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(widget.dm.chatId);
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.dm.chatId, draft);
    }
  }

  bool _isValidPinnedMessage(MessageModel msg) {
    if (msg.id.isEmpty) return false;
    return (msg.body != null && msg.body!.isNotEmpty) ||
        msg.type != MessageType.text;
  }

  Future<void> _loadPinnedMessage() async {
    final conversation = await _conversationsRepo.getConversationById(
      widget.dm.chatId,
    );
    final currentPinnedMessageId = conversation?.pinnedMsgId;

    if (currentPinnedMessageId != null) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        currentPinnedMessageId,
      );
      if (!_canSetState) return;

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
        await _conversationsRepo.updatePinnedMessage(widget.dm.chatId, null);
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    } else {
      if (!_canSetState) return;
      _safeSetState(() {
        _pinnedMessage = null;
      });
    }
  }

  Future<void> _initializeChat() async {
    // get the current user details
    final currentUser = await _userUtils.getUserDetails();
    if (currentUser != null) {
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _currentUserDetails = currentUser;
      });
    }

    ref
        .read(chatProvider.notifier)
        .setActiveConversation(widget.dm.chatId, ChatType.dm);

    // --- Parallel: independent reads that don't depend on each other ---
    // Start message stream (synchronous subscription setup)
    _messagesStreamSub?.cancel();
    _messagesStreamSub = _messagesRepo
        .watchMessages(widget.dm.chatId)
        .listen(
          (msgs) {
            if (!_canSetState) return;
            _safeSetState(() {
              _messages = msgs;
              _sortMessagesBySentAt();
              _isLoading = false;
            });
          },
          onError: (e) {
            debugPrint('Messages stream error: $e');
          },
        );

    // Start reactions stream (synchronous subscription setup)
    _reactionsSubscription?.cancel();
    _reactionsSubscription = _messageStatusRepo
        .watchReactionsByConversation(widget.dm.chatId)
        .listen(
          (reactions) {
            debugPrint(
              '[Reactions] Stream fired: ${reactions.length} messages with reactions',
            );
            for (final entry in reactions.entries) {
              debugPrint(
                '[Reactions]   msg=${entry.key} emojis=${(entry.value as Map).keys.toList()}',
              );
            }
            if (!_canSetState) return;
            _safeSetState(() => _reactionsByMessage = reactions);
          },
          onError: (e) {
            debugPrint('Reactions stream error: $e');
          },
        );

    // Start delivery/read status stream
    _deliveryStatusSubscription?.cancel();
    _deliveryStatusSubscription = _messageStatusRepo
        .watchDeliveryStatusByConversation(widget.dm.chatId)
        .listen(
          (statuses) {
            if (!_canSetState) return;
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
      _conversationsRepo.updateUnreadCount(widget.dm.chatId, 0),
      _loadPinnedMessage(),
    ]);

    // Clear via provider to update UI state (synchronous, no await needed)
    ref
        .read(chatProvider.notifier)
        .clearUnreadCount(widget.dm.chatId, ChatType.dm);

    // Fire-and-forget: don't block chat opening for these
    unawaited(
      _sendConversationJoin().catchError(
        (e) => debugPrint('Error joining conversation: $e'),
      ),
    );
    unawaited(
      _syncMessagesFromServer().catchError(
        (e) => debugPrint('Error syncing messages: $e'),
      ),
    );

    // resend any failed messages
    // final failedMessages = messagesFromLocal
    //     .where(
    //       (msg) =>
    //           msg.metadata != null &&
    //           msg.metadata!['upload_failed'] == true &&
    //           msg.senderId == _currentUserDetails?.id,
    //     )
    //     .toList();
    // if (failedMessages.isNotEmpty) {
    //   // Set flag to indicate automatic resend is in progress
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       _isResendingFailedMessages = true;
    //     });
    //   }
    //
    //   // Update UI to show loading state for all failed messages before resending
    //   if (_canSetState) {
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
    //     widget.dm.chatId,
    //     limit: 100,
    //     offset: 0,
    //   );
    //
    //   // Clear flag after all automatic resends are complete
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       _messages = updatedMessages;
    //       _sortMessagesBySentAt();
    //       _isResendingFailedMessages = false;
    //     });
    //   }
    // } else {
    //   // No failed messages - enable manual resend immediately
    //   if (_canSetState) {
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
        conversationId: widget.dm.chatId,
        beforeMessageId: oldestMsgId,
        limit: 100,
      );

      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
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
      debugPrint('[DM] Error loading more messages: $e');
    } finally {
      if (mounted) {
        _safeSetState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchAndSaveChatMembers() async {
    try {
      final result = await apiService.chat.getChatMembers(
        conversationId: widget.dm.chatId,
      );
      if (!result.isSuccess || result.data == null) return;

      final data = result.data as Map<String, dynamic>;
      final List<dynamic> raw = (data['members'] ?? []) as List<dynamic>;
      if (raw.isEmpty) return;

      final members = raw
          .map(
            (e) => ConversationMemberModel(
              id: e['id']?.toString(),
              chatId: widget.dm.chatId,
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
      debugPrint('[DM] Error fetching chat members: $e');
    }
  }

  Future<void> _syncMessagesFromServer() async {
    final needSync = await _conversationsRepo.getNeedSyncStatus(
      widget.dm.chatId,
    );

    if (needSync == false) {
      // Subsequent open: gap-check only
      final localLatestId = _messages.isNotEmpty ? _messages.last.id : null;
      final serverLatestId = widget.dm.lastMsgId;

      if (localLatestId == null ||
          localLatestId == serverLatestId ||
          serverLatestId == null) {
        _hasMoreOnServer = true;
        return;
      }

      // Local is behind — fetch only the gap
      debugPrint(
        '[Sync] Gap detected: local=$localLatestId server=$serverLatestId',
      );
      final gapResponse = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        afterMessageId: localLatestId,
        limit: 100,
      );

      if (gapResponse.data != null) {
        final gapHistory = ConversationHistoryResponse.fromJson(
          gapResponse.data as Map<String, dynamic>,
        );
        if (gapHistory.messages.isNotEmpty) {
          await _messagesRepo.insertMessages(gapHistory.messages);
          debugPrint(
            '[Sync] Gap filled: ${gapHistory.messages.length} messages',
          );
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

    if (_canSetState) {
      _safeSetState(() {
        _isSyncingMessages = true;
      });
    }

    try {
      while (batch < firstOpenMaxBatches &&
          hasMore &&
          mounted &&
          !_isDisposed) {
        final result = await apiService.chat.getConversationHistory(
          conversationId: widget.dm.chatId,
          beforeMessageId: beforeCursor,
          limit: limit,
        );

        if (result.data == null) break;

        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );

        if (history.messages.isEmpty) break;

        await _messagesRepo.insertMessages(history.messages);

        beforeCursor = history.messages.first.id;
        hasMore = history.hasMore;
        batch++;
        await Future.delayed(const Duration(milliseconds: 30));
      }

      _hasMoreOnServer = hasMore;

      if (mounted) {
        _safeSetState(() {
          _isSyncingMessages = false;
        });
      }

      // First open only: sync statuses from server (no local data to overwrite)
      await _syncMessageStatuses();
      await _conversationsRepo.updateNeedSyncStatus(widget.dm.chatId, false);
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      if (mounted) {
        _safeSetState(() {
          _isSyncingMessages = false;
        });
      }
    }
  }

  Future<void> _syncMessageStatuses() async {
    print("-----------------------------------------------------------");
    print("_syncMessageStatuses");
    print("-----------------------------------------------------------");
    try {
      int page = 1;
      const int limit = 1000; // Fetch up to 1000 statuses per page
      bool hasMorePages = true;

      while (hasMorePages && _canSetState) {
        final response = (await apiService.chat.getMessageStatuses(
          conversationId: widget.dm.chatId,
          page: page,
          limit: limit,
        )).toMap();

        if (response['success'] != true || response['data'] == null) {
          break; // Stop on error
        }

        final statusesData = response['data'];
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
    } catch (e) {
      debugPrint('❌ Error syncing message statuses: $e');
      // Don't fail the entire sync if status sync fails
    }
  }

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

  MessageStatusType _deriveStatus(MessageModel message) {
    if (message.isFailed) return MessageStatusType.failed;
    final atts = message.attachments;
    if (atts is Map<String, dynamic>) {
      if (atts['is_uploading'] == true) return MessageStatusType.uploading;
    }
    return _deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
  }
}
