import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/find_help_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/map_screen.dart';
import 'screens/mesh_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'services/profile_storage_service.dart';

class BlackoutPragueApp extends StatelessWidget {
  const BlackoutPragueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blackout Prague',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        cardTheme: CardThemeData(
          color: const Color(0xFF171A20),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF30343B)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFF12161D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0D10),
          foregroundColor: Color(0xFFF5F7FA),
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF111318),
          indicatorColor: const Color(0xFF7F1D1D),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? const Color(0xFFFFFFFF) : const Color(0xFFC4C7CC),
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(height: 1.35),
          bodyMedium: TextStyle(height: 1.35),
        ),
      ),
      home: const _StartupScreen(),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ProfileStorageService().isOnboardingCompleted(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data ?? false) {
          return const BlackoutPragueShell();
        }

        return const OnboardingScreen(completedScreen: BlackoutPragueShell());
      },
    );
  }
}

class BlackoutPragueShell extends StatefulWidget {
  const BlackoutPragueShell({super.key});

  @override
  State<BlackoutPragueShell> createState() => _BlackoutPragueShellState();
}

class _BlackoutPragueShellState extends State<BlackoutPragueShell> {
  int _selectedIndex = 0;
  String? _selectedMapHelpPointId;
  int _mapFocusNonce = 0;

  static const _titles = <String>['Domů', 'Mapa', 'Pomoc', 'Návody', 'Mesh'];


  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == 0 ? 'Blackout Prague' : _titles[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
            },
          ),
          IconButton(
            tooltip: 'Nastavení',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            onOpenFindHelp: () => _selectTab(2),
            onOpenGuides: () => _selectTab(3),
          ),
          MapScreen(selectedHelpPointId: _selectedMapHelpPointId, focusNonce: _mapFocusNonce),
          FindHelpScreen(onShowHelpPointOnMap: _openHelpPointOnMap),
          const GuideScreen(),
          const MeshScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Domů'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services), label: 'Pomoc'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Návody'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Mesh'),
        ],
      ),
    );
  }

  void _openHelpPointOnMap(String helpPointId) {
    setState(() {
      _selectedMapHelpPointId = helpPointId;
      _mapFocusNonce++;
      _selectedIndex = 1;
    });
  }
void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }
}
