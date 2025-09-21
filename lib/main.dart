import 'package:flutter/material.dart' as material;
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/cookie_service.dart';
import 'services/websocket_service.dart';
// import 'api/api_service.dart';

void main() async {
  material.WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final cookieService = CookieService();
  await cookieService.init();

  // Initialize WebSocket service (will be used in MyApp widget)
  WebSocketService();

  // Initialize API service (which uses the cookie service)
  // final apiService = ApiService();

  material.runApp(MyApp());
}

class MyApp extends material.StatefulWidget {
  @override
  material.State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends material.State<MyApp> {
  final AuthService _authService = AuthService();
  final WebSocketService _websocketService = WebSocketService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _setupWebSocketListeners();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuthenticated;
      _isLoading = false;
    });

    // Connect to WebSocket if user is authenticated
    if (isAuthenticated) {
      // Then try to connect
      await _websocketService.connect();
    }
  }

  void _setupWebSocketListeners() {
    // Listen to WebSocket connection state changes
    _websocketService.connectionStateStream.listen((state) {
      // WebSocket state changed
    });

    // Listen to WebSocket messages
    _websocketService.messageStream.listen((message) {
      // Handle incoming messages here
    });

    // Listen to WebSocket errors
    _websocketService.errorStream.listen((error) {
      // Handle errors here
    });
  }

  @override
  void dispose() {
    _websocketService.dispose();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.MaterialApp(
      title: 'Amigo Chat App',
      theme: material.ThemeData(
        primarySwatch: material.Colors.blue,
        visualDensity: material.VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: _isLoading
          ? _buildLoadingScreen()
          : _isAuthenticated
          ? MainScreen()
          : LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  material.Widget _buildLoadingScreen() {
    return material.Scaffold(
      body: material.Center(child: material.CircularProgressIndicator()),
    );
  }
}
