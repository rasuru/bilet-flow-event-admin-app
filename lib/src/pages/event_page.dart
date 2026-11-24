import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class EventPage extends ConsumerStatefulWidget {
  const EventPage({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  late Future<AssignedEvent> _event;
  late Future<CheckInCounts> _counts;
  late final ValueNotifier<int> _revision;

  String get _path => '/events/${widget.eventId}';

  @override
  void initState() {
    super.initState();
    _event = _loadEvent();
    _counts = _loadCounts();
    _revision = ref.read(sessionProvider).checkInRevision;
    _revision.addListener(_refreshCounts);
  }

  @override
  void dispose() {
    _revision.removeListener(_refreshCounts);
    super.dispose();
  }

  Future<AssignedEvent> _loadEvent() async {
    final events = await ref.read(sessionProvider).api.assignedEvents();
    final event = events.where((item) => item.id == widget.eventId).firstOrNull;
    if (event == null) {
      throw const ApiFailure('This event is no longer assigned to you.');
    }
    return event;
  }

  Future<CheckInCounts> _loadCounts() =>
      ref.read(sessionProvider).api.counts(widget.eventId);

  void _refreshCounts() {
    final next = _loadCounts();
    setState(() {
      _counts = next;
    });
  }

  void _retryEvent() => setState(() {
    _event = _loadEvent();
    _counts = _loadCounts();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Event check-in'),
      leading: IconButton(
        tooltip: 'Assigned events',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/events'),
      ),
    ),
    body: FutureBuilder<CheckInCounts>(
      future: _counts,
      builder: (context, attendance) => FutureBuilder<AssignedEvent>(
        future: _event,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading event'),
            );
          }
          if (snapshot.hasError) {
            return PageNotice(
              icon: Icons.error_outline,
              title: 'Cannot open event',
              message: readableError(snapshot.error!),
              action: FilledButton(
                onPressed: _retryEvent,
                child: const Text('Retry'),
              ),
            );
          }
          final event = snapshot.data!;
          final theme = Theme.of(context);
          final titleStyle = MediaQuery.sizeOf(context).width < 360
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineLarge;
          final start = event.startAt.toLocal();
          final date = MaterialLocalizations.of(
            context,
          ).formatMediumDate(start);
          final time = TimeOfDay.fromDateTime(start).format(context);
          return PageWidth(
            child: ListView(
              padding: pagePadding,
              children: [
                Text(
                  event.title,
                  style: titleStyle?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    date,
                    time,
                    if (event.venueName?.trim().isNotEmpty ?? false)
                      event.venueName!,
                  ].join(' · '),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: () => context.go('$_path/scan'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan ticket'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('$_path/search'),
                  icon: const Icon(Icons.search),
                  label: const Text('Search attendees'),
                ),
                const SizedBox(height: 28),
                _Attendance(
                  counts: attendance.data,
                  error: attendance.error,
                  refreshing:
                      attendance.connectionState != ConnectionState.done,
                  onRefresh: _refreshCounts,
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Attendance extends StatelessWidget {
  const _Attendance({
    required this.counts,
    required this.error,
    required this.refreshing,
    required this.onRefresh,
  });

  final CheckInCounts? counts;
  final Object? error;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = counts;
    final numbers = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Attendance', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Refresh attendance',
                  onPressed: refreshing ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (refreshing)
              const LinearProgressIndicator(
                semanticsLabel: 'Loading attendance',
              ),
            if (!refreshing && error != null)
              InlineNotice(
                message: 'Could not load attendance. ${readableError(error!)}',
              ),
            if (data != null) ...[
              const SizedBox(height: 6),
              if (data.registered == 0 && data.checkedIn == 0)
                const Text('No registrations yet.')
              else ...[
                Text(
                  '${numbers.formatDecimal(data.checkedIn)} of ${numbers.formatDecimal(data.registered)} checked in',
                  style: theme.textTheme.titleLarge,
                ),
                if (data.registered > 0) ...[
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      value: (data.checkedIn / data.registered)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
