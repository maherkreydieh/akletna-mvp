import 'package:flutter/material.dart';

import '../../widgets/app_state_view.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/grocery_list.dart';
import '../../models/meal_plan.dart';
import '../../services/grocery_list_service.dart';
import '../meal_plans/weekly_meal_planner_screen.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/kitchen_destinations.dart';
import 'grocery_source_cards.dart';

class GroceryListScreen extends StatefulWidget {
  final GroceryListService? groceryListService;
  final DateTime? initialDate;

  const GroceryListScreen({
    super.key,
    this.groceryListService,
    this.initialDate,
  });

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  late final GroceryListService _service;
  late DateTime _monday;
  GroceryList? _list;
  bool _loading = true;
  bool _openingPlanner = false;
  int? _togglingItem;
  bool _removingContribution = false;
  String? _error;
  bool _generating = false;
  bool _confirmingGeneration = false;
  int _view = 0;
  int _filter = 0;
  bool? _wasActive;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = KitchenDestinations.maybeOf(context)?.selectedIndex == 3;
    if (active && _wasActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy) _loadWeek();
      });
    }
    _wasActive = active;
  }

  bool get _busy =>
      _loading ||
      _openingPlanner ||
      _togglingItem != null ||
      _removingContribution ||
      _confirmingGeneration ||
      _generating;

  @override
  void initState() {
    super.initState();
    _service = widget.groceryListService ?? GroceryListService();
    _monday = mealPlanWeekStart(widget.initialDate ?? DateTime.now());
    _loadWeek();
  }

  bool _redirectIfUnauthorized(Object error) {
    if (error is! ApiException || error.statusCode != 401) return false;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (_) => false,
    );
    return true;
  }

  Future<void> _loadWeek() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getList();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      setState(() {
        _loading = false;
        _error = error is ApiException && error.statusCode == 400
            ? error.message
            : 'Could not load your groceries. Please check your connection and try again.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    await _loadWeek();
  }

  void _changeWeek(DateTime monday) {
    if (_busy) return;
    setState(() => _monday = monday);
    _loadWeek();
  }

  Future<void> _toggleItem(GroceryItem item) async {
    if (_busy) return;
    setState(() => _togglingItem = item.id);
    try {
      final updated = await _service.toggleItem(item.id);
      if (!mounted) return;
      setState(() {
        _list = GroceryList(
          contributions: _list!.contributions,
          id: _list!.id,
          updatedAt: _list!.updatedAt,
          items: [
            for (final current in _list!.items)
              current.id == updated.id ? updated : current,
          ],
        );
      });
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not confirm the purchased check. Reloading saved checks.',
          ),
        ),
      );
      // A lost response might still have toggled the server item. Read it once;
      // do not repeat the toggle or regenerate (which would reset all checks).
      try {
        final stored = await _service.getList();
        if (!mounted) return;
        setState(() => _list = stored);
      } catch (reloadError) {
        if (!mounted) return;
        if (_redirectIfUnauthorized(reloadError)) return;
        setState(
          () => _error = 'Could not reload your groceries. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _togglingItem = null);
    }
  }

  Future<void> _openPlanner() async {
    if (_busy) return;
    setState(() => _openingPlanner = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WeeklyMealPlannerScreen(initialDate: _monday),
        ),
      );
      if (!mounted) return;
      await _loadWeek();
    } finally {
      if (mounted) setState(() => _openingPlanner = false);
    }
  }

  Future<void> _removeContribution(int id, String name) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove grocery addition?'),
        content: Text(
          'Remove missing ingredients added from $name? Other recipes and weekly meals will remain. Totals will be recalculated and purchased checks will reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove addition'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _removingContribution = true);
    try {
      final result = await _service.removeContribution(id);
      if (mounted) setState(() => _list = result);
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not confirm removal. Refresh your groceries.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _removingContribution = false);
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _confirmingGeneration = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Generate groceries?'),
          content: Text(
            'Replace planned-meal requirements for ${mealPlanDate(_monday)} to ${mealPlanDate(mealPlanDay(_monday, 6))}? Recipe additions remain. Purchased checks will reset.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Generate'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() => _generating = true);
      final list = await _service.generateWeek(_monday);
      if (mounted) {
        setState(() {
          _list = list;
          _error = null;
        });
      }
    } catch (error) {
      if (!mounted || _redirectIfUnauthorized(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException && error.statusCode == 400
                ? error.message
                : 'Could not confirm generation. Reloading the saved list.',
          ),
        ),
      );
      await _loadWeek();
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
          _confirmingGeneration = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Akletna اكلتنا'),
      actions: [
        IconButton(
          tooltip: 'Open weekly meal planner',
          onPressed: _busy ? null : _openPlanner,
          icon: const Icon(Icons.calendar_today_outlined),
        ),
        IconButton(
          tooltip: 'Refresh groceries',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppErrorView(title: _error!, onRetry: _busy ? null : _loadWeek)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text(
                    'Grocery Checklist',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: AppColors.primaryDark),
                  ),
                  const Text(
                    'قائمة التسوق',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HearthSection('Saved shopping list'),
                          const SizedBox(height: 8),
                          const Text(
                            'Planned meals and recipe additions. Refresh keeps your purchased checks.',
                          ),
                          if (_list!.contributions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: HearthBadge(
                                '${_list!.contributions.length} captured sources',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  HearthTabs(
                    labels: const ['Shopping list', 'Recipe sources'],
                    selected: _view,
                    onSelected: (view) => setState(() => _view = view),
                  ),
                  const SizedBox(height: 16),
                  if (_togglingItem != null ||
                      _generating ||
                      _removingContribution)
                    const LinearProgressIndicator(),
                  if (_view == 1)
                    GrocerySourceCards(
                      sources: _list!.contributions,
                      busy: _busy,
                      onRemove: _removeContribution,
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(
                                  const ['All', 'To buy', 'Purchased'][i],
                                ),
                                selected: _filter == i,
                                onSelected: (_) => setState(() => _filter = i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_list!.items.isEmpty) ...[
                      const AppStateView(
                        icon: Icons.shopping_basket_outlined,
                        title: 'Your grocery list is empty',
                        message: 'Plan meals or add missing recipe ingredients to start your list.',
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _openPlanner,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Plan meals'),
                      ),
                    ] else
                      ..._checklists(),
                  ],
                  const SizedBox(height: 20),
                  _progress(),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HearthSection('Generate from your meal plan'),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous week',
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          _changeWeek(mealPlanDay(_monday, -7)),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  '${mealPlanDate(_monday)} – ${mealPlanDate(mealPlanDay(_monday, 6))}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next week',
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          _changeWeek(mealPlanDay(_monday, 7)),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _changeWeek(
                                    mealPlanWeekStart(DateTime.now()),
                                  ),
                            child: const Text('This week'),
                          ),
                          const Text(
                            'Generation resets purchased checks. Recipe additions stay until you remove them.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              onPressed: _busy ? null : _generate,
                              icon: const Icon(Icons.sync),
                              label: const Text('Generate Grocery List'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );

  List<Widget> _checklists() {
    final visible = _list!.items
        .where((i) => _filter == 0 || (_filter == 2) == i.checked)
        .toList();
    final groups = <String, List<GroceryItem>>{};
    for (final item in visible) {
      // Presentation groups only. Every stored item ID/amount remains distinct.
      final unit = item.displayUnit ?? item.unit;
      groups
          .putIfAbsent(
            unit?.trim().isNotEmpty == true ? unit! : 'Unit unavailable',
            () => [],
          )
          .add(item);
    }
    if (groups.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No items match this filter.'),
        ),
      ];
    }
    return [
      for (final entry in groups.entries)
        Card(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.primaryLight,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      entry.key == 'Unit unavailable'
                          ? entry.key
                          : 'Measured in ${entry.key}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    HearthBadge(
                      '${entry.value.where((i) => i.checked).length}/${entry.value.length} purchased',
                      spice: true,
                    ),
                  ],
                ),
              ),
              for (final item in entry.value)
                CheckboxListTile(
                  key: ValueKey('grocery-${item.id}'),
                  value: item.checked,
                  onChanged: _busy ? null : (_) => _toggleItem(item),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: item.checked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(item.quantityLabel),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _progress() {
    final total = _list!.items.length;
    final checked = _list!.items.where((i) => i.checked).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HearthSection('Shopping progress'),
            const SizedBox(height: 12),
            Text('$checked of $total purchased'),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : checked / total,
                minHeight: 8,
                semanticsLabel: '$checked of $total purchased grocery items',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
