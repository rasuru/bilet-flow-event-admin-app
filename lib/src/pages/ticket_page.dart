import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({
    super.key,
    required this.eventId,
    required this.code,
    this.fromSearch = false,
    this.searchTicket,
  });

  final String eventId;
  final String code;
  final bool fromSearch;
  final EventTicket? searchTicket;

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

enum _TicketAction { checkIn, reverse }

class _TicketPageState extends ConsumerState<TicketPage> {
  late Future<TicketValidation> _validation;
  _TicketAction? _pending;
  _TicketAction? _completed;
  String? _error;
  EventTicket? _lastTicket;

  String get _path => '/events/${widget.eventId}';
  bool get _busy => _pending != null;

  @override
  void initState() {
    super.initState();
    _validation = _validate();
  }

  Future<TicketValidation> _validate() =>
      ref.read(sessionProvider).api.validate(widget.eventId, widget.code);

  void _refresh() {
    if (_busy) return;
    setState(() {
      _error = null;
      _completed = null;
      _validation = _validate();
    });
  }

  void _back() {
    if (widget.fromSearch && context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fromSearch ? '$_path/search' : _path);
  }

  void _scanNext() => context.go('$_path/scan');

  Future<void> _confirmReversal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse check-in?'),
        content: const Text('This ticket will be eligible for entry again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse check-in'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _mutate(_TicketAction.reverse);
  }

  Future<void> _mutate(_TicketAction action) async {
    if (_busy) return;
    final session = ref.read(sessionProvider);
    setState(() {
      _pending = action;
      _error = null;
    });
    try {
      final api = session.api;
      final ticket = switch (action) {
        _TicketAction.checkIn => await api.checkIn(widget.eventId, widget.code),
        _TicketAction.reverse => await api.reverse(widget.eventId, widget.code),
      };
      if (mounted) {
        setState(() {
          _lastTicket = ticket;
          _completed = action;
          _validation = Future.value(
            TicketValidation(
              ticketId: ticket.id,
              eventId: widget.eventId,
              status: ticket.status,
              validForEntry: ticket.status == 'VALID',
              seatId: ticket.seatId,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      // A request can succeed even if the connection drops before its response.
      setState(() {
        _error = 'Could not confirm the change. ${readableError(error)}';
        _completed = null;
        _validation = _validate();
      });
    } finally {
      session.checkInRevision.value++;
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Ticket status'),
        leading: IconButton(
          tooltip: widget.fromSearch ? 'Search results' : 'Event overview',
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _back,
        ),
        actions: [
          FutureBuilder<TicketValidation>(
            future: _validation,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Refresh ticket status',
              onPressed:
                  _busy || snapshot.connectionState != ConnectionState.done
                  ? null
                  : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: FutureBuilder<TicketValidation>(
        future: _validation,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          final validation = waiting ? null : snapshot.data;
          final checkedIn = validation?.status == 'CHECKED_IN';
          final ready = validation?.validForEntry ?? false;
          final admitted = checkedIn && _completed == _TicketAction.checkIn;
          final reversed = ready && _completed == _TicketAction.reverse;
          final error = snapshot.error;
          final statusCode = error is ApiFailure ? error.statusCode : null;
          final (tone, icon, headline, message) = switch (validation?.status) {
            _ when waiting => (
              TicketTone.neutral,
              Icons.qr_code_scanner,
              'Verifying ticket',
              'Checking its status with the server.',
            ),
            _ when statusCode == 404 => (
              TicketTone.blocked,
              Icons.search_off,
              'Ticket not found',
              'Check the ticket code and the selected event.',
            ),
            _ when statusCode == 403 => (
              TicketTone.blocked,
              Icons.lock_outline,
              'Access unavailable',
              'You are not assigned to this event.',
            ),
            _ when error != null => (
              TicketTone.neutral,
              Icons.error_outline,
              'Verification unavailable',
              readableError(error),
            ),
            _ when admitted => (
              TicketTone.admitted,
              Icons.task_alt,
              'Checked in',
              'Admit this attendee.',
            ),
            _ when reversed => (
              TicketTone.eligible,
              Icons.undo,
              'Check-in reversed',
              'This ticket is eligible for entry again.',
            ),
            'CHECKED_IN' => (
              TicketTone.used,
              Icons.history,
              'Already checked in',
              'This ticket has already been used for entry.',
            ),
            'CANCELLED' => (
              TicketTone.blocked,
              Icons.block,
              'Do not admit',
              'This ticket was cancelled.',
            ),
            'REFUNDED' => (
              TicketTone.blocked,
              Icons.block,
              'Do not admit',
              'This ticket was refunded.',
            ),
            _ when ready => (
              TicketTone.eligible,
              Icons.verified_outlined,
              'Ready for entry',
              'Confirm check-in before admitting this attendee.',
            ),
            _ => (
              TicketTone.blocked,
              Icons.block,
              'Do not admit',
              'This ticket is not eligible for entry.',
            ),
          };
          final attendee =
              _lastTicket?.attendeeEmail ?? widget.searchTicket?.attendeeEmail;
          final manualCode = shortTicketCodeFromInput(
            _lastTicket?.manualCode ??
                widget.searchTicket?.manualCode ??
                widget.code,
          );
          final qrCode =
              _lastTicket?.ticketCode ??
              widget.searchTicket?.ticketCode ??
              ticketCodeFromInput(widget.code);
          return PageWidth(
            maxWidth: 540,
            child: ListView(
              padding: pagePadding,
              children: [
                _TicketDecision(
                  tone: tone,
                  icon: icon,
                  headline: headline,
                  message: message,
                  loading: waiting || _busy,
                ),
                if (_error case final message?) ...[
                  const SizedBox(height: 12),
                  InlineNotice(message: message),
                ],
                const SizedBox(height: 16),
                if (ready)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _mutate(_TicketAction.checkIn),
                    icon: const Icon(Icons.how_to_reg_outlined),
                    label: Text(
                      _pending == _TicketAction.checkIn
                          ? 'Checking in…'
                          : 'Confirm check-in',
                    ),
                  )
                else if (!waiting &&
                    validation == null &&
                    statusCode != 403 &&
                    statusCode != 404)
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry verification'),
                  )
                else if (!waiting && statusCode != 403)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : widget.fromSearch
                        ? _back
                        : _scanNext,
                    icon: Icon(
                      widget.fromSearch ? Icons.search : Icons.qr_code_scanner,
                    ),
                    label: Text(
                      widget.fromSearch ? 'Back to search' : 'Scan next ticket',
                    ),
                  ),
                if ((ready ||
                        (validation == null &&
                            statusCode != 403 &&
                            statusCode != 404)) &&
                    !waiting) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : widget.fromSearch
                        ? _back
                        : _scanNext,
                    child: Text(
                      widget.fromSearch
                          ? 'Back to search'
                          : 'Scan another ticket',
                    ),
                  ),
                ],
                if ((attendee?.isNotEmpty ?? false) ||
                    validation?.seatId != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (attendee?.isNotEmpty ?? false)
                            _Detail(label: 'Attendee', value: attendee!),
                          if (validation?.seatId case final seat?)
                            _Detail(label: 'Seat ID', value: seat),
                        ],
                      ),
                    ),
                  ),
                ],
                if (checkedIn) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _busy ? null : _confirmReversal,
                    icon: const Icon(Icons.undo),
                    label: Text(
                      _pending == _TicketAction.reverse
                          ? 'Reversing check-in…'
                          : 'Reverse check-in',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Ticket details'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (manualCode != null)
                      _Detail(
                        label: 'Check-in code',
                        value: formatShortTicketCode(manualCode),
                      ),
                    if (qrCode != null)
                      _Detail(label: 'QR code ID', value: qrCode),
                    if (validation != null)
                      _Detail(label: 'Ticket ID', value: validation.ticketId),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _TicketDecision extends StatelessWidget {
  const _TicketDecision({
    required this.tone,
    required this.icon,
    required this.headline,
    required this.message,
    required this.loading,
  });

  final TicketTone tone;
  final IconData icon;
  final String headline;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: tone.foreground),
              const SizedBox(height: 14),
              Text(
                headline,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: tone.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tone.foreground,
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                LinearProgressIndicator(
                  color: tone.foreground,
                  backgroundColor: tone.foreground.withValues(alpha: 0.18),
                  semanticsLabel: 'Ticket request in progress',
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
