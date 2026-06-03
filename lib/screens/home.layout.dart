import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../models/user.model.dart';
import '../providers/chat.provider.dart';
import '../providers/notification-badge.provider.dart';
import '../providers/rejoinable-call.provider.dart';
import '../providers/theme-color.provider.dart';
import '../services/socket/ws-message.handler.dart';
import '../ui/pulsing-dot.widget.dart';
import '../utils/user.utils.dart';
import 'call/call-logs.screen.dart';
import 'chat/dm/dm-list.screen.dart';
import 'chat/group/group-list.screen.dart';
import 'settings/settings.screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  int _currentPageIndex = 0;
  final GlobalKey<ChatsPageState> _chatsPageKey = GlobalKey<ChatsPageState>();
  final GlobalKey<GroupsPageState> _groupsPageKey =
      GlobalKey<GroupsPageState>();
  final GlobalKey<CallsPageState> _callsPageKey = GlobalKey<CallsPageState>();
  final apiService = ApiService();

  late final PageController _pageController;
  late final List<Widget> _pages;

  // Ghost-call recovery: keep the rejoinable-call provider in sync with the
  // backend's rejoin-window signals (live over WS) + hydrate on open/resume.
  StreamSubscription? _rejoinAvailableSub;
  StreamSubscription? _rejoinExpiredSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentPageIndex);

    _pages = [
      ChatsPage(key: _chatsPageKey),
      GroupsPage(key: _groupsPageKey),
      CallsPage(key: _callsPageKey),
      const SettingsPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPageIndex == 0) {
        _chatsPageKey.currentState?.onPageVisible();
      } else if (_currentPageIndex == 1) {
        _groupsPageKey.currentState?.onPageVisible();
      }
    });

    _wireRejoinSignals();
    _loadUserDetails();
  }

  /// Subscribe to the backend's rejoin-window WS signals and feed them into
  /// the provider; hydrate once now to catch a window opened while we were
  /// away (e.g. killed app reopened within the 10s).
  void _wireRejoinSignals() {
    final handler = WebSocketMessageHandler();
    _rejoinAvailableSub = handler.callRejoinAvailableStream.listen((p) {
      final cid = p.callId;
      final data = p.data;
      if (cid == null || data is! Map) return;
      final peerId = data['peer_id']?.toString();
      final expiresAt = DateTime.tryParse(data['expires_at']?.toString() ?? '');
      if (peerId == null || expiresAt == null) return;
      final peerName = data['peer_name']?.toString();
      ref.read(rejoinableCallProvider.notifier).set(RejoinableCall(
            cid: cid,
            peerId: peerId,
            peerName:
                (peerName != null && peerName.isNotEmpty) ? peerName : 'Unknown',
            peerPfp: data['peer_pfp']?.toString(),
            expiresAt: expiresAt,
          ));
    });
    _rejoinExpiredSub = handler.callRejoinExpiredStream.listen((p) {
      ref.read(rejoinableCallProvider.notifier).clear(cid: p.callId);
    });
    // Cover the missed-push / killed-app case.
    ref.read(rejoinableCallProvider.notifier).hydrateFromBackend();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-hydrate on resume: a rejoin window may have opened (or closed)
      // while we were backgrounded and the live WS push could have been missed.
      ref.read(rejoinableCallProvider.notifier).hydrateFromBackend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rejoinAvailableSub?.cancel();
    _rejoinExpiredSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _loadUserDetails() async {
    final currentUser = await UserUtils().getUserDetails();
    if (currentUser == null) {
      final response = await apiService.user.getUser();
      if (response.isSuccess && response.hasData) {
        final userDetail = {
          'id': response.data!['id'],
          'name': response.data!['name'],
          'phone': response.data!['phone'],
          'role': response.data!['role'],
          'profile_pic': response.data!['profile_pic'],
          'created_at': response.data!['created_at'],
          'call_access': response.data!['call_access'],
        };
        await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentPageIndex = index);
    _pageController.jumpToPage(index);

    if (index == 0) {
      _chatsPageKey.currentState?.onPageVisible();
    } else if (index == 1) {
      _groupsPageKey.currentState?.onPageVisible();
    } else if (index == 2) {
      _callsPageKey.currentState?.onPageVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeState = ref.watch(notificationBadgeProvider);
    final unreadDMs = ref.watch(chatProvider).unreadDmCount;
    final unreadGroups = ref.watch(chatProvider).unreadGroupCount;
    final hasRejoinableCall = ref.watch(rejoinableCallProvider) != null;

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (index) {
          setState(() => _currentPageIndex = index);
          if (index == 0) {
            _chatsPageKey.currentState?.onPageVisible();
          } else if (index == 1) {
            _groupsPageKey.currentState?.onPageVisible();
          } else if (index == 2) {
            _callsPageKey.currentState?.onPageVisible();
          }
        },
      ),
      bottomNavigationBar: FloatingPillNavBar(
        currentIndex: _currentPageIndex,
        onTap: _onTabSelected,
        items: [
          FloatingPillNavItem(
            icon: Icons.message_outlined,
            selectedIcon: Icons.message_rounded,
            label: 'Chats',
            badgeCount: unreadDMs,
          ),
          FloatingPillNavItem(
            icon: Icons.group_outlined,
            selectedIcon: Icons.group_rounded,
            label: 'Groups',
            badgeCount: unreadGroups,
          ),
          FloatingPillNavItem(
            icon: Icons.call_outlined,
            selectedIcon: Icons.call_rounded,
            label: 'Calls',
            badgeCount: badgeState.callCount,
            showDot: hasRejoinableCall,
          ),
          const FloatingPillNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Frosted-glass floating pill bottom navigation bar — Telegram-style.
class FloatingPillNavBar extends ConsumerWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<FloatingPillNavItem> items;

  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 60,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(80),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.black.withAlpha(20), width: 1),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black.withAlpha(10),
                //     blurRadius: 24,
                //     offset: const Offset(2, 8),
                //   ),
                // ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = index == currentIndex;
                  return Expanded(
                    key: ValueKey('nav-${item.label}'),
                    child: _FloatingPillNavButton(
                      key: ValueKey('nav-btn-${item.label}'),
                      item: item,
                      selected: selected,
                      themeColor: themeColor.primary,
                      onTap: () => onTap(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingPillNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;

  /// When true, show a pulsing green dot (no number) instead of/alongside the
  /// count badge — used to flag a rejoinable active call on the Calls tab.
  final bool showDot;

  const FloatingPillNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
    this.showDot = false,
  });
}

class _FloatingPillNavButton extends StatefulWidget {
  final FloatingPillNavItem item;
  final bool selected;
  final Color themeColor;
  final VoidCallback onTap;

  const _FloatingPillNavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.themeColor,
    required this.onTap,
  });

  @override
  State<_FloatingPillNavButton> createState() => _FloatingPillNavButtonState();
}

class _FloatingPillNavButtonState extends State<_FloatingPillNavButton> {
  static const Duration _pressDuration = Duration(milliseconds: 100);
  static const Duration _releaseDuration = Duration(milliseconds: 1500);

  bool _pressed = false;
  bool _locked = false;
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTapDown() {
    if (_locked) return;
    _setPressed(true);
  }

  void _handleTapCancel() {
    if (_locked) return;
    _setPressed(false);
  }

  void _handleTap() {
    if (_locked) return;
    _setPressed(false);
    widget.onTap();
    _locked = true;
    _lockTimer?.cancel();
    _lockTimer = Timer(_releaseDuration, () {
      if (!mounted) return;
      setState(() => _locked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.themeColor : const Color(0xFF6E6E73);
    final count = widget.item.badgeCount ?? 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTapDown(),
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: _pressed ? _pressDuration : _releaseDuration,
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: Container(
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.themeColor.withAlpha(15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.selected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    color: color,
                    size: 22,
                  ),
                  if (count > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: widget.themeColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  // Pulsing green dot for a rejoinable active call (no count).
                  else if (widget.item.showDot)
                    const Positioned(
                      right: -6,
                      top: -2,
                      child: PulsingDot(size: 10),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
