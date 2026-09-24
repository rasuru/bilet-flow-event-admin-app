import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.eventId});
  final String eventId;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _opening = false;
  String? _message;

  void _open(String raw) {
    if (_opening) return;
    final code = ticketCodeFromInput(raw);
    if (code == null) {
      setState(() => _message = 'That QR code does not contain a ticket code. Try another or enter the UUID.');
      return;
    }
    _opening = true;
    context.go('/events/${widget.eventId}/tickets/$code');
  }

  void _detected(BarcodeCapture capture) {
    if (_opening) return;
    for (final barcode in capture.barcodes) {
      final code = ticketCodeFromInput(barcode.rawValue ?? '');
      if (code != null) {
        _open(code);
        return;
      }
    }
    if (mounted && _message == null) setState(() => _message = 'This QR code is not a ticket. Try another one.');
  }

  Future<void> _manualEntry() async {
    String input = '';
    String? error;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, update) {
        void submit() {
          final parsed = ticketCodeFromInput(input);
          if (parsed == null) {
            update(() => error = 'Enter the full ticket UUID.');
          } else {
            Navigator.pop(sheetContext, parsed);
          }
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Enter ticket code', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Use the UUID on the ticket when scanning is unavailable.'),
            const SizedBox(height: 18),
            TextField(
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                input = value;
                if (error != null) update(() => error = null);
              },
              onSubmitted: (value) { input = value; submit(); },
              decoration: InputDecoration(labelText: 'Ticket UUID', errorText: error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: submit, child: const Text('Verify ticket')),
          ])),
        );
      }),
    );
    if (mounted && code != null) _open(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan ticket'), leading: IconButton(
      tooltip: 'Event overview', icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/events/${widget.eventId}'))),
    body: Stack(children: [
      MobileScanner(
        onDetect: _detected,
        errorBuilder: (context, error) => Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 52),
            const SizedBox(height: 12),
            Text('Camera unavailable', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Allow camera access in device settings, or enter the ticket code below.', textAlign: TextAlign.center),
          ]),
        )),
      ),
      Align(alignment: Alignment.bottomCenter, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        decoration: const BoxDecoration(color: Color(0xF00C0E14), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.qr_code_scanner, size: 32),
          const SizedBox(height: 8),
          Text(_message ?? 'Point the camera at the ticket QR code.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _opening ? null : _manualEntry,
            icon: const Icon(Icons.keyboard), label: const Text('Enter code manually'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
        ])),
      )),
    ]),
  );
}
