enum ConversationType { dm, group, communityGroup }

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Method to synchronize chat data
  Future<void> synchronizeChatData(
    ConversationType conversationType,
    int conversationId,
  ) async {}
}
