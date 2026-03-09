import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Card(title: 'Today focus card', subtitle: 'Recommended exercise for today.'),
          _Card(title: 'Live Pitch', subtitle: 'Open quick live monitoring.'),
          _Card(title: 'History', subtitle: 'Review past sessions and analysis.'),
          _Card(title: 'Quick pitch monitor', subtitle: 'Jump into real-time pitch feedback.'),
          _Card(title: 'Progress snapshot', subtitle: 'Review your latest trend and streak.'),
          _Card(title: 'Continue last session', subtitle: 'Resume your most recent training flow.'),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(title: Text(title), subtitle: Text(subtitle)),
    );
  }
}
