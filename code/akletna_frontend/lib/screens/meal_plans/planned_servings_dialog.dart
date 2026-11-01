import 'package:flutter/material.dart';

/// One serving picker for both new meals and edits; source recipes remain unchanged.
class PlannedServingsDialog extends StatefulWidget {
  final int initialServings;
  final String title;
  final String description;
  final String confirmLabel;
  const PlannedServingsDialog({
    super.key,
    required this.initialServings,
    required this.title,
    required this.description,
    required this.confirmLabel,
  });
  @override
  State<PlannedServingsDialog> createState() => _PlannedServingsDialogState();
}

class _PlannedServingsDialogState extends State<PlannedServingsDialog> {
  bool _submitted = false;
  late int _servings = widget.initialServings;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.description),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Decrease servings',
              onPressed: _servings <= 1
                  ? null
                  : () => setState(() => _servings--),
              icon: const Icon(Icons.remove),
            ),
            Flexible(
              child: Text(
                'Servings: $_servings',
                key: const ValueKey('planned-servings-value'),
              ),
            ),
            IconButton(
              tooltip: 'Increase servings',
              onPressed: _servings >= 2147483647
                  ? null
                  : () => setState(() => _servings++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _submitted
            ? null
            : () {
                if (_submitted) return;
                setState(() => _submitted = true);
                Navigator.pop(context, _servings);
              },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
