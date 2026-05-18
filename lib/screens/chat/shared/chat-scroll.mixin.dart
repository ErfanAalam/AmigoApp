import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../models/message.model.dart';
import '../../../api/api_service.dart';
import '../../../providers/draft.provider.dart';
import '../../../ui/snackbar.dart';
import '../../../utils/chat/chat-helpers.utils.dart';

/// Scroll-list, jump-mode, and message-animation plumbing shared by the DM
/// and group messaging screens. Owns ~17 transient state fields and the
/// methods that drive: draft saving on text change, debounced sticky-date
/// updates, scroll-to-bottom button visibility, fast-path scroll-to-message
/// (with a server-fetched jump window for far targets), and the slide-fade
/// animation applied to brand-new messages.
///
/// The host plugs in via [scrollController], [loadMoreMessages] (impl
/// lives on the host's sync code), [setStickyDate] (DM uses ValueNotifier,
/// group uses plain state), [scrollDebugPrefix], and an optional
/// [loadMoreDistanceFromTop] override.
mixin ChatScrollMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, TickerProvider {
  Timer? draftSaveTimer;
  Timer? scrollDebounceTimer;
  Timer? highlightTimer;

  double lastScrollPosition = 0.0;
  bool isAtBottom = true;

  // Sticky date pill state. Using ValueNotifiers so the date update during
  // scroll doesn't trigger a full-screen rebuild — only the
  // ValueListenableBuilder under [buildStickyDateSeparator] rebuilds.
  final ValueNotifier<String?> currentStickyDate = ValueNotifier<String?>(null);
  final ValueNotifier<bool> showStickyDate = ValueNotifier<bool>(false);

  // Jump mode — server fetches a window around a target message and the
  // display list temporarily switches to [jumpMessages] until the user
  // scrolls back to the bottom.
  static const int _jumpWindowSize = 300;
  bool isInJumpMode = false;
  bool isScrollingToJumpTarget = false;
  bool isLoadingTargetMessage = false;
  bool isLoadingJumpOlder = false;
  bool isLoadingJumpNewer = false;
  bool jumpHasOlderMessages = true;
  bool jumpHasNewerMessages = true;
  List<MessageModel> jumpMessages = [];

  // New-message slide+fade animation
  final Map<String, AnimationController> messageAnimationControllers = {};
  final Map<String, Animation<double>> messageSlideAnimations = {};
  final Map<String, Animation<double>> messageFadeAnimations = {};
  final Set<String> animatedMessages = {};

  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;
  TextEditingController get messageController;
  String get conversationId;
  ApiService get chatApiService;

  /// Where the host's mixin-private highlight slot lives (provided by
  /// ChatSearchMixin in the current setup).
  String? get highlightedMessageId;
  set highlightedMessageId(String? value);

  AutoScrollController get scrollController;

  /// Implemented by the host's sync code — pulls older messages from the
  /// repository / API.
  Future<void> loadMoreMessages();

  String get scrollDebugPrefix;

  /// Distance (in px) from the top before [loadMoreMessages] kicks in.
  /// DM uses the default; group overrides to 1000 to load earlier.
  int get loadMoreDistanceFromTop => 200;

  /// Source list before disappearing-messages filtering. Use this when you
  /// need authoritative indices for mutations (e.g. ack updates) — those keys
  /// off message id, but loops that rely on index/length need the unfiltered
  /// list to stay consistent with the on-disk row set.
  List<MessageModel> get rawDisplayMessages =>
      isInJumpMode ? jumpMessages : messages;

  /// Render-only view: hides messages whose disappearing deadline has already
  /// passed so the UI clears them the moment the timer ticks past expires_at,
  /// without waiting for the server's message:delete event to roundtrip.
  /// The authoritative soft-delete still arrives via the WS handler — this is
  /// purely a view predicate, no DB writes happen here.
  /// See chat-sync.mixin._disappearingTicker for the rebuild driver.
  List<MessageModel> get displayMessages {
    final src = rawDisplayMessages;
    if (src.isEmpty) return src;
    final now = DateTime.now();
    // Fast path: if no row has expiresAt set, skip the allocation.
    if (!src.any((m) => m.expiresAt != null)) return src;
    return src.where((m) => !m.isExpiredAt(now)).toList(growable: false);
  }

  /// Owned by ChatSwipeReplyMixin; gestures gate on this to avoid starting
  /// a swipe-reply while the list is mid-scroll. Hosts that don't mix in
  /// the swipe mixin can just override with a stub.
  bool get isScrolling;
  set isScrolling(bool value);

  /// Provided by ChatSyncMixin (read+write so this mixin can clear the
  /// separator when the user scrolls to bottom).
  String? get firstUnreadMessageId;
  set firstUnreadMessageId(String? value);
  int get unreadAtOpen;
  set unreadAtOpen(int value);

  void onMessageTextChanged() {
    draftSaveTimer?.cancel();
    draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (canSetState) {
        ref
            .read(draftMessagesProvider.notifier)
            .saveDraft(conversationId, messageController.text);
      }
    });
  }

  void updateStickyDateSeparator() {
    if (displayMessages.isEmpty || !scrollController.hasClients) return;

    final scrollOffset = scrollController.offset;
    const itemHeight = 100.0; // Approximate height per message
    final visibleIndex = (scrollOffset / itemHeight).floor();

    final messageIndex = displayMessages.length - 1 - visibleIndex;
    if (messageIndex >= 0 && messageIndex < displayMessages.length) {
      final currentMessage = displayMessages[messageIndex];
      final currentDateString = ChatHelpers.getMessageDateString(
        currentMessage.sentAt,
      );
      if (currentStickyDate.value != currentDateString) {
        currentStickyDate.value = currentDateString;
        showStickyDate.value = true;
      }
    }
  }

  Widget buildStickyDateSeparator() {
    return ValueListenableBuilder<bool>(
      valueListenable: showStickyDate,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return ValueListenableBuilder<String?>(
          valueListenable: currentStickyDate,
          builder: (context, date, _) {
            if (date == null) return const SizedBox.shrink();
            final messageWithCurrentDate = displayMessages.firstWhere(
              (m) => ChatHelpers.getMessageDateString(m.sentAt) == date,
              orElse: () => displayMessages.first,
            );
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  ChatHelpers.formatDateSeparator(
                    messageWithCurrentDate.sentAt,
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void onScroll() {
    if (!mounted || !scrollController.hasClients) return;

    isScrolling = true;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) isScrolling = false;
    });

    scrollDebounceTimer?.cancel();
    scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && scrollController.hasClients) {
        updateStickyDateSeparator();
      }
    });

    updateScrollToBottomState();

    final scrollPosition = scrollController.position.pixels;
    final maxScrollExtent = scrollController.position.maxScrollExtent;
    final distanceFromTop = maxScrollExtent - scrollPosition;

    if (isInJumpMode && !isScrollingToJumpTarget) {
      if (distanceFromTop <= 1000) loadJumpOlderMessages();
      if (scrollPosition <= 200) loadJumpNewerMessages();
    } else if (!isLoadingTargetMessage) {
      if (distanceFromTop <= loadMoreDistanceFromTop) loadMoreMessages();
    }
  }

  void scrollToBottom() {
    ChatHelpers.scrollToBottom(
      scrollController: scrollController,
      onScrollComplete: () {
        if (canSetState) {
          safeSetState(() {
            isAtBottom = true;
          });
        }
      },
      mounted: mounted,
    );
  }

  void handleScrollToBottomTap() {
    exitJumpMode();
  }

  void updateScrollToBottomState() {
    if (!scrollController.hasClients) return;

    final scrollPosition = scrollController.position.pixels;
    final isAtBottomNow = scrollPosition <= 100;
    final scrolledUp = scrollPosition > lastScrollPosition + 50;

    if (isAtBottomNow) {
      if (canSetState && !isAtBottom) {
        safeSetState(() {
          isAtBottom = true;
          // Caught up — drop the unread separator so it doesn't reappear
          // if more messages arrive while still pinned to bottom.
          firstUnreadMessageId = null;
          unreadAtOpen = 0;
        });
      }
    } else if (scrolledUp || scrollPosition > 100) {
      if (canSetState && isAtBottom) {
        safeSetState(() {
          isAtBottom = false;
        });
      }
    }

    lastScrollPosition = scrollPosition;
  }

  /// Scroll to the first-unread anchor on initial paint if one exists,
  /// otherwise fall back to the default newest-at-bottom behavior. Called
  /// from ChatSyncMixin once the messages stream produces its first
  /// non-empty emit. The list is `reverse: true` (newest at index 0 in
  /// builder space), so the builder index is `length - 1 - displayIndex`.
  Future<void> scrollToFirstUnreadOrBottom() async {
    if (!mounted || !scrollController.hasClients) {
      // Wait one frame — first emit fires before the list is laid out.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !scrollController.hasClients) return;
    }
    final anchor = firstUnreadMessageId;
    if (anchor != null && unreadAtOpen > 0) {
      final list = displayMessages;
      final idx = list.indexWhere((m) => m.id == anchor);
      if (idx != -1) {
        final builderIndex = list.length - 1 - idx;
        try {
          await scrollController.scrollToIndex(
            builderIndex,
            preferPosition: AutoScrollPosition.middle,
            duration: const Duration(milliseconds: 250),
          );
          return;
        } catch (_) {
          // Fall through to scrollToBottom on any layout race.
        }
      }
    }
    scrollToBottom();
  }

  Future<void> scrollToMessage(String messageId) async {
    if (!mounted || !scrollController.hasClients) return;

    final current = displayMessages;
    if (current.isNotEmpty) {
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final builderIndex = current.length - 1 - idx;
        if (builderIndex <= 100) {
          await scrollController.scrollToIndex(
            builderIndex,
            preferPosition: AutoScrollPosition.middle,
            duration: const Duration(milliseconds: 300),
          );
          highlightMessage(messageId);
          return;
        }
      }
    }

    await jumpToMessage(messageId);
  }

  void highlightMessage(String messageId) {
    if (!canSetState) return;
    safeSetState(() => highlightedMessageId = messageId);
    highlightTimer?.cancel();
    highlightTimer = Timer(const Duration(milliseconds: 2000), () {
      if (canSetState) safeSetState(() => highlightedMessageId = null);
    });
  }

  Future<void> jumpToMessage(String messageId) async {
    if (!canSetState) return;
    safeSetState(() => isLoadingTargetMessage = true);
    try {
      final result = await chatApiService.chat.getMessagesAround(
        conversationId: conversationId,
        messageId: messageId,
        before: 50,
        after: 50,
      );
      if (!canSetState) return;
      if (result.data == null) {
        safeSetState(() => isLoadingTargetMessage = false);
        if (canSetState) Snack.warning('Could not load message');
        return;
      }
      final around = MessagesAroundResponse.fromJson(
        result.data as Map<String, dynamic>,
      );
      safeSetState(() {
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
        final seen = <String>{};
        jumpMessages = sorted.where((m) => seen.add(m.id)).toList();
        jumpHasOlderMessages = around.hasOlder;
        jumpHasNewerMessages = around.hasNewer;
        isInJumpMode = true;
        isLoadingTargetMessage = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (!canSetState || !scrollController.hasClients) return;

      final idx = jumpMessages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      isScrollingToJumpTarget = true;
      await scrollController.scrollToIndex(
        jumpMessages.length - 1 - idx,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 300),
      );
      isScrollingToJumpTarget = false;
      highlightMessage(messageId);
    } catch (e) {
      debugPrint('$scrollDebugPrefix jumpToMessage: $e');
      if (canSetState) safeSetState(() => isLoadingTargetMessage = false);
      if (canSetState) Snack.warning('Could not load message');
    }
  }

  Future<void> loadJumpOlderMessages() async {
    if (isLoadingJumpOlder || !jumpHasOlderMessages || !isInJumpMode) return;
    if (!canSetState) return;
    safeSetState(() => isLoadingJumpOlder = true);
    try {
      final result = await chatApiService.chat.getConversationHistory(
        conversationId: conversationId,
        beforeMessageId: jumpMessages.first.id,
        limit: 50,
      );
      if (!canSetState || !isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isNotEmpty) {
          safeSetState(() {
            final existingIds = jumpMessages.map((m) => m.id).toSet();
            final newMessages = history.messages
                .where((m) => !existingIds.contains(m.id))
                .toList();
            jumpMessages = [...newMessages, ...jumpMessages];
            if (jumpMessages.length > _jumpWindowSize) {
              final excess = jumpMessages.length - _jumpWindowSize;
              jumpMessages = jumpMessages.sublist(
                0,
                jumpMessages.length - excess,
              );
              jumpHasNewerMessages = true;
            }
            jumpHasOlderMessages = history.hasMore;
          });
        } else {
          safeSetState(() => jumpHasOlderMessages = false);
        }
      }
    } catch (e) {
      debugPrint('$scrollDebugPrefix loadJumpOlderMessages: $e');
    } finally {
      if (canSetState) safeSetState(() => isLoadingJumpOlder = false);
    }
  }

  Future<void> loadJumpNewerMessages() async {
    if (isLoadingJumpNewer || !jumpHasNewerMessages || !isInJumpMode) return;
    if (!canSetState) return;
    safeSetState(() => isLoadingJumpNewer = true);
    try {
      final result = await chatApiService.chat.getConversationHistory(
        conversationId: conversationId,
        afterMessageId: jumpMessages.last.id,
        limit: 50,
      );
      if (!canSetState || !isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isEmpty || !history.hasMore) {
          safeSetState(() => isLoadingJumpNewer = false);
          exitJumpMode();
          return;
        }
        safeSetState(() {
          final existingIds = jumpMessages.map((m) => m.id).toSet();
          final newMessages = history.messages
              .where((m) => !existingIds.contains(m.id))
              .toList();
          jumpMessages = [...jumpMessages, ...newMessages];
          if (jumpMessages.length > _jumpWindowSize) {
            final excess = jumpMessages.length - _jumpWindowSize;
            jumpMessages = jumpMessages.sublist(excess);
            jumpHasOlderMessages = true;
          }
          jumpHasNewerMessages = history.hasMore;
        });
      }
    } catch (e) {
      debugPrint('$scrollDebugPrefix loadJumpNewerMessages: $e');
    } finally {
      if (canSetState) safeSetState(() => isLoadingJumpNewer = false);
    }
  }

  void exitJumpMode() {
    if (!canSetState) return;
    safeSetState(() {
      isInJumpMode = false;
      jumpMessages = [];
      jumpHasOlderMessages = true;
      jumpHasNewerMessages = true;
      isLoadingJumpOlder = false;
      isLoadingJumpNewer = false;
      highlightedMessageId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (canSetState && scrollController.hasClients) scrollToBottom();
    });
    // Temporary fix to ensure scroll-to-bottom completes after jump-mode exit.
    Timer(const Duration(milliseconds: 800), scrollToBottom);
  }

  void animateNewMessage(String messageId) {
    if (animatedMessages.contains(messageId)) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    messageAnimationControllers[messageId] = controller;
    messageSlideAnimations[messageId] = slideAnimation;
    messageFadeAnimations[messageId] = fadeAnimation;
    animatedMessages.add(messageId);

    controller.forward().then((_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (messageAnimationControllers.containsKey(messageId)) {
          messageAnimationControllers[messageId]?.dispose();
          messageAnimationControllers.remove(messageId);
          messageSlideAnimations.remove(messageId);
          messageFadeAnimations.remove(messageId);
        }
      });
    });
  }

  void disposeScroll() {
    draftSaveTimer?.cancel();
    scrollDebounceTimer?.cancel();
    highlightTimer?.cancel();
    for (final controller in messageAnimationControllers.values) {
      controller.dispose();
    }
    messageAnimationControllers.clear();
    messageSlideAnimations.clear();
    messageFadeAnimations.clear();
    animatedMessages.clear();
    currentStickyDate.dispose();
    showStickyDate.dispose();
  }
}
