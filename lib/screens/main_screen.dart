import 'package:flutter/material.dart';
import 'main_pages/chats_page.dart';
import 'main_pages/groups_page.dart';
import 'main_pages/contacts_page.dart';
import 'main_pages/profile_page.dart';
import 'main_pages/calls_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentPageIndex = 0;
  final GlobalKey<ChatsPageState> _chatsPageKey = GlobalKey<ChatsPageState>();

  // List of pages for bottom navigation
  late final List<Widget> _pages;

  // List of colors for each page
  final List<Color> _pageColors = [
    Colors.teal,
    Colors.teal,
    Colors.teal,
    Colors.teal,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize pages with the ChatsPage having a key
    _pages = [
      ChatsPage(key: _chatsPageKey),
      GroupsPage(),
      ContactsPage(),
      CallsPage(),
      ProfilePage(),
    ];
    
    // Trigger silent refresh for ChatsPage if it's the initial page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPageIndex == 0) {
        _chatsPageKey.currentState?.onPageVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentPageIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
          
          // If navigating to Chats tab (index 0), trigger silent refresh
          if (index == 0) {
            _chatsPageKey.currentState?.onPageVisible();
          }
        },
        indicatorColor: _pageColors[_currentPageIndex].withValues(alpha: 0.2),
        selectedIndex: _currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.message, color: Colors.teal),
            icon: Icon(Icons.message_outlined, color: Colors.grey),
            label: 'Chats',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.group, color: Colors.teal),
            icon: Icon(Icons.group_outlined, color: Colors.grey),
            label: 'Groups',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.contacts_rounded, color: Colors.teal),
            icon: Icon(Icons.contacts_outlined, color: Colors.grey),
            label: 'Contacts',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.call, color: Colors.teal),
            icon: Icon(Icons.call_outlined, color: Colors.grey),
            label: 'Calls',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded, color: Colors.teal),
            icon: Icon(Icons.person_outline, color: Colors.grey),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
