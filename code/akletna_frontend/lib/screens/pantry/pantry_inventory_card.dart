import 'package:flutter/material.dart';

import '../../models/pantry_item.dart';
import '../../core/presentation/pantry_quantity_step.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/kitchen_thumbnail.dart';

class PantryInventoryCard extends StatelessWidget {
  const PantryInventoryCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
    required this.onStep,
  });
  final PantryItem item;
  final bool busy;
  final VoidCallback onEdit, onRemove;
  final ValueChanged<int> onStep;
  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('pantry-${item.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KitchenThumbnail(icon: Icons.eco_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HearthBadge(
                      item.quantity == null
                          ? 'Amount unknown'
                          : 'Quantity tracked',
                      spice: item.quantity == null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.ingredientName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      item.quantityLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: ValueKey('pantry-decrease-${item.id}'),
                tooltip: 'Decrease by 1 ${item.unit ?? 'unit'}',
                onPressed: busy || pantryQuantityStep(item.quantity, -1) == null
                    ? null
                    : () => onStep(-1),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                key: ValueKey('pantry-increase-${item.id}'),
                tooltip: 'Increase by 1 ${item.unit ?? 'unit'}',
                onPressed: busy || pantryQuantityStep(item.quantity, 1) == null
                    ? null
                    : () => onStep(1),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Edit ${item.ingredientName}',
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remove ${item.ingredientName}',
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (item.quantity == null)
            Text(
              'Set an amount to use quantity controls.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (item.quantity != null)
            Text(
              '±1 ${item.unit} per tap',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );
}
