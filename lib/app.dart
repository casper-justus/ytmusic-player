import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'screens/local_files_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/album_detail_screen.dart';
import 'screens/login_screen.dart';
import 'models/playlist_item.dart';
import 'models/album.dart';

/// Root widget of the YTMusic Player app.
///
/// Sets up:
/// - Material 3 design with dynamic color scheme
/// - Theme based on user preference (light/dark/amoled)
/// - Named routes for all screens
/// - Bottom navigation for primary sections
class YTMusicPlayerApp extends ConsumerWidget {
  const YTMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = _resolveThemeMode(settings.themeMode);
    final isAmoled = settings.themeMode == ThemeModeOption.black;

    return MaterialApp(
      title: 'YTMusic Player',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // Light theme
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),

      // Dark theme — with optional AMOLED overrides
      darkTheme: isAmoled ? _buildAmoledTheme() : _buildDarkTheme(),

      // Route-based screen navigation
      onGenerateRoute: _onGenerateRoute,

      // Home is the primary entry point with bottom nav
      home: const MainShell(),
    );
  }

  ThemeMode _resolveThemeMode(ThemeModeOption option) {
    switch (option) {
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
      case ThemeModeOption.black:
        return ThemeMode.dark;
    }
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blueGrey,
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildAmoledTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blueGrey,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.black,
      ),
      cardTheme: const CardThemeData(color: Color(0xFF121212)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black,
        indicatorColor: Colors.grey[800],
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings routeSettings) {
    // Handle named routes for full-screen pages
    switch (routeSettings.name) {
      case '/player':
        return MaterialPageRoute(
          builder: (_) => const PlayerScreen(),
          settings: routeSettings,
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: routeSettings,
        );
      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: routeSettings,
        );
      // Playlist detail — receives a PlaylistItem as argument
      case '/playlist':
        final playlist = routeSettings.arguments;
        if (playlist is PlaylistItem) {
          return MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
            settings: routeSettings,
          );
        }
        return null;

      // Album detail — receives an Album as argument
      case '/album':
        final album = routeSettings.arguments;
        if (album is Album) {
          return MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
            settings: routeSettings,
          );
        }
        return null;

      default:
        return null;
    }
  }
}

/// Primary scaffold with bottom navigation for the main sections.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    LocalFilesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
        ],
      ),
    );
  }
}
