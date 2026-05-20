import 'package:flutter/material.dart';

import 'blurred-dialog.widget.dart';

/// A single-pick option for [showBlurredSelectionDialog]. The picker shows
/// each option as a tappable row with an optional leading icon and trailing
/// radio indicator. The selected `value` is what comes back from the future.
class BlurredSelectionOption<T> {
  final T value;
  final String label;
  final String? sublabel;
  final IconData? icon;

  const BlurredSelectionOption({
    required this.value,
    required this.label,
    this.sublabel,
    this.icon,
  });
}

/// Single-select picker rendered inside the same frosted-glass shell as
/// [showBlurredDialog]: title at the top, optional body paragraph, vertical
/// list of options, Cancel / OK footer. Resolves to the chosen value, or
/// null when the user cancels or dismisses via the barrier.
///
/// Confirm is disabled until something is picked (unless [initialValue] is
/// supplied, in which case OK is enabled immediately).
Future<T?> showBlurredSelectionDialog<T>({
  required BuildContext context,
  required String title,
  String? body,
  required List<BlurredSelectionOption<T>> options,
  T? initialValue,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool barrierDismissible = true,
}) {
  return showBlurredDialog<T>(
    context: context,
    title: title,
    barrierDismissible: barrierDismissible,
    bodyPadding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
    body: _BlurredSelectionBody<T>(
      body: body,
      options: options,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _BlurredSelectionBody<T> extends StatefulWidget {
  final String? body;
  final List<BlurredSelectionOption<T>> options;
  final T? initialValue;
  final String confirmLabel;
  final String cancelLabel;

  const _BlurredSelectionBody({
    required this.body,
    required this.options,
    required this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  @override
  State<_BlurredSelectionBody<T>> createState() =>
      _BlurredSelectionBodyState<T>();
}

class _BlurredSelectionBodyState<T> extends State<_BlurredSelectionBody<T>> {
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.body != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              widget.body!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF3A3F47),
              ),
            ),
          ),
        ...widget.options.map((opt) {
          final selected =
              _selected != null && _selected == opt.value;
          return InkWell(
            onTap: () => setState(() => _selected = opt.value),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  if (opt.icon != null) ...[
                    Icon(
                      opt.icon,
                      size: 20,
                      color: const Color(0xFF3A3F47),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2329),
                          ),
                        ),
                        if (opt.sublabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              opt.sublabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Trailing radio indicator — matches the blurred-dialog
                  // accent (#1F6FEB) when selected, empty ring otherwise.
                  _RadioIndicator(selected: selected),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: BlurredDialogActions(
            onCancel: (ctx) => Navigator.of(ctx).pop(),
            onConfirm: (ctx) => Navigator.of(ctx).pop<T>(_selected as T),
            confirmEnabled: _selected != null,
            confirmLabel: widget.confirmLabel,
            cancelLabel: widget.cancelLabel,
          ),
        ),
      ],
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;
  const _RadioIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1F6FEB);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : const Color(0xFFB6BBC4),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
