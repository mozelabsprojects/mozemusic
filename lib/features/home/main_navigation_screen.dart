import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import '../library/library_screen.dart';
import '../jam_room/jam_room_screen.dart';
import '../player/mini_player.dart';
import '../player/widgets/cross_device_handoff_banner.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const LibraryScreen(),
    const JamRoomScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Cross-device Handoff Banner overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 74,
            child: const CrossDeviceHandoffBanner(isDesktop: false),
          ),

          // Mini Player overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 6,
            child: const MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor?.withValues(alpha: 0.6) ?? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
            selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: loc.get('home')),
            BottomNavigationBarItem(icon: const Icon(Icons.search), label: loc.get('search')),
            BottomNavigationBarItem(icon: const Icon(Icons.library_music), label: loc.get('library')),
            BottomNavigationBarItem(icon: const Icon(Icons.graphic_eq), label: loc.get('jam_room')),
          ],
        ),
      ),
      ),
    );
  }
}
