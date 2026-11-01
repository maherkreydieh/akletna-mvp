import 'package:flutter/foundation.dart';

/// Invalidation only; the backend remains the source of all grocery quantities.
abstract final class MealPlanChanges {
  static final revision = ValueNotifier<int>(0);
  static void notify() => revision.value++;
}
