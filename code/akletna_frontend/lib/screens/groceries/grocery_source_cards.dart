import 'package:flutter/material.dart';

import '../../models/recipe_shortage.dart';
import '../../widgets/hearth_components.dart';

/// Source requirements are not checked-item identities. Keep this view read-only
/// apart from the existing removal action; never infer joins by ingredient name.
class GrocerySourceCards extends StatelessWidget {
  const GrocerySourceCards({
    super.key,
    required this.sources,
    required this.busy,
    required this.onRemove,
  });
  final List<GroceryContribution> sources;
  final bool busy;
  final void Function(int, String) onRemove;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Captured recipe requirements. Mark purchases in Shopping list.',
      ),
      const SizedBox(height: 12),
      if (sources.isEmpty)
        const Text('Recipe source information is unavailable for this list.'),
      for (final source in sources)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HearthSection(
                  source.source == 'PLANNED_MEAL'
                      ? 'Weekly meal plan'
                      : source.name,
                ),
                if (source.servings != null)
                  HearthBadge('${source.servings} servings'),
                const SizedBox(height: 12),
                for (final line in source.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(line.explanation),
                      ],
                    ),
                  ),
                if (source.source == 'RECIPE_SHORTAGE')
                  TextButton.icon(
                    key: ValueKey('remove-source-${source.id}'),
                    onPressed: busy
                        ? null
                        : () => onRemove(source.id, source.name),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Remove addition from ${source.name}'),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
