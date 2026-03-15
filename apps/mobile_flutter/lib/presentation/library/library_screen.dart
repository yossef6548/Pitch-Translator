import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = SessionRepository.instance.libraryOverviewCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: FutureBuilder<Map<String, int>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load library assets.'));
          }
          final counts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Tile(
                title: 'Reference tones',
                subtitle: 'Indexed references: ${counts['reference_tones']}',
                icon: Icons.music_note,
                onTap: () => _showLocalFlow(context, 'Reference tones are local-only in this build.'),
              ),
              _Tile(
                title: 'Imported audio',
                subtitle: 'Use local file picker flow (coming from native import menu).',
                icon: Icons.audio_file,
                onTap: () => _showLocalFlow(context, 'Import pipeline is local-only. Add files via platform picker integration.'),
              ),
              _Tile(
                title: 'Choir presets',
                subtitle: 'Mastered entries: ${counts['mastered_entries']}',
                icon: Icons.groups,
                onTap: () => _showLocalFlow(context, 'Preset association is stored in local SQLite metadata.'),
              ),
              _Tile(
                title: 'Drift replay browsing',
                subtitle: 'Saved drift events: ${counts['drift_replays']}',
                icon: Icons.replay,
                onTap: () => _showLocalFlow(context, 'Drift replay panel is available in Analyze > Session detail.'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showLocalFlow(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local flow'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
