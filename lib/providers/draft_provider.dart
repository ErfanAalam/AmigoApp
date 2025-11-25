import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/draft_message_service.dart';

/// Riverpod provider for draft messages state
/// Maps conversationId -> draft text
final draftMessagesProvider =
    NotifierProvider<DraftMessagesNotifier, Map<int, String>>(() {
  return DraftMessagesNotifier();
});

class DraftMessagesNotifier extends Notifier<Map<int, String>> {
  final DraftMessageService _draftService = DraftMessageService();

  @override
  Map<int, String> build() {
    // Load drafts asynchronously
    Future.microtask(() => _loadDrafts());
    return {};
  }

  /// Load all drafts from storage
  Future<void> _loadDrafts() async {
    final drafts = await _draftService.getAllDrafts();
    if (drafts.isNotEmpty) {
      state = drafts;
    }
  }

  /// Save draft for a conversation
  Future<void> saveDraft(int conversationId, String draftText) async {
    await _draftService.saveDraft(conversationId, draftText);
    
    if (draftText.trim().isEmpty) {
      // Remove from state if empty
      final newState = Map<int, String>.from(state);
      newState.remove(conversationId);
      state = newState;
    } else {
      // Update state
      state = {...state, conversationId: draftText};
    }
  }

  /// Remove draft for a conversation
  Future<void> removeDraft(int conversationId) async {
    await _draftService.removeDraft(conversationId);
    final newState = Map<int, String>.from(state);
    newState.remove(conversationId);
    state = newState;
  }

  /// Get draft for a conversation
  String? getDraft(int conversationId) {
    return state[conversationId];
  }

  /// Clear all drafts (used during logout)
  void clearAllDrafts() {
    state = {};
  }
}

