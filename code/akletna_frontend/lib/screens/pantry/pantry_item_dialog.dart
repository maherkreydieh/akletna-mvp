import 'package:flutter/material.dart';

import '../../models/pantry_item.dart';

class PantryAmount {
  final String? quantity;
  final String? unit;
  const PantryAmount(this.quantity, this.unit);
}

class PantryItemDialog extends StatefulWidget {
  final String ingredientName;
  final PantryItem? item;
  const PantryItemDialog({super.key, required this.ingredientName, this.item});
  @override
  State<PantryItemDialog> createState() => _PantryItemDialogState();
}

class _PantryItemDialogState extends State<PantryItemDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late bool _known;
  @override
  void initState() {
    super.initState();
    _known = widget.item?.quantity != null;
    _quantity = TextEditingController(text: widget.item?.quantity ?? '');
    _unit = TextEditingController(text: widget.item?.unit ?? '');
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.item == null
          ? 'Add ${widget.ingredientName}'
          : 'Edit ${widget.ingredientName}',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I know the quantity'),
              subtitle: const Text(
                'Leave off to simply mark this ingredient as in your pantry.',
              ),
              value: _known,
              onChanged: (value) => setState(() => _known = value),
            ),
            if (_known) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return RegExp(r'^\d{1,15}(\.\d{1,12})?$').hasMatch(text) &&
                          RegExp(r'[1-9]').hasMatch(text)
                      ? null
                      : 'Enter a positive amount (up to 12 decimal places).';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'g, kg, mL, L, cup, piece or other',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty || value.length > 30
                    ? 'Enter a unit (up to 30 characters).'
                    : null,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              PantryAmount(
                _known ? _quantity.text.trim() : null,
                _known ? _unit.text.trim() : null,
              ),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
