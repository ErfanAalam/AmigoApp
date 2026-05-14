import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app-colors.config.dart';
import '../../../models/message.model.dart';
import '../../../types/socket.types.dart';

/// Shared search/recommendation logic for DM and group messaging screens.
///
/// The mixin owns search state (mode, query, matches, highlight ids, focus).
/// Host state classes provide the message list, controllers, and the
/// `safeSetState` / `scrollToMessage` / `sendMessage` / `canSetState` hooks.
mixin ChatSearchMixin<T extends StatefulWidget> on State<T> {
  bool isSearchMode = false;
  final TextEditingController searchController = TextEditingController();
  List<String> searchMatches = [];
  int currentMatchIndex = -1;
  Timer? searchDebounceTimer;

  String? highlightedMessageId;
  Set<String> highlightedMessageIds = {};

  bool isInputFocused = false;

  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;
  TextEditingController get messageController;
  FocusNode get messageFocusNode;
  Future<void> scrollToMessage(String messageId);
  void sendMessage(MessageType type);

  void toggleSearchMode() {
    safeSetState(() {
      isSearchMode = !isSearchMode;
      if (!isSearchMode) {
        searchController.clear();
        searchMatches.clear();
        currentMatchIndex = -1;
        highlightedMessageId = null;
        highlightedMessageIds.clear();
      }
    });
  }

  void onSearchTextChanged() {
    searchDebounceTimer?.cancel();
    searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch();
    });
  }

  void onInputFocusChange() {
    if (!canSetState) return;
    safeSetState(() {
      isInputFocused = messageFocusNode.hasFocus;
    });
  }

  void onRecommendationTap(String recommendation) {
    if (!canSetState) return;
    messageController.text = recommendation;
    sendMessage(MessageType.text);
  }

  void performSearch() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      safeSetState(() {
        searchMatches.clear();
        currentMatchIndex = -1;
        highlightedMessageId = null;
        highlightedMessageIds.clear();
      });
      return;
    }

    final matches = <String>[];
    for (final message in messages) {
      if (message.isDeleted) continue;
      if (message.body != null && message.body!.toLowerCase().contains(query)) {
        matches.add(message.id);
      }
    }

    safeSetState(() {
      searchMatches = matches;
      highlightedMessageIds = matches.toSet();
      if (matches.isNotEmpty) {
        currentMatchIndex = 0;
        navigateToMatch(0);
      } else {
        currentMatchIndex = -1;
        highlightedMessageId = null;
      }
    });
  }

  void navigateToMatch(int index) {
    if (index < 0 || index >= searchMatches.length) return;

    final messageId = searchMatches[index];
    safeSetState(() {
      currentMatchIndex = index;
      highlightedMessageId = messageId;
    });

    scrollToMessage(messageId);
  }

  void navigateToNextMatch() {
    if (searchMatches.isEmpty) return;
    final nextIndex = (currentMatchIndex + 1) % searchMatches.length;
    navigateToMatch(nextIndex);
  }

  void navigateToPreviousMatch() {
    if (searchMatches.isEmpty) return;
    final prevIndex = currentMatchIndex <= 0
        ? searchMatches.length - 1
        : currentMatchIndex - 1;
    navigateToMatch(prevIndex);
  }

  Widget buildSearchBar(ColorTheme themeColor) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: searchController,
      builder: (context, searchValue, child) {
        final hasText = searchValue.text.isNotEmpty;
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300, width: 0.6),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search messages...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) {
                    if (searchMatches.isNotEmpty) {
                      navigateToNextMatch();
                    }
                  },
                ),
              ),
              if (hasText) ...[
                if (searchMatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${currentMatchIndex + 1}/${searchMatches.length}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: searchMatches.isNotEmpty
                      ? navigateToPreviousMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 20,
                    color: searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: searchMatches.isNotEmpty
                      ? navigateToNextMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: toggleSearchMode,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  void disposeSearch() {
    searchController.dispose();
    searchDebounceTimer?.cancel();
  }
}
