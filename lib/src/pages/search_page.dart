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
  bool _busy = false;
  int _requestId = 0;

  @override
  void dispose() {
    _requestId++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.length < 3) {
      _requestId++;
      setState(() { _busy = false; _error = 'Enter at least three characters from an email.'; _results = null; });
      return;
    }
    final request = ++_requestId;
    setState(() { _busy = true; _error = null; _results = null; });
    try {
      final results = await ref.read(sessionProvider).api.search(widget.eventId, value);
      if (mounted && request == _requestId) setState(() => _results = results);
    } catch (error) {
      if (mounted && request == _requestId) setState(() { _error = readableError(error); _results = null; });
    } finally {
      if (mounted && request == _requestId) setState(() => _busy = false);
    }
  }

  void _queryChanged(String value) {
    _requestId++;
    setState(() { _busy = false; _error = null; _results = null; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search attendees')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 12), child: TextField(
        controller: _query,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.search,
        onChanged: _queryChanged,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(hintText: 'Search by attendee email', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(tooltip: 'Search', onPressed: _search, icon: const Icon(Icons.arrow_forward))),
      )),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: _error != null
        ? PageNotice(icon: Icons.error_outline, title: _query.text.trim().length < 3 ? 'Enter more of the email' : 'Search unavailable', message: _error!,
            action: FilledButton(onPressed: _search, child: const Text('Try again')))
        : _busy
          ? const Center(child: Text('Searching attendees…'))
        : _results == null
        ? const PageNotice(icon: Icons.manage_search, title: 'Find an attendee', message: 'Enter at least three characters from their email, then tap Search.')
        : _results!.isEmpty
          ? PageNotice(icon: Icons.person_search, title: 'No tickets found', message: 'Try a different email or scan the ticket QR code.',
              action: OutlinedButton(onPressed: () => context.go('/events/${widget.eventId}/scan'), child: const Text('Scan ticket')))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              itemCount: _results!.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ticket = _results![index];
                return Card(child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  title: Text(ticket.attendeeEmail),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Align(
                    alignment: Alignment.centerLeft, child: StatusPill(ticket.status))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/events/${widget.eventId}/tickets/${ticket.ticketCode}?from=search', extra: ticket).then((_) {
                    if (mounted && _query.text.trim().length >= 3) _search();
                  }),
                ));
              },
            )),
    ]),
  );
}
