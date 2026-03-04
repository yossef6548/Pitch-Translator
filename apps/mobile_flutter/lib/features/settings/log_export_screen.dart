import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logger.dart';

class LogExportScreen extends StatelessWidget {
  const LogExportScreen({super.key});

  Future<void> _copyLogs(BuildContext context) async {
    final logs = AppLogger.exportLines().join('\n');
    await Clipboard.setData(ClipboardData(text: logs));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard.')),
    );
  }

  Future<void> _saveLogsToFile(BuildContext context) async {
    final logs = AppLogger.exportLines().join('\n');
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final path = '${Directory.systemTemp.path}/pitch_translator_logs_$timestamp.txt';
    final file = File(path);
    await file.writeAsString(logs.isEmpty ? '[no log entries]' : logs);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Local log export created at: $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Local diagnostic logs are kept only on this device and can be exported for support/debugging.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _copyLogs(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy logs'),
                ),
                FilledButton.icon(
                  onPressed: () => _saveLogsToFile(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Export to local file'),
                ),
                TextButton(
                  onPressed: AppLogger.clear,
                  child: const Text('Clear logs'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: AppLogger.entries,
                builder: (context, entries, _) {
                  if (entries.isEmpty) {
                    return const Center(child: Text('No log entries yet.'));
                  }
                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        title: Text(entry.message),
                        subtitle: Text(
                          '${entry.level} • ${entry.timestamp.toLocal().toIso8601String()}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
