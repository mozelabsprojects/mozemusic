import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_handler.dart';
import '../../core/theme/app_theme.dart';

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(sleepTimerProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Sleep Timer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 8),
          if (timerState.isActive) ...[
            const SizedBox(height: 16),
            if (timerState.endOfTrack)
              const Text('Stopping after current track', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16))
            else if (timerState.remaining != null) ...[
              Text(
                '${timerState.remaining!.inMinutes}:${(timerState.remaining!.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Text('remaining', style: TextStyle(color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ref.read(sleepTimerProvider.notifier).cancel();
                  Navigator.pop(context);
                },
                child: const Text('Cancel Timer', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ..._buildTimerOptions(context, ref),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildTimerOptions(BuildContext context, WidgetRef ref) {
    final options = [
      ('5 minutes', const Duration(minutes: 5)),
      ('15 minutes', const Duration(minutes: 15)),
      ('30 minutes', const Duration(minutes: 30)),
      ('45 minutes', const Duration(minutes: 45)),
      ('1 hour', const Duration(hours: 1)),
    ];

    return [
      ...options.map((opt) => ListTile(
        title: Text(opt.$1, style: const TextStyle(color: Colors.white)),
        leading: const Icon(Icons.timer, color: AppTheme.textSecondary),
        onTap: () {
          ref.read(sleepTimerProvider.notifier).startTimer(opt.$2);
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      )),
      ListTile(
        title: const Text('End of track', style: TextStyle(color: Colors.white)),
        leading: const Icon(Icons.music_note, color: AppTheme.textSecondary),
        onTap: () {
          ref.read(sleepTimerProvider.notifier).setEndOfTrack();
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ];
  }
}
