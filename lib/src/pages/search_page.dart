import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../models.dart';
import '../widgets.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _query = TextEditingController();
  List<EventTicket>? _results;
  String? _error;
  String? _validationError;
  bool _busy = false;
  int _requestId = 0;

  String get _path => '/events/${widget.eventId}';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    final value = _query.text.trim();
    if (value.length < 3) {
      setState(() => _validationError = 'Enter at least three characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    final request = ++_requestId;
    setState(() {
      _busy = true;
      _error = null;
      _validationError = null;
    });
    try {
      final results = await ref
          .read(sessionProvider)
          .api
          .search(widget.eventId, value);
      if (mounted && request == _requestId) setState(() => _results = results);
    } catch (error) {
      if (mounted && request == _requestId) {
        setState(() {
          _error = readableError(error);
          _results = null;
        });
      }
    } finally {
      if (mounted && request == _requestId) setState(() => _busy = false);
    }
  }

  void _queryChanged(String value) {
    _requestId++;
    setState(() {
      _busy = false;
      _error = null;
      _validationError = null;
      _results = null;
    });
  }

  Future<void> _openTicket(EventTicket ticket) async {
    final revision = ref.read(sessionProvider).checkInRevision;
    final previous = revision.value;
    await context.push(
      '$_path/tickets/${ticket.ticketCode}?from=search',
      extra: ticket,
    );
    if (mounted && previous != revision.value) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Search attendees')),
      body: PageWidth(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: pagePadding.copyWith(bottom: 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _query,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      onChanged: _queryChanged,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: 'Attendee email',
                        helperText: 'Enter at least 3 characters.',
                        errorText: _validationError,
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear email',
                                onPressed: () {
                                  _query.clear();
                                  _queryChanged('');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _search,
                      icon: const Icon(Icons.search),
                      label: Text(_busy ? 'Searching…' : 'Search'),
                    ),
                    if (_busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Searching attendees',
                      ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 14),
                      InlineNotice(
                        message: 'Could not search attendees. $error',
                      ),
                    ],
                    if (results != null && results.isEmpty && !_busy) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'No matching tickets',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try a different email or scan the ticket QR code.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.go('$_path/scan'),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan ticket'),
                      ),
                    ],
                    if (results != null && results.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          results.length == 1
                              ? '1 matching ticket'
                              : '${results.length} matching tickets',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (results != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final ticket = results[index];
                    final code = ticket.ticketCode;
                    final manualCode = shortTicketCodeFromInput(
                      ticket.manualCode ?? '',
                    );
                    final displayCode = manualCode != null
                        ? formatShortTicketCode(manualCode)
                        : (code.length > 8
                              ? '…${code.substring(code.length - 8)}'
                              : code);
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          title: Text(
                            ticket.attendeeEmail,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Code $displayCode'),
                                if (ticket.seatId != null)
                                  Text('Seat ID ${ticket.seatId}'),
                                const SizedBox(height: 6),
                                StatusPill(ticket.status),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _busy ? null : () => _openTicket(ticket),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
