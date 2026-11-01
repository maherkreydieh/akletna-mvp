import 'package:flutter/material.dart';

import '../../widgets/app_state_view.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_service.dart';
import '../../services/ingredient_service.dart';
import 'pantry_item_dialog.dart';
import 'pantry_ingredient_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/presentation/pantry_quantity_step.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/kitchen_destinations.dart';
import '../../services/pantry_matching_service.dart';
import 'cook_with_what_i_have_screen.dart';
import 'pantry_inventory_card.dart';

class MyPantryScreen extends StatefulWidget {
  final PantryService? pantryService;
  final IngredientService? ingredientService;
  final PantryMatchingService? matchingService;
  const MyPantryScreen({
    super.key,
    this.pantryService,
    this.ingredientService,
    this.matchingService,
  });
  @override
  State<MyPantryScreen> createState() => _MyPantryScreenState();
}

class _MyPantryScreenState extends State<MyPantryScreen> {
  late final PantryService _pantry;
  late final IngredientService _ingredients;
  List<PantryItem> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _search = TextEditingController();
  int _filter = 0;
  bool _recent = false;
  bool? _wasActive;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = KitchenDestinations.maybeOf(context)?.selectedIndex == 4;
    if (active && _wasActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy && !_loading) _load();
      });
    }
    _wasActive = active;
  }

  @override
  void initState() {
    super.initState();
    _pantry = widget.pantryService ?? PantryService();
    _ingredients = widget.ingredientService ?? IngredientService();
    _load();
  }

  bool _auth(Object error) {
    if (error is ApiException && error.statusCode == 401) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.loginRoute,
        (_) => false,
      );
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _pantry.getPantry();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted && !_auth(error)) {
        setState(() => _error = 'Could not load your pantry. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    bool redirected = false;
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pantry updated.')));
      }
    } catch (error) {
      if (!mounted) return;
      if (_auth(error)) {
        redirected = true;
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException &&
                    (error.statusCode == 400 || error.statusCode == 409)
                ? error.message
                : 'Could not update your pantry. Refresh before trying again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (!redirected) await _load();
      }
    }
  }

  Future<void> _add() async {
    final ingredient = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantryIngredientPicker(ingredientService: _ingredients),
      ),
    );
    if (!mounted || ingredient == null) return;
    final amount = await showDialog<PantryAmount>(
      context: context,
      builder: (_) => PantryItemDialog(ingredientName: ingredient.name),
    );
    if (mounted && amount != null) {
      await _mutate(() async {
        await _pantry.add(
          ingredient.id,
          quantity: amount.quantity,
          unit: amount.unit,
        );
      });
    }
  }

  Future<void> _edit(PantryItem item) async {
    final amount = await showDialog<PantryAmount>(
      context: context,
      builder: (_) =>
          PantryItemDialog(ingredientName: item.ingredientName, item: item),
    );
    if (mounted && amount != null) {
      await _mutate(() async {
        await _pantry.update(
          item.id,
          quantity: amount.quantity,
          unit: amount.unit,
        );
      });
    }
  }

  Future<void> _remove(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${item.ingredientName}?'),
        content: const Text(
          'Remove this ingredient from your pantry when you no longer have it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _mutate(() => _pantry.remove(item.id));
    }
  }

  Future<void> _step(PantryItem item, int delta) async {
    final next = pantryQuantityStep(item.quantity, delta);
    if (next == null || item.unit == null || _busy || _loading) return;
    await _mutate(() async {
      await _pantry.update(item.id, quantity: next, unit: item.unit);
    });
  }

  Future<void> _matches() async {
    if (_busy || _loading) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CookWithWhatIHaveScreen(
          matchingService: widget.matchingService,
          pantryService: _pantry,
          ingredientService: _ingredients,
        ),
      ),
    );
    if (mounted) await _load();
  }

  List<PantryItem> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final items = _items
        .where(
          (i) =>
              i.ingredientName.toLowerCase().contains(query) &&
              (_filter == 0 || (_filter == 1) == (i.quantity != null)),
        )
        .toList();
    items.sort(
      (a, b) => _recent
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.ingredientName.toLowerCase().compareTo(
              b.ingredientName.toLowerCase(),
            ),
    );
    return items;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Akletna اكلتنا'),
      actions: [
        IconButton(
          onPressed: _loading || _busy ? null : _load,
          tooltip: 'Refresh pantry',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading || _busy ? null : _add,
      icon: const Icon(Icons.add),
      label: const Text('Add Ingredient'),
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _busy ? () async {} : _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  Text(
                    'Pantry & Mouneh',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'المونة اللبنانية',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    AppErrorView(title: _error!, onRetry: _busy ? null : _load),
                  ] else ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: HearthBadge(
                        '${_items.length} tracked ingredients',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search your pantry…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear pantry search',
                                onPressed: () => setState(_search.clear),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HearthBadge('Your kitchen, less waste'),
                            const SizedBox(height: 12),
                            const HearthSection('Cook With What I Have'),
                            const SizedBox(height: 8),
                            const Text(
                              'Find recipes using your pantry. Unknown amounts are kept separate from confirmed matches.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy ? null : _matches,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Find matching recipes'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const HearthSection('Inventory'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(
                                  const [
                                    'All',
                                    'Quantity tracked',
                                    'Amount unknown',
                                  ][i],
                                ),
                                selected: _filter == i,
                                onSelected: (_) => setState(() => _filter = i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DropdownButton<bool>(
                        isExpanded: true,
                        itemHeight: null,
                        value: _recent,
                        items: const [
                          DropdownMenuItem(value: false, child: Text('Name')),
                          DropdownMenuItem(
                            value: true,
                            child: Text('Recently updated'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _recent = value!),
                      ),
                    ),
                    if (_items.isEmpty)
                      const AppStateView(
                        icon: Icons.kitchen_outlined,
                        title: 'Your pantry is empty',
                        message: 'Add ingredients you already have at home.',
                      )
                    else if (_filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No ingredients match your search or filter.',
                        ),
                      )
                    else
                      for (final item in _filtered)
                        PantryInventoryCard(
                          item: item,
                          busy: _busy,
                          onEdit: () => _edit(item),
                          onRemove: () => _remove(item),
                          onStep: (delta) => _step(item, delta),
                        ),
                  ],
                ],
              ),
            ),
    ),
  );
}
