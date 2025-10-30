import 'package:flutter/material.dart';
import 'chat/dm/dm_list.dart';
import 'chat/group/group_list.dart';
import 'contact/contact_list.dart';
import 'profile/profile_info.dart';
import 'call/call_logs.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentPageIndex = 0;
  final GlobalKey<ChatsPageState> _chatsPageKey = GlobalKey<ChatsPageState>();
  final GlobalKey<CallsPageState> _callsPageKey = GlobalKey<CallsPageState>();

  late final PageController _pageController;

  // List of pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);

    _pages = [
      ChatsPage(key: _chatsPageKey),
      GroupsPage(),
      ContactsPage(),
      CallsPage(key: _callsPageKey),
      ProfilePage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPageIndex == 0) {
        _chatsPageKey.currentState?.onPageVisible();
      }
    });
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
    } else if (index == 3) {
      _callsPageKey.currentState?.onPageVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          } else if (index == 3) {
            _callsPageKey.currentState?.onPageVisible();
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
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.message, color: Colors.teal),
            icon: Icon(
              Icons.message_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.group, color: Colors.teal),
            icon: Icon(
              Icons.group_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Groups',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.contacts_rounded, color: Colors.teal),
            icon: Icon(
              Icons.contacts_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Contacts',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.call, color: Colors.teal),
            icon: Icon(
              Icons.call_outlined,
              color: Color.fromARGB(255, 65, 64, 64),
            ),
            label: 'Calls',
          ),
          NavigationDestination(
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
