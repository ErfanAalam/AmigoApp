import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme-color.provider.dart';
import '../../ui/app-bar.widget.dart';
import '../../ui/settings-tile.widget.dart';
import '../../utils/message-recommendations.store.dart';

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: const AmigoAppBar(title: 'Chat Settings', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120, top: 8),
        children: [
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.bolt_rounded,
                iconBackgroundColor: const Color(0xFFFFB400),
                title: 'Quick Replies',
                subtitle: 'Customize one-tap message suggestions',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 22,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuickRepliesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
            child: Text(
              'Quick replies appear above the message input for one-tap responses.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone screen to edit the quick reply list, replacing the previous
/// dialog-based editor.
class QuickRepliesScreen extends ConsumerStatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  ConsumerState<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends ConsumerState<QuickRepliesScreen> {
  static const int _maxLength = 40;
  List<String> _recs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    MessageRecommendationsStore.load().then((recs) {
      if (!mounted) return;
      setState(() {
        _recs = recs;
        _loaded = true;
      });
    });
  }

  void _persist() => MessageRecommendationsStore.save(_recs);

  void _add(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    setState(() => _recs = [..._recs, v]);
    _persist();
  }

  void _updateAt(int index, String value) {
    final v = value.trim();
    if (v.isEmpty || index < 0 || index >= _recs.length) return;
    if (_recs[index] == v) return;
    setState(() {
      final next = [..._recs];
      next[index] = v;
      _recs = next;
    });
    _persist();
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _recs.length) return;
    setState(() {
      final next = [..._recs];
      next.removeAt(index);
      _recs = next;
    });
    _persist();
  }

  void _reset() {
    setState(() {
      _recs = List<String>.from(kDefaultMessageRecommendations);
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AmigoAppBar(
        title: 'Quick Replies',
        showBackButton: true,
        actions: [
          AmigoAppBarAction(
            icon: Icons.refresh_rounded,
            onPressed: _reset,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(color: themeColor.primary))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: _recs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _QuickReplyRow(
                        key: ValueKey('rec-$index-${_recs[index]}'),
                        initialValue: _recs[index],
                        themeColor: themeColor.primary,
                        maxLength: _maxLength,
                        onChanged: (next) => _updateAt(index, next),
                        onRemove: () => _removeAt(index),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    color: const Color(0xFFF2F3F5),
                    child: _AddQuickReplyField(
                      themeColor: themeColor.primary,
                      maxLength: _maxLength,
                      onSubmit: _add,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuickReplyRow extends StatefulWidget {
  final String initialValue;
  final Color themeColor;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  const _QuickReplyRow({
    super.key,
    required this.initialValue,
    required this.themeColor,
    required this.maxLength,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_QuickReplyRow> createState() => _QuickReplyRowState();
}

class _QuickReplyRowState extends State<_QuickReplyRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      _controller.text = widget.initialValue;
      return;
    }
    if (v != widget.initialValue) widget.onChanged(v);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                _commit();
                _focusNode.unfocus();
              },
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1F2329),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: widget.onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddQuickReplyField extends StatefulWidget {
  final Color themeColor;
  final int maxLength;
  final ValueChanged<String> onSubmit;

  const _AddQuickReplyField({
    required this.themeColor,
    required this.maxLength,
    required this.onSubmit,
  });

  @override
  State<_AddQuickReplyField> createState() => _AddQuickReplyFieldState();
}

class _AddQuickReplyFieldState extends State<_AddQuickReplyField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    widget.onSubmit(v);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.themeColor.withOpacity(0.4),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: 'Add a quick reply',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1F2329),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: widget.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _submit,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
