import 'package:flutter/material.dart';

class PageNotice extends StatelessWidget {
  const PageNotice({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      if (action != null) ...[const SizedBox(height: 20), action!],
    ]),
  ));
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'VALID' => const Color(0xFF75D8AD),
      'CHECKED_IN' => const Color(0xFFFFC978),
      'CANCELLED' || 'REFUNDED' => const Color(0xFFFF8590),
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

String readableError(Object error) => error.toString().replaceFirst('ApiFailure: ', '');
