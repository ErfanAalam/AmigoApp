import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:flutter/material.dart';
import '../../db/sqlite.db.dart';
import 'db-viewer.screen.dart';
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
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('DB Viewer'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DbViewerScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Query DB'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriftDbViewer(SqliteDatabase.instance.database),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
