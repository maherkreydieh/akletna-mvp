import 'package:flutter/material.dart';

/// Seven equal columns keep the week centered without horizontal clipping.
class WeekdayStrip extends StatelessWidget {
  const WeekdayStrip({super.key, required this.days})
    : assert(days.length == 7);
  final List<Widget> days;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < days.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(child: days[i]),
      ],
    ],
  );
}
