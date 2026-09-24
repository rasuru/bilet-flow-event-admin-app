import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../models.dart';
import '../widgets.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  late Future<List<AssignedEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = ref.read(sessionProvider).api.assignedEvents();
  }

  Future<void> _refresh() async {
    final next = ref.read(sessionProvider).api.assignedEvents();
    setState(() => _events = next);
    try { await next; } catch (_) { /* FutureBuilder shows the error. */ }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Assigned events'),
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'Sign out', onPressed: () => ref.read(sessionProvider).signOut(), icon: const Icon(Icons.logout)),
      ],
    ),
    body: FutureBuilder<List<AssignedEvent>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return PageNotice(icon: Icons.wifi_off, title: 'Could not load events',
          message: readableError(snapshot.error!), action: FilledButton(onPressed: _refresh, child: const Text('Retry')));
        final events = snapshot.data!;
        if (events.isEmpty) return PageNotice(icon: Icons.event_busy_outlined, title: 'No events to check in',
          message: 'Ask the organizer to assign you to a published event. Then refresh this page.', action: OutlinedButton(onPressed: _refresh, child: const Text('Refresh events')));
        return RefreshIndicator(onRefresh: _refresh, child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          itemCount: events.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final event = events[index];
            final date = MaterialLocalizations.of(context).formatMediumDate(event.startAt.toLocal());
            final time = TimeOfDay.fromDateTime(event.startAt.toLocal()).format(context);
            return Card(child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/events/${event.id}'),
              child: Padding(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text('$date · $time', style: Theme.of(context).textTheme.bodyMedium),
                  if (event.venueName != null) ...[const SizedBox(height: 5), Text(event.venueName!)],
                  const SizedBox(height: 16),
                  Row(children: [const StatusPill('PUBLISHED'), const Spacer(),
                    Text('Open check-in', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 4), const Icon(Icons.chevron_right)]),
                ],
              )),
            ));
          },
        ));
      },
    ),
  );
}
