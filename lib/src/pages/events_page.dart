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
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(sessionProvider).api.assignedEvents();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final next = ref.read(sessionProvider).api.assignedEvents();
    setState(() {
      _refreshing = true;
      _events = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder shows the error.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('BiletFlow'),
      actions: [
        IconButton(
          tooltip: 'Refresh events',
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => ref.read(sessionProvider).signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<List<AssignedEvent>>(
      future: _events,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState != ConnectionState.done;
        if (snapshot.data == null && waiting) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading assigned events',
            ),
          );
        }
        if (snapshot.hasError) {
          return PageNotice(
            icon: Icons.error_outline,
            title: 'Could not load events',
            message: readableError(snapshot.error!),
            action: FilledButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return PageNotice(
            icon: Icons.event_busy_outlined,
            title: 'No assigned events',
            message:
                'Ask the organizer to assign you to a published event, then refresh this page.',
            action: OutlinedButton(
              onPressed: _refreshing ? null : _refresh,
              child: const Text('Refresh events'),
            ),
          );
        }

        final now = DateTime.now();
        final today = DateUtils.dateOnly(now);
        final sorted = [...events]
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final groups = <String, List<AssignedEvent>>{
          'Today': [],
          'Upcoming': [],
          'Earlier starts': [],
        };
        for (final event in sorted) {
          final day = DateUtils.dateOnly(event.startAt.toLocal());
          final group = day == today
              ? 'Today'
              : day.isAfter(today)
              ? 'Upcoming'
              : 'Earlier starts';
          groups[group]!.add(event);
        }
        final sections = [
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty)
              (
                entry.key,
                entry.key == 'Earlier starts'
                    ? entry.value.reversed
                    : entry.value,
              ),
        ];
        final theme = Theme.of(context);
        return PageWidth(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: pagePadding.copyWith(bottom: 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned events',
                          style: theme.textTheme.headlineLarge,
                        ),
                        if (waiting) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(
                            semanticsLabel: 'Refreshing events',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                for (final (label, group) in sections) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Semantics(
                        header: true,
                        child: Text(label, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.list(
                      children: [
                        for (final event in group) _EventRow(event: event),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AssignedEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = event.startAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(start);
    final time = TimeOfDay.fromDateTime(start).format(context);
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 4,
          ),
          title: Text(event.title, style: theme.textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$date · $time'),
                if (event.venueName?.trim().isNotEmpty ?? false)
                  Text(event.venueName!),
                if (event.status != 'PUBLISHED') ...[
                  const SizedBox(height: 6),
                  StatusPill(event.status),
                ],
              ],
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          onTap: () => context.go('/events/${event.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
