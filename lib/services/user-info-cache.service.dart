import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/db/repositories/conversation-member.repo.dart';
import 'package:amigo/models/user.model.dart';

class _CachedUser {
  final UserModel user;
  final DateTime cachedAt;
  _CachedUser(this.user) : cachedAt = DateTime.now();
}

class UserInfoCache {
  UserInfoCache._();
  static final instance = UserInfoCache._();

  final Map<String, _CachedUser> _cache = {};
  static const _ttlMs = 10000;

  final _userRepo = UserRepository();
  final _memberRepo = ConversationMemberRepository();

  Future<void> loadChatMembers(String chatId) async {
    final members = await _memberRepo.getMembersByConversationId(chatId);
    for (final member in members) {
      final user = await _userRepo.getUserById(member.userId);
      if (user != null) {
        _cache[user.id] = _CachedUser(user);
      }
    }
  }

  Future<UserModel?> getUser(String userId) async {
    final cached = _cache[userId];
    if (cached != null) {
      final age = DateTime.now().difference(cached.cachedAt).inMilliseconds;
      if (age < _ttlMs) return cached.user;
    }
    final user = await _userRepo.getUserById(userId);
    if (user != null) {
      _cache[userId] = _CachedUser(user);
    }
    return user;
  }

  void setUser(UserModel user) {
    _cache[user.id] = _CachedUser(user);
  }

  void clear() => _cache.clear();
}
