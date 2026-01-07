import 'package:amigo/providers/call.provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/user.api-client.dart';
import '../models/user.model.dart';
import '../providers/chat.provider.dart';
import '../providers/notification-badge.provider.dart';
import '../providers/theme-color.provider.dart';
import '../ui/badge.widget.dart';
import '../ui/call/call-bar.widget.dart';
import '../utils/user.utils.dart';
import 'call/call-logs.screen.dart';
import 'chat/dm/dm-list.screen.dart';
import 'chat/group/group-list.screen.dart';
import 'contact/contact-list.screen.dart';
import 'profile/profile-info.screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentPageIndex = 0;
  final GlobalKey<ChatsPageState> _chatsPageKey = GlobalKey<ChatsPageState>();
  final GlobalKey<GroupsPageState> _groupsPageKey =
      GlobalKey<GroupsPageState>();
  final GlobalKey<CallsPageState> _callsPageKey = GlobalKey<CallsPageState>();
  final UserService _userService = UserService();

  late final PageController _pageController;

  // List of pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);

    _pages = [
      ChatsPage(key: _chatsPageKey),
      GroupsPage(key: _groupsPageKey),
      ContactsPage(),
      CallsPage(key: _callsPageKey),
      ProfilePage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPageIndex == 0) {
        _chatsPageKey.currentState?.onPageVisible();
      } else if (_currentPageIndex == 1) {
        _groupsPageKey.currentState?.onPageVisible();
      }
    });

    _loadUserDetails();
  }

  void _loadUserDetails() async {
    // Implement user details loading logic here

    final currentUser = await UserUtils().getUserDetails();

    if (currentUser == null) {
      final response = await _userService.getUser();
      if (response['success'] == true) {
        final userDetail = {
          'id': response['data']['id'],
          'name': response['data']['name'],
          'phone': response['data']['phone'],
          'role': response['data']['role'],
          'profile_pic': response['data']['profile_pic'],
          'created_at': response['data']['created_at'],
          'call_access': response['data']['call_access'],
        };

        await UserUtils().saveUserDetails(UserModel.fromJson(userDetail));
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    // Use jumpToPage for immediate navigation when clicking tabs
    // This prevents showing intermediate pages during navigation
    _pageController.jumpToPage(index);

    if (index == 0) {
      _chatsPageKey.currentState?.onPageVisible();
    } else if (index == 1) {
      _groupsPageKey.currentState?.onPageVisible();
    } else if (index == 3) {
      _callsPageKey.currentState?.onPageVisible();
      // Mark calls as seen when call screen is viewed
      // ref.read(notificationBadgeProvider.notifier).markCallsAsSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeState = ref.watch(notificationBadgeProvider);
    final unreadDMs = ref.watch(chatProvider).unreadDmCount;
    final unreadGroups = ref.watch(chatProvider).unreadGroupCount;
    final themeColor = ref.watch(themeColorProvider);
    final callProvider = ref.read(callServiceProvider.notifier);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        // We'll use a Container to set the SafeArea background color.
        child: Container(
          color: callProvider.hasActiveCall
              ? Colors.green.shade600
              : themeColor.primary, // Otherwise, theme's top color
          child: SafeArea(child: const GlobalCallBar()),
        ),
      ),
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });

          if (index == 0) {
            _chatsPageKey.currentState?.onPageVisible();
          } else if (index == 1) {
            _groupsPageKey.currentState?.onPageVisible();
          } else if (index == 3) {
            _callsPageKey.currentState?.onPageVisible();
            // Mark calls as seen when call screen is viewed
            // ref.read(notificationBadgeProvider.notifier).markCallsAsSeen();
          }
        },
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onTabSelected,
        indicatorColor: themeColor.primary.withAlpha(20),
        selectedIndex: _currentPageIndex,
        backgroundColor: Colors.grey[100],
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: BadgeWidget(
              count: unreadDMs,
              child: Icon(Icons.message, color: themeColor.primary),
            ),
            icon: BadgeWidget(
              count: unreadDMs,
              child: const Icon(
                Icons.message_outlined,
                color: Color.fromARGB(255, 65, 64, 64),
              ),
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            selectedIcon: BadgeWidget(
              count: unreadGroups,
              child: Icon(Icons.group, color: themeColor.primary),
            ),
            icon: BadgeWidget(
              count: unreadGroups,
              child: const Icon(
                Icons.group_outlined,
                color: Color.fromARGB(255, 65, 64, 64),
              ),
            ),
            label: 'Groups',
          ),
          NavigationDestination(
            selectedIcon: Icon(
              Icons.contacts_rounded,
              color: themeColor.primary,
            ),
            icon: const Icon(
              Icons.contacts_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Contacts',
          ),
          NavigationDestination(
            selectedIcon: BadgeWidget(
              count: badgeState.callCount,
              child: Icon(Icons.call, color: themeColor.primary),
            ),
            icon: BadgeWidget(
              count: badgeState.callCount,
              child: const Icon(
                Icons.call_outlined,
                color: Color.fromARGB(255, 65, 64, 64),
              ),
            ),
            label: 'Calls',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded, color: themeColor.primary),
            icon: const Icon(
              Icons.person_outline,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
