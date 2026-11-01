import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/ingredient.dart';
import '../../services/ingredient_service.dart';

class PantryIngredientPicker extends StatefulWidget {
  final IngredientService ingredientService;
  const PantryIngredientPicker({super.key, required this.ingredientService});
  @override
  State<PantryIngredientPicker> createState() => _PantryIngredientPickerState();
}

class _PantryIngredientPickerState extends State<PantryIngredientPicker> {
  final _search = TextEditingController();
  List<Ingredient> _ingredients = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.ingredientService.getIngredients();
      items.sort((a, b) {
        final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
      if (mounted) setState(() => _ingredients = items);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
        return;
      }
      setState(() => _error = 'Could not load ingredients. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final item = await showDialog<Ingredient>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateIngredientDialog(
        service: widget.ingredientService,
        name: _search.text.trim(),
      ),
    );
    if (mounted && item != null) Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = _ingredients
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose an ingredient'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh ingredients',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Search ingredients',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const HearthPageIntro(
                        title: 'Stock your kitchen',
                        subtitle: 'Choose an existing ingredient to preserve its identity and unit.',
                        icon: Icons.kitchen_outlined,
                      ),
                      if (matches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No matching ingredients',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...matches.map(
                        (item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.unit),
                          onTap: () => Navigator.pop(context, item),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: Text(
                            query.isEmpty
                                ? 'Create a new ingredient'
                                : 'Add "${_search.text.trim()}" as a new ingredient',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CreateIngredientDialog extends StatefulWidget {
  final IngredientService service;
  final String name;
  const _CreateIngredientDialog({required this.service, required this.name});
  @override
  State<_CreateIngredientDialog> createState() =>
      _CreateIngredientDialogState();
}

class _CreateIngredientDialogState extends State<_CreateIngredientDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _unit = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final item = await widget.service.createIngredient(
        _name.text,
        _unit.text,
      );
      if (mounted) Navigator.pop(context, item);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
        return;
      }
      setState(
        () => _error = error is ApiException && error.statusCode == 400
            ? error.message
            : 'Could not create the ingredient. Refresh the catalog before retrying.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Create ingredient'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reuse an existing ingredient when possible. New ingredients are also available when creating recipes.',
              ),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Ingredient name'),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ||
                        (value?.trim().length ?? 0) > 100
                    ? 'Enter a name (2–100 characters).'
                    : null,
              ),
              TextFormField(
                controller: _unit,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Default unit',
                  hintText: 'g, mL, cup, piece or other',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty || value.length > 30
                    ? 'Enter a unit (up to 30 characters).'
                    : null,
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(),
                )
              : const Text('Create'),
        ),
      ],
    ),
  );
}
