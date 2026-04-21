import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/sqlite.db.dart';

/// Simple DB browser for debugging.
/// Lists all tables → pick one → shows up to 200 rows as key/value pairs.
class DbViewerScreen extends StatefulWidget {
  const DbViewerScreen({super.key});

  @override
  State<DbViewerScreen> createState() => _DbViewerScreenState();
}

class _DbViewerScreenState extends State<DbViewerScreen> {
  List<String> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final db = SqliteDatabase.instance.database;
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
          "ORDER BY name",
        )
        .get();
    if (!mounted) return;
    setState(() {
      _tables = rows.map((r) => r.read<String>('name')).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DB Viewer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _tables.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = _tables[i];
                return ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(t),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _TableRowsScreen(tableName: t),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TableRowsScreen extends StatefulWidget {
  final String tableName;
  const _TableRowsScreen({required this.tableName});

  @override
  State<_TableRowsScreen> createState() => _TableRowsScreenState();
}

class _TableRowsScreenState extends State<_TableRowsScreen> {
  List<Map<String, dynamic>> _rows = [];
  int _totalCount = 0;
  bool _loading = true;
  static const _limit = 200;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    setState(() => _loading = true);
    final db = SqliteDatabase.instance.database;
    try {
      final countRows = await db
          .customSelect('SELECT COUNT(*) AS c FROM "${widget.tableName}"')
          .get();
      final total = countRows.first.read<int>('c');

      final rows = await db
          .customSelect(
            'SELECT * FROM "${widget.tableName}" LIMIT $_limit',
          )
          .get();

      if (!mounted) return;
      setState(() {
        _totalCount = total;
        _rows = rows.map((r) {
          final data = <String, dynamic>{};
          r.data.forEach((k, v) => data[k] = v);
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _truncateTable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Truncate ${widget.tableName}?'),
        content: const Text('This deletes all rows. Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final db = SqliteDatabase.instance.database;
    await db.customStatement('DELETE FROM "${widget.tableName}"');
    await _loadRows();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRows,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: _truncateTable,
            tooltip: 'Truncate',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Showing ${_rows.length} of $_totalCount rows',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('No rows'))
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            return _RowTile(index: i, row: _rows[i]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> row;
  const _RowTile({required this.index, required this.row});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.blueGrey[100],
        child: Text(
          '${index + 1}',
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ),
      title: Text(
        _previewLine(row),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      children: row.entries.map((e) {
        final valStr = e.value?.toString() ?? 'NULL';
        return InkWell(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: valStr));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${e.key}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    valStr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _previewLine(Map<String, dynamic> row) {
    // Prefer id or name for the preview
    final candidates = ['id', 'name', 'title', 'body', 'message_id', 'user_id'];
    for (final k in candidates) {
      final v = row[k];
      if (v != null && v.toString().isNotEmpty) {
        return '$k=${v.toString()}';
      }
    }
    // Fallback: first non-null column
    for (final e in row.entries) {
      if (e.value != null) return '${e.key}=${e.value}';
    }
    return '(empty row)';
  }
}
