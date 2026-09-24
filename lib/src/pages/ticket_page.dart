import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../models.dart';
import '../widgets.dart';

class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({super.key, required this.eventId, required this.code,
    this.fromSearch = false, this.searchTicket});
  final String eventId;
  final String code;
  final bool fromSearch;
  final EventTicket? searchTicket;

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage> {
  late Future<TicketValidation> _validation;
  bool _busy = false;
  bool _justCheckedIn = false;
  String? _error;
  EventTicket? _lastTicket;

  @override
  void initState() {
    super.initState();
    _validation = _validate();
  }

  Future<TicketValidation> _validate() => ref.read(sessionProvider).api.validate(widget.eventId, widget.code);

  void _refresh() {
    if (_busy) return;
    setState(() { _error = null; _justCheckedIn = false; _validation = _validate(); });
  }

  void _back() {
    if (widget.fromSearch && context.canPop()) {
      context.pop();
    } else {
      context.go('/events/${widget.eventId}');
    }
  }

  void _scanNext() => context.go('/events/${widget.eventId}/scan');

  Future<void> _mutate({required bool reverse}) async {
    if (_busy) return;
    if (reverse) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Reverse check-in?'),
        content: const Text('This ticket will be eligible for entry again.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reverse'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final api = ref.read(sessionProvider).api;
      final ticket = reverse
        ? await api.reverse(widget.eventId, widget.code)
        : await api.checkIn(widget.eventId, widget.code);
      if (!mounted) return;
      setState(() {
        _lastTicket = ticket;
        _justCheckedIn = !reverse;
        _validation = Future.value(TicketValidation(
          ticketId: ticket.id, eventId: widget.eventId, status: ticket.status,
          validForEntry: ticket.status == 'VALID', seatId: ticket.seatId,
        ));
      });
      ref.read(sessionProvider).checkInRevision.value++;
    } catch (error) {
      if (!mounted) return;
      // A request may have succeeded even if the connection dropped. Fetch the
      // server state before enabling another check-in or reversal.
      setState(() {
        _error = '${readableError(error)} Check the current status before trying again.';
        _justCheckedIn = false;
        _validation = _validate();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ticket verification'), leading: IconButton(
      tooltip: widget.fromSearch ? 'Search results' : 'Event overview',
      icon: const Icon(Icons.arrow_back), onPressed: _back),
      actions: [IconButton(tooltip: 'Refresh status', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<TicketValidation>(
      future: _validation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return PageNotice(icon: Icons.error_outline, title: 'Cannot verify this ticket',
          message: _error == null ? readableError(snapshot.error!) : 'Could not confirm the latest status. ${readableError(snapshot.error!)}',
          action: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(onPressed: _refresh, child: const Text('Retry verification')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _scanNext, child: const Text('Scan next ticket')),
          ]));
        final validation = snapshot.data!;
        final checkedIn = validation.status == 'CHECKED_IN';
        final ready = validation.validForEntry;
        final color = _justCheckedIn ? const Color(0xFF75D8AD) : ready
          ? const Color(0xFF75D8AD) : const Color(0xFFFFC978);
        final headline = _justCheckedIn ? 'Checked in' : ready ? 'Ready for entry' : checkedIn
          ? 'Already checked in' : 'Do not admit';
        final message = _justCheckedIn ? 'Check-in completed. You can scan the next ticket.' : switch (validation.status) {
          'VALID' => ready ? 'This ticket is valid for the selected event. Confirm check-in before admitting.'
            : 'This ticket is not eligible for entry right now.',
          'CHECKED_IN' => 'This ticket has already been used for entry.',
          'CANCELLED' => 'This ticket was cancelled.',
          'REFUNDED' => 'This ticket was refunded.',
          _ => 'This ticket cannot be used for entry.',
        };
        final attendee = _lastTicket?.attendeeEmail ?? widget.searchTicket?.attendeeEmail;
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
          Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            Icon(_justCheckedIn ? Icons.task_alt : ready ? Icons.verified_outlined : Icons.info_outline,
              size: 64, color: color),
            const SizedBox(height: 14),
            Text(headline, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StatusPill(validation.status),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ]))),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(child: Text(_error!)),
            ]))),
          ],
          if (attendee != null && attendee.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Attendee', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(attendee, style: Theme.of(context).textTheme.titleMedium),
          ],
          const SizedBox(height: 24),
          if (ready) ...[
            FilledButton.icon(onPressed: _busy ? null : () => _mutate(reverse: false),
              icon: const Icon(Icons.how_to_reg), label: const Text('Confirm check-in')),
            const SizedBox(height: 12),
          ],
          if (!ready || _justCheckedIn) ...[
            FilledButton.icon(onPressed: _busy ? null : _scanNext,
              icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan next ticket')),
            const SizedBox(height: 12),
          ],
          if (checkedIn) ...[
            OutlinedButton.icon(onPressed: _busy ? null : () => _mutate(reverse: true),
              icon: const Icon(Icons.undo), label: const Text('Reverse check-in'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54))),
            const SizedBox(height: 12),
          ],
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          TextButton(onPressed: _back, child: Text(widget.fromSearch ? 'Back to search' : 'Event overview')),
          const SizedBox(height: 12),
          ExpansionTile(title: const Text('Ticket details'), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _Detail(label: 'Ticket ID', value: validation.ticketId),
              _Detail(label: 'Code', value: widget.code),
              if (validation.seatId != null) _Detail(label: 'Seat ID', value: validation.seatId!),
            ]),
        ]);
      },
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 3),
      SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
    ]),
  );
}
