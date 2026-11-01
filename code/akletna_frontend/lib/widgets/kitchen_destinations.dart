import 'package:flutter/material.dart';

/// Lets existing Home shortcuts select a primary destination in the shell.
class KitchenDestinations extends InheritedWidget {
  const KitchenDestinations({
    super.key,
    required this.select,
    required super.child,
    this.selectedIndex = 0,
    this.selectPlanner,
    this.plannerDate,
    this.plannerRequest = 0,
  });

  final ValueChanged<int> select;
  final int selectedIndex;
  final ValueChanged<DateTime>? selectPlanner;
  final DateTime? plannerDate;
  final int plannerRequest;

  static KitchenDestinations? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KitchenDestinations>();

  @override
  bool updateShouldNotify(KitchenDestinations oldWidget) =>
      selectedIndex != oldWidget.selectedIndex ||
      plannerRequest != oldWidget.plannerRequest;
}
