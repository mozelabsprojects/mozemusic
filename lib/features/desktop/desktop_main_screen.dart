import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/desktop_sidebar.dart';
import 'components/desktop_player_bar.dart';
import 'components/desktop_header.dart';
import 'components/desktop_queue_panel.dart';
import 'components/desktop_lyrics_panel.dart';
import '../player/widgets/cross_device_handoff_banner.dart';
import '../../services/audio_handler.dart';
import '../home/home_screen.dart';
import '../home/search_screen.dart';
import '../library/library_screen.dart';
import '../jam_room/jam_room_screen.dart';

class DesktopMainScreen extends ConsumerWidget {
  const DesktopMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(desktopNavIndexProvider);
    final showQueue = ref.watch(desktopQueueVisibleProvider);
    final showLyrics = ref.watch(desktopLyricsVisibleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const LibraryScreen(),
      const JamRoomScreen(),
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Disable shortcuts on Search screen (navIndex == 1)
        if (navIndex == 1) {
          return KeyEventResult.ignored;
        }

        // Ignore shortcuts if the user is typing in any text field
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null) {
          final ctx = primaryFocus.context;
          if (ctx != null) {
            final isTextInput = ctx.widget is EditableText ||
                ctx.widget is TextField ||
                ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
                ctx.findAncestorWidgetOfExactType<TextField>() != null ||
                ctx.findAncestorStateOfType<EditableTextState>() != null;
            if (isTextInput) {
              return KeyEventResult.ignored;
            }
          }
          final debugLabel = (primaryFocus.debugLabel ?? '').toLowerCase();
          if (debugLabel.contains('editable') || debugLabel.contains('text')) {
            return KeyEventResult.ignored;
          }
        }

        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final key = event.logicalKey;
        final handler = ref.read(audioHandlerProvider);

        if (key == LogicalKeyboardKey.space) {
          final isPlaying = handler.playbackState.value.playing;
          if (isPlaying) {
            handler.pause();
          } else {
            handler.play();
          }
          return KeyEventResult.handled;
        } else if (isCtrl && key == LogicalKeyboardKey.arrowRight) {
          handler.skipToNext();
          return KeyEventResult.handled;
        } else if (isCtrl && key == LogicalKeyboardKey.arrowLeft) {
          handler.skipToPrevious();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          handler.seek(handler.player.position + const Duration(seconds: 5));
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          final target = handler.player.position - const Duration(seconds: 5);
          handler.seek(target < Duration.zero ? Duration.zero : target);
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          final vol = handler.player.volume;
          handler.setVolume((vol + 0.05).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          final vol = handler.player.volume;
          handler.setVolume((vol - 0.05).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.keyM) {
          final vol = handler.player.volume;
          handler.setVolume(vol > 0 ? 0.0 : 1.0);
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.keyL) {
          ref.read(desktopLyricsVisibleProvider.notifier).toggle();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.keyQ) {
          ref.read(desktopQueueVisibleProvider.notifier).toggle();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
        body: Column(
          children: [
            // Main content area (sidebar + content + queue/lyrics)
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  const DesktopSidebar(),

                  // Main content viewport
                  Expanded(
                    child: Column(
                      children: [
                        // Header
                        const DesktopHeader(),

                        // Page content
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: KeyedSubtree(
                              key: ValueKey(navIndex),
                              child: pages[navIndex],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Queue panel (conditionally shown)
                  if (showQueue) const DesktopQueuePanel(),

                  // Lyrics panel (conditionally shown)
                  if (showLyrics) const DesktopLyricsPanel(),
                ],
              ),
            ),

            // Cross-device playback continuation banner
            const CrossDeviceHandoffBanner(isDesktop: true),

            // Bottom Player Bar
            const DesktopPlayerBar(),
          ],
        ),
      ),
    );
  }
}
