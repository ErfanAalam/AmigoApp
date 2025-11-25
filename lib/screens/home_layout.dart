import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/user.service.dart';
import '../models/user_model.dart';
import '../utils/user.utils.dart';
import 'chat/dm/dm_list.dart';
import 'chat/group/group_list.dart';
import 'contact/contact_list.dart';
import 'profile/profile_info.dart';
import 'call/call_logs.dart';
import '../widgets/badge_widget.dart';
import '../providers/notification_badge_provider.dart';

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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    if (index == 0) {
      _chatsPageKey.currentState?.onPageVisible();
    } else if (index == 1) {
      _groupsPageKey.currentState?.onPageVisible();
    } else if (index == 3) {
      _callsPageKey.currentState?.onPageVisible();
      // Mark calls as seen when call screen is viewed
      ref.read(notificationBadgeProvider.notifier).markCallsAsSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeState = ref.watch(notificationBadgeProvider);

    return Scaffold(
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
            ref.read(notificationBadgeProvider.notifier).markCallsAsSeen();
          }
        },
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onTabSelected,
        indicatorColor: Colors.teal.withAlpha(20),
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
              count: badgeState.chatCount,
              child: const Icon(Icons.message, color: Colors.teal),
            ),
            icon: BadgeWidget(
              count: badgeState.chatCount,
              child: const Icon(
                Icons.message_outlined,
                color: Color.fromARGB(255, 65, 64, 64),
              ),
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            selectedIcon: BadgeWidget(
              count: badgeState.groupCount,
              child: const Icon(Icons.group, color: Colors.teal),
            ),
            icon: BadgeWidget(
              count: badgeState.groupCount,
              child: const Icon(
                Icons.group_outlined,
                color: Color.fromARGB(255, 65, 64, 64),
              ),
            ),
            label: 'Groups',
          ),
          const NavigationDestination(
            selectedIcon: Icon(Icons.contacts_rounded, color: Colors.teal),
            icon: Icon(
              Icons.contacts_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Contacts',
          ),
          NavigationDestination(
            selectedIcon: BadgeWidget(
              count: badgeState.callCount,
              child: const Icon(Icons.call, color: Colors.teal),
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
          const NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded, color: Colors.teal),
            icon: Icon(
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
