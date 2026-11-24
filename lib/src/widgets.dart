import 'package:flutter/material.dart';

const pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 28);

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

class PageNotice extends StatelessWidget {
  const PageNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageWidth(
      child: SingleChildScrollView(
        padding: pagePadding,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(message, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isError ? colors.onErrorContainer : colors.onSurface;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: foreground,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TicketTone {
  eligible(Color(0xFF1B352B), Color(0xFFBCEFD0)),
  admitted(Color(0xFFD5F398), Color(0xFF233407)),
  used(Color(0xFF382E1D), Color(0xFFFFDB9C)),
  blocked(Color(0xFF482823), Color(0xFFFFDAD4)),
  neutral(Color(0xFF222E27), Color(0xFFD4E2D7));

  const TicketTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      'VALID' => ('Valid', TicketTone.eligible),
      'CHECKED_IN' => ('Checked in', TicketTone.used),
      'CANCELLED' => ('Cancelled', TicketTone.blocked),
      'REFUNDED' => ('Refunded', TicketTone.blocked),
      'PUBLISHED' => ('Published', TicketTone.neutral),
      'DRAFT' => ('Draft', TicketTone.neutral),
      _ => (status.replaceAll('_', ' '), TicketTone.neutral),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tone.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String readableError(Object error) =>
    error.toString().replaceFirst('ApiFailure: ', '');
