import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final headerChildren = <Widget>[
      if (icon != null) ...<Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    ];
    if (trailing != null) {
      headerChildren.add(trailing!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: headerChildren),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
