import 'package:flutter/material.dart';
import 'log-files.screen.dart';

class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Menu')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('See Logs'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogFilesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
