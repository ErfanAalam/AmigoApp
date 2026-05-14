import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/chat-background.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../ui/chat/chat-pills.widget.dart';
import '../../../ui/chat/pinned-message.widget.dart';
import '../../../ui/chat/scroll-to-bottom.button.dart';
import 'chat-actions.mixin.dart';
import 'chat-bubble.mixin.dart';
import 'chat-scroll.mixin.dart';
import 'chat-search.mixin.dart';
import 'chat-sync.mixin.dart';

/// The chat-screen scaffold shared by DM and group messaging screens — the
/// `Scaffold` + `AppBar` + body `Stack` (background, pinned header, messages
/// list, sticky date, sync/loading/jump pills, scroll-to-bottom, return-to-
/// latest, message input). Hosts plug in only the parts that genuinely
/// differ: the AppBar title widget, the non-selection AppBar actions, and
/// the message input widget.
mixin ChatShellMixin<T extends ConsumerStatefulWidget>
    on
        ConsumerState<T>,
        ChatActionsMixin<T>,
        ChatScrollMixin<T>,
        ChatSearchMixin<T>,
        ChatSyncMixin<T>,
        ChatBubbleMixin<T> {
  /// Optional `AppBar.titleSpacing` override. DMs use 0 so the avatar sits
  /// flush with the leading icon; groups use the Material default.
  double? get appBarTitleSpacing => null;

  Widget buildChatScaffold({
    required Widget appBarTitle,
    required List<Widget> nonSelectionActions,
    required List<Widget> selectionModeActions,
    required Widget messageInput,
  }) {
    final themeColor = ref.watch(themeColorProvider);
    final customBgPath = ref.watch(chatBackgroundProvider);
    final inSelection = selectedMessages.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            inSelection ? Icons.close : Icons.arrow_back_rounded,
            color: Colors.black,
          ),
          onPressed: inSelection
              ? exitSelectionMode
              : () => Navigator.pop(context),
        ),
        title: isSearchMode
            ? buildSearchBar(themeColor)
            : inSelection
            ? Text(
                '${selectedMessages.length} selected',
                style: TextStyle(
                  color: themeColor.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : appBarTitle,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleSpacing: appBarTitleSpacing,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: inSelection ? selectionModeActions : nonSelectionActions,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image:
                        (customBgPath != null &&
                            File(customBgPath).existsSync())
                        ? FileImage(File(customBgPath)) as ImageProvider
                        : const AssetImage('assets/images/chat_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.white.withAlpha(100)),
            ),
            Column(
              children: [
                if (pinnedMessage != null && pinnedMessage!.id.isNotEmpty)
                  PinnedMessageSection(
                    pinnedMessage: messages.firstWhere(
                      (m) => m.id == pinnedMessage?.id,
                      orElse: () => pinnedMessage!,
                    ),
                    currentUserId: currentUserId,
                    onTap: () => scrollToMessage(pinnedMessage?.id ?? ''),
                    onUnpin: () => togglePinMessage(pinnedMessage!),
                  ),
                Expanded(child: buildMessagesList()),
                messageInput,
              ],
            ),
            if (isLoadingTargetMessage)
              const Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: LoadingTargetPill(),
              ),
            if (isSyncingMessages && !isLoadingTargetMessage)
              const Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: SyncProgressPill(),
              ),
            Positioned(
              top: (isSyncingMessages || isLoadingTargetMessage || isInJumpMode)
                  ? 54
                  : 10,
              left: 0,
              right: 0,
              child: buildStickyDateSeparator(),
            ),
            Positioned(
              right: 16,
              bottom: replyToMessageData != null ? 150.0 : 110.0,
              child: ScrollToBottomButton(
                scrollController: scrollController,
                onTap: handleScrollToBottomTap,
                isAtBottom: isAtBottom,
                bottomPadding: 0.0,
              ),
            ),
            if (isInJumpMode)
              Positioned(
                top: (isSyncingMessages || isLoadingTargetMessage) ? 54 : 10,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: exitJumpMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Return to latest',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
