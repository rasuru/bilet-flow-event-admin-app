import 'package:bilet_flow_event_admin_app/src/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../models.dart';
import '../widgets.dart';

class EventPage extends ConsumerStatefulWidget {
  const EventPage({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  late Future<(AssignedEvent, CheckInCounts)> _overview;
  late final ValueNotifier<int> _revision;

  @override
  void initState() {
    super.initState();
    _overview = _load();
    _revision = ref.read(sessionProvider).checkInRevision;
    _revision.addListener(_refresh);
  }

  @override
  void dispose() {
    _revision.removeListener(_refresh);
    super.dispose();
  }

  Future<(AssignedEvent, CheckInCounts)> _load() async {
    final api = ref.read(sessionProvider).api;
    final results = await Future.wait<Object>([
      api.assignedEvents(),
      api.counts(widget.eventId),
    ]);
    final events = results[0] as List<AssignedEvent>;
    final event = events.where((item) => item.id == widget.eventId).firstOrNull;
    if (event == null) {
      throw ApiFailure('This event is no longer assigned to you.');
    }
    return (event, results[1] as CheckInCounts);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _overview = future);
    try {
      await future;
    } catch (_) {
      /* The error view handles this. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Event check-in'),
      leading: IconButton(
        tooltip: 'Assigned events',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/events'),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<(AssignedEvent, CheckInCounts)>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return PageNotice(
            icon: Icons.error_outline,
            title: 'Cannot open event',
            message: readableError(snapshot.error!),
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.go('/events/${widget.eventId}/scan'),
                  child: const Text('Open scanner'),
                ),
              ],
            ),
          );
        final (event, counts) = snapshot.data!;
        final date = MaterialLocalizations.of(
          context,
        ).formatMediumDate(event.startAt.toLocal());
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$date${event.venueName == null ? '' : ' · ${event.venueName}'}',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      label: 'Registered',
                      count: counts.registered,
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      label: 'Checked in',
                      count: counts.checkedIn,
                      icon: Icons.how_to_reg_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/events/${widget.eventId}/scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan ticket'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/events/${widget.eventId}/search').then((_) {
                      if (mounted) _refresh();
                    }),
                icon: const Icon(Icons.search),
                label: const Text('Search attendees'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              if (counts.registered == 0) ...[
                const SizedBox(height: 24),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No registrations yet. You can still scan a ticket or search when attendees arrive.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Check-in requires a connection to the server.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
  });
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
