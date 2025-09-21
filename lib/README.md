# Amigo Chat App - Project Structure

This Flutter chat app follows a clean folder structure for better organization and maintainability.

## Folder Structure

```
lib/
├── main.dart                 # Entry point of the app
├── screens/                  # All screen files
│   ├── auth/                # Authentication screens
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── main_pages/          # Main app pages (bottom navigation)
│   │   ├── chats_page.dart
│   │   ├── groups_page.dart
│   │   ├── contacts_page.dart
│   │   └── profile_page.dart
│   └── main_screen.dart     # Main screen with bottom navigation
├── widgets/                 # Reusable UI components
├── models/                  # Data models
└── services/               # Business logic and API calls
```

## How the App Works

### 1. App Flow
- **Start**: App starts with `LoginScreen`
- **Authentication**: Users can switch between Login and SignUp screens
- **Main App**: After login, users see `MainScreen` with bottom navigation
- **Navigation**: Users can navigate between 4 main pages using bottom navigation

### 2. Screen Descriptions

#### Authentication Screens (`screens/auth/`)
- **LoginScreen**: User login with email and password
- **SignUpScreen**: User registration with name, email, and password

#### Main Pages (`screens/main_pages/`)
- **ChatsPage**: List of individual chats with search functionality
- **GroupsPage**: List of group chats with member count
- **ContactsPage**: List of contacts with online status
- **ProfilePage**: User profile with settings and options

#### Main Screen (`screens/main_screen.dart`)
- Contains bottom navigation bar
- Manages page switching
- Uses `IndexedStack` to maintain page state

### 3. Key Features

#### Bottom Navigation
- 4 tabs: Chats, Groups, Contacts, Profile
- Each tab has a different color theme
- Maintains state when switching between tabs

#### UI Components
- Modern Material Design 3
- Consistent color scheme
- Responsive design
- Search functionality on each page
- Floating action buttons where appropriate

### 4. Navigation Flow
```
LoginScreen → MainScreen
     ↓
SignUpScreen → LoginScreen (back button)
     ↓
MainScreen → Bottom Navigation → Individual Pages
```

### 5. Future Enhancements
- Add actual authentication logic
- Implement real-time messaging
- Add database integration
- Implement push notifications
- Add file sharing capabilities

## Getting Started

1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to start the app
3. The app will start with the login screen
4. Use any credentials to navigate to the main app
5. Explore different pages using bottom navigation

## For Beginners

This structure helps you understand:
- How to organize Flutter code
- How navigation works in Flutter
- How to create reusable UI components
- How to manage app state
- How to implement Material Design

Each screen is self-contained and can be modified independently without affecting other parts of the app.
