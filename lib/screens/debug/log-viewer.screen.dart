import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class LogViewerScreen extends StatefulWidget {
  final File file;

  const LogViewerScreen({super.key, required this.file});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await widget.file.readAsString();
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _content = 'Error reading file: $e';
        _loading = false;
      });
    }
  }

  String get _filename => widget.file.path.split('/').last;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filename),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _loading ? null : _copy),
          IconButton(icon: const Icon(Icons.share), onPressed: _loading ? null : _share),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _content,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
