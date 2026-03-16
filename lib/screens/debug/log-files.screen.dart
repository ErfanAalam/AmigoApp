import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'log-viewer.screen.dart';

class LogFilesScreen extends StatefulWidget {
  const LogFilesScreen({super.key});

  @override
  State<LogFilesScreen> createState() => _LogFilesScreenState();
}

class _LogFilesScreenState extends State<LogFilesScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final Directory? dir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();

      if (dir == null || !dir.existsSync()) {
        setState(() => _loading = false);
        return;
      }

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadFiles();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No log files found'))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, i) {
                    final file = _files[i];
                    final stat = file.statSync();
                    final name = file.path.split('/').last;
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(name),
                      subtitle: Text(
                        '${_formatSize(stat.size)}  ·  ${_formatDate(stat.modified)}',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LogViewerScreen(file: file),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
