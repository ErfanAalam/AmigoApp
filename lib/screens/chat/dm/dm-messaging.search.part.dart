part of 'dm-messaging.screen.dart';

extension _DmSearch on _InnerChatPageState {
  void _toggleSearchMode() {
    _safeSetState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        // Clear search when exiting
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  void _onSearchTextChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  void _onInputFocusChange() {
    if (!_canSetState) return;
    _safeSetState(() {
      _isInputFocused = _messageFocusNode.hasFocus;
    });
  }

  void _onRecommendationTap(String recommendation) {
    if (!_canSetState) return;

    // Set the message text
    _messageController.text = recommendation;

    // Send the message
    _sendMessage(MessageType.text);

    // Keep keyboard open - don't unfocus
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _safeSetState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
        _highlightedMessageIds.clear();
      });
      return;
    }

    // Search in loaded messages
    final matches = <String>[];
    for (final message in _messages) {
      if (message.isDeleted) continue;

      // Search in message body
      if (message.body != null && message.body!.toLowerCase().contains(query)) {
        matches.add(message.id);
      }
    }

    _safeSetState(() {
      _searchMatches = matches;
      _highlightedMessageIds = matches.toSet(); // Highlight all matches
      if (matches.isNotEmpty) {
        _currentMatchIndex = 0;
        _navigateToMatch(0);
      } else {
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  void _navigateToMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return;

    final messageId = _searchMatches[index];
    _safeSetState(() {
      _currentMatchIndex = index;
      _highlightedMessageId = messageId;
    });

    // Scroll to message
    _scrollToMessage(messageId);

    // Note: We don't remove the highlight anymore - all matches stay highlighted
    // Only the current match gets a brighter highlight
  }

  void _navigateToNextMatch() {
    if (_searchMatches.isEmpty) return;
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    _navigateToMatch(nextIndex);
  }

  void _navigateToPreviousMatch() {
    if (_searchMatches.isEmpty) return;
    final prevIndex = _currentMatchIndex <= 0
        ? _searchMatches.length - 1
        : _currentMatchIndex - 1;
    _navigateToMatch(prevIndex);
  }

  Widget _buildSearchBar(ColorTheme themeColor) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, searchValue, child) {
        final hasText = searchValue.text.isNotEmpty;
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
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
                    if (_searchMatches.isNotEmpty) {
                      _navigateToNextMatch();
                    }
                  },
                ),
              ),
              if (hasText) ...[
                // Match counter
                if (_searchMatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_currentMatchIndex + 1}/${_searchMatches.length}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Previous match button
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: _searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: _searchMatches.isNotEmpty
                      ? _navigateToPreviousMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // Next match button
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 20,
                    color: _searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: _searchMatches.isNotEmpty
                      ? _navigateToNextMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
              // Close search button
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: _toggleSearchMode,
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
}
