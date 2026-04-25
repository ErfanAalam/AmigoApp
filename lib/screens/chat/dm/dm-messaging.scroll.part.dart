part of 'dm-messaging.screen.dart';

extension _DmScroll on _InnerChatPageState {
  void _onMessageTextChanged() {
    // Cancel existing timer
    _draftSaveTimer?.cancel();

    // Create new timer to save draft after 500ms of no typing
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_canSetState) {
        final draftNotifier = ref.read(draftMessagesProvider.notifier);
        final text = _messageController.text;
        draftNotifier.saveDraft(widget.dm.chatId, text);
      }
    });
  }

  void _updateStickyDateSeparator() {
    if (_displayMessages.isEmpty || !_scrollController.hasClients) return;

    // Calculate which message is currently visible at the top
    final scrollOffset = _scrollController.offset;
    final itemHeight = 100.0; // Approximate height per message
    final visibleIndex = (scrollOffset / itemHeight).floor();

    // Find the message that should show the sticky date
    final messageIndex = _displayMessages.length - 1 - visibleIndex;
    if (messageIndex >= 0 && messageIndex < _displayMessages.length) {
      final currentMessage = _displayMessages[messageIndex];
      final currentDateString = ChatHelpers.getMessageDateString(
        currentMessage.sentAt,
      );

      // Only update if the date has changed - using ValueNotifier to avoid setState
      if (_currentStickyDate.value != currentDateString) {
        _currentStickyDate.value = currentDateString;
        _showStickyDate.value = true;
      }
    }
  }

  void _onScroll() async {
    // Ensure we have a valid scroll position and the widget is still mounted
    if (!mounted || !_scrollController.hasClients) return;

    // Set scrolling flag to disable swipe gestures during scroll
    _isScrolling = true;

    // Reset scrolling flag after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _isScrolling = false;
      }
    });

    // Debounce sticky date separator updates to reduce frequency (increased to 100ms)
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _updateStickyDateSeparator();
      }
    });

    // Update scroll to bottom button state
    _updateScrollToBottomState();

    // With reverse: true, when scrolling to see older messages (scrolling "up" in the UI),
    // we're actually scrolling towards maxScrollExtent
    // Load older messages when we're near the top of the scroll (close to maxScrollExtent)
    final scrollPosition = _scrollController.position.pixels;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final distanceFromTop = maxScrollExtent - scrollPosition;

    if (_isInJumpMode && !_isScrollingToJumpTarget) {
      if (distanceFromTop <= 1000) _loadJumpOlderMessages();
      if (scrollPosition <= 200) _loadJumpNewerMessages();
    } else if (!_isLoadingTargetMessage) {
      if (distanceFromTop <= 200) await _loadMoreMessages();
    }
  }

  void _scrollToBottom() {
    ChatHelpers.scrollToBottom(
      scrollController: _scrollController,
      onScrollComplete: () {
        if (_canSetState) {
          _safeSetState(() {
            // _unreadCountWhileScrolled = 0;
            _isAtBottom = true;
          });
        }
      },
      mounted: mounted,
    );
  }

  void _handleScrollToBottomTap() {
    _exitJumpMode();
    // _scrollToBottom();
    // Clear unread count
    // setState(() {
    //   _unreadCountWhileScrolled = 0;
    // });
  }

  void _updateScrollToBottomState() {
    if (!_scrollController.hasClients) return;

    final scrollPosition = _scrollController.position.pixels;

    // With reverse: true, 0 is the bottom, maxScrollExtent is the top
    // Check if we're within 100px of the bottom
    final isAtBottomNow = scrollPosition <= 100;

    // Check if user scrolled up significantly
    final scrolledUp = scrollPosition > _lastScrollPosition + 50;

    if (isAtBottomNow) {
      // User is at bottom - clear unread count
      if (_canSetState && (!_isAtBottom)) {
        _safeSetState(() {
          _isAtBottom = true;
        });
      }
    } else if (scrolledUp || scrollPosition > 100) {
      // User scrolled up - show button
      if (_canSetState && _isAtBottom) {
        _safeSetState(() {
          _isAtBottom = false;
        });
      }
    }

    _lastScrollPosition = scrollPosition;
  }

  Future<void> _scrollToMessage(String messageId) async {
    if (!mounted || !_scrollController.hasClients) return;

    // Fast path: only if message is within 100 items of the bottom (visible or near-visible).
    // For anything farther, scrollToIndex through hundreds of items is too slow — use jump mode.
    final current = _displayMessages;
    if (current.isNotEmpty) {
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final builderIndex = current.length - 1 - idx;
        if (builderIndex <= 100) {
          await _scrollController.scrollToIndex(
            builderIndex,
            preferPosition: AutoScrollPosition.middle,
            duration: const Duration(milliseconds: 300),
          );
          _highlightMessage(messageId);
          return;
        }
      }
    }

    // Jump mode: server fetches a 100-message window, replaces display list instantly
    await _jumpToMessage(messageId);
  }

  void _highlightMessage(String messageId) {
    if (!_canSetState) return;
    _safeSetState(() => _highlightedMessageId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
      _safeSetState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _jumpToMessage(String messageId) async {
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingTargetMessage = true);
    try {
      final result = await apiService.chat.getMessagesAround(
        conversationId: widget.dm.chatId,
        messageId: messageId,
        before: 50,
        after: 50,
      );
      if (!_canSetState) return;
      if (result.data == null) {
        _safeSetState(() => _isLoadingTargetMessage = false);
        if (mounted) Snack.warning('Could not load message');
        return;
      }
      final around = MessagesAroundResponse.fromJson(
        result.data as Map<String, dynamic>,
      );
      _safeSetState(() {
        final sorted = List<MessageModel>.from(around.messages)
          ..sort((a, b) {
            try {
              return DateTime.parse(
                a.sentAt,
              ).compareTo(DateTime.parse(b.sentAt));
            } catch (_) {
              return a.sentAt.compareTo(b.sentAt);
            }
          });
        // Deduplicate by message ID
        final seen = <String>{};
        _jumpMessages = sorted.where((m) => seen.add(m.id)).toList();
        _jumpHasOlderMessages = around.hasOlder;
        _jumpHasNewerMessages = around.hasNewer;
        _isInJumpMode = true;
        _isLoadingTargetMessage = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (!_canSetState || !_scrollController.hasClients) return;

      final idx = _jumpMessages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      _isScrollingToJumpTarget = true;
      await _scrollController.scrollToIndex(
        _jumpMessages.length - 1 - idx,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 300),
      );
      _isScrollingToJumpTarget = false;
      _highlightMessage(messageId);
    } catch (e) {
      debugPrint('[DM] _jumpToMessage: $e');
      if (_canSetState) _safeSetState(() => _isLoadingTargetMessage = false);
      if (mounted) Snack.warning('Could not load message');
    }
  }

  Future<void> _loadJumpOlderMessages() async {
    if (_isLoadingJumpOlder || !_jumpHasOlderMessages || !_isInJumpMode) return;
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingJumpOlder = true);
    try {
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        beforeMessageId: _jumpMessages.first.id,
        limit: 50,
      );
      if (!_canSetState || !_isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isNotEmpty) {
          _safeSetState(() {
            final existingIds = _jumpMessages.map((m) => m.id).toSet();
            final newMessages = history.messages
                .where((m) => !existingIds.contains(m.id))
                .toList();
            _jumpMessages = [...newMessages, ..._jumpMessages];
            if (_jumpMessages.length > _InnerChatPageState._jumpWindowSize) {
              final excess = _jumpMessages.length - _InnerChatPageState._jumpWindowSize;
              _jumpMessages = _jumpMessages.sublist(
                0,
                _jumpMessages.length - excess,
              );
              _jumpHasNewerMessages = true;
            }
            _jumpHasOlderMessages = history.hasMore;
          });
        } else {
          _safeSetState(() => _jumpHasOlderMessages = false);
        }
      }
    } catch (e) {
      debugPrint('[DM] _loadJumpOlderMessages: $e');
    } finally {
      if (_canSetState) _safeSetState(() => _isLoadingJumpOlder = false);
    }
  }

  Future<void> _loadJumpNewerMessages() async {
    if (_isLoadingJumpNewer || !_jumpHasNewerMessages || !_isInJumpMode) return;
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingJumpNewer = true);
    try {
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        afterMessageId: _jumpMessages.last.id,
        limit: 50,
      );
      if (!_canSetState || !_isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isEmpty || !history.hasMore) {
          _safeSetState(() => _isLoadingJumpNewer = false);
          _exitJumpMode();
          return;
        }
        _safeSetState(() {
          final existingIds = _jumpMessages.map((m) => m.id).toSet();
          final newMessages = history.messages
              .where((m) => !existingIds.contains(m.id))
              .toList();
          _jumpMessages = [..._jumpMessages, ...newMessages];
          if (_jumpMessages.length > _InnerChatPageState._jumpWindowSize) {
            final excess = _jumpMessages.length - _InnerChatPageState._jumpWindowSize;
            _jumpMessages = _jumpMessages.sublist(excess);
            _jumpHasOlderMessages = true;
          }
          _jumpHasNewerMessages = history.hasMore;
        });
      }
    } catch (e) {
      debugPrint('[DM] _loadJumpNewerMessages: $e');
    } finally {
      if (_canSetState) _safeSetState(() => _isLoadingJumpNewer = false);
    }
  }

  void _exitJumpMode() {
    if (!_canSetState) return;
    _safeSetState(() {
      _isInJumpMode = false;
      _jumpMessages = [];
      _jumpHasOlderMessages = true;
      _jumpHasNewerMessages = true;
      _isLoadingJumpOlder = false;
      _isLoadingJumpNewer = false;
      _highlightedMessageId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canSetState && _scrollController.hasClients) _scrollToBottom();
    });

    // termporary fix to ensure scroll to bottom after jump mode exit
    Timer(const Duration(milliseconds: 800), _scrollToBottom);
  }

  void _animateNewMessage(String messageId) {
    if (_animatedMessages.contains(messageId)) return; // Already animated

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final slideAnimation = Tween<double>(
      begin: 50.0, // Start 50 pixels below
      end: 0.0, // End at normal position
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final fadeAnimation =
        Tween<double>(
          begin: 0.0, // Start transparent
          end: 1.0, // End fully visible
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );

    _messageAnimationControllers[messageId] = controller;
    _messageSlideAnimations[messageId] = slideAnimation;
    _messageFadeAnimations[messageId] = fadeAnimation;
    _animatedMessages.add(messageId);

    // Start the animation
    controller.forward().then((_) {
      // Clean up after animation completes
      Future.delayed(const Duration(seconds: 5), () {
        if (_messageAnimationControllers.containsKey(messageId)) {
          _messageAnimationControllers[messageId]?.dispose();
          _messageAnimationControllers.remove(messageId);
          _messageSlideAnimations.remove(messageId);
          _messageFadeAnimations.remove(messageId);
        }
      });
    });
  }
}
