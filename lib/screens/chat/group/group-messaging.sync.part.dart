part of 'group-messaging.screen.dart';

// Sync / chat-init plumbing now lives on ChatSyncMixin (loadDraft,
// loadPinnedMessage, initializeChat, loadMoreMessages, syncMessagesFromServer,
// syncMessageStatuses, sortMessagesBySentAt, fetchAndSaveChatMembers,
// disposeSync). Group-specific concerns (`getAllConversationMembers` and
// `_checkRemovedState`) live directly on `_InnerGroupChatPageState`.
//
// This file is intentionally empty and can be removed (along with its
// `part` directive) in a future cleanup.
