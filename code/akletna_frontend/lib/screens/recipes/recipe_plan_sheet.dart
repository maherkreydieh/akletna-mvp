import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/meal_plan.dart';
import '../../services/meal_plan_service.dart';

class RecipePlanSheet extends StatefulWidget {
  const RecipePlanSheet({
    super.key,
    required this.recipeId,
    required this.servings,
    required this.service,
    required this.onUnauthorized,
  });
  final int recipeId;
  final int servings;
  final MealPlanService service;
  final VoidCallback onUnauthorized;
  @override
  State<RecipePlanSheet> createState() => _RecipePlanSheetState();
}

class _RecipePlanSheetState extends State<RecipePlanSheet> {
  DateTime _date = mealPlanDay(DateTime.now());
  MealType _type = MealType.lunch;
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.addMeal(
        recipeId: widget.recipeId,
        plannedServings: widget.servings,
        date: _date,
        mealType: _type,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        Navigator.pop(context);
        widget.onUnauthorized();
      } else {
        setState(
          () => _error = e is ApiException && e.statusCode == 409
              ? 'This meal slot is already filled. Choose another slot or edit it in Meal Plan.'
              : 'Could not confirm this meal. Check Meal Plan before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Add to Meal Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.servings} servings'),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(mealPlanDate(_date)),
            onPressed: _saving
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) setState(() => _date = date);
                  },
          ),
          DropdownButtonFormField<MealType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Meal'),
            items: MealType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: _saving ? null : (type) => setState(() => _type = type!),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Adding…' : 'Add meal'),
        ),
      ],
    ),
  );
}
