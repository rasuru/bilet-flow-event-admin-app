import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models.dart';
import '../widgets.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.eventId});
  final String eventId;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _opening = false;
  bool _enteringCode = false;
  String? _message;

  void _open(String code) {
    if (_opening) return;
    _opening = true;
    context.go('/events/${widget.eventId}/tickets/$code');
  }

  void _detected(BarcodeCapture capture) {
    if (!mounted || _opening || _enteringCode) return;
    for (final barcode in capture.barcodes) {
      final code = ticketCodeFromInput(barcode.rawValue ?? '');
      if (code != null) {
        _open(code);
        return;
      }
    }
    if (capture.barcodes.isNotEmpty && _message == null) {
      setState(
        () => _message =
            'Ticket code not found in this QR. Try another ticket or enter the code.',
      );
    }
  }

  Future<void> _manualEntry() async {
    if (_opening || _enteringCode) return;
    _enteringCode = true;
    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => const _ManualEntry(),
      );
      if (mounted && code != null) _open(code);
    } finally {
      _enteringCode = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan ticket'),
      leading: IconButton(
        tooltip: 'Event overview',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/events/${widget.eventId}'),
      ),
    ),
    body: PageWidth(
      maxWidth: 540,
      child: ListView(
        padding: pagePadding,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final side = math.min(size.width, size.height) * 0.72;
                  final window = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: side,
                    height: side,
                  );
                  return MobileScanner(
                    onDetect: _detected,
                    scanWindow: window,
                    placeholderBuilder: (context) => const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Starting camera',
                      ),
                    ),
                    overlayBuilder: (context, constraints) {
                      final theme = Theme.of(context);
                      return IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _Viewfinder(
                                window,
                                theme.colorScheme.primary,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'Align the QR code in the frame',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error) => _CameraUnavailable(
                      permissionDenied:
                          error.errorCode ==
                          MobileScannerErrorCode.permissionDenied,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_message case final message?) ...[
            InlineNotice(message: message),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _manualEntry,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Enter ticket code'),
          ),
        ],
      ),
    ),
  );
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.permissionDenied});

  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Camera unavailable',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  permissionDenied
                      ? 'Allow camera access in device settings, or enter the code below.'
                      : 'Enter the ticket code below to verify it.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends CustomPainter {
  const _Viewfinder(this.window, this.color);

  final Rect window;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(window);
    canvas.drawPath(shade, Paint()..color = const Color(0xA6101613));

    const length = 22.0;
    final corners = Path()
      ..moveTo(window.left, window.top + length)
      ..lineTo(window.left, window.top)
      ..lineTo(window.left + length, window.top)
      ..moveTo(window.right - length, window.top)
      ..lineTo(window.right, window.top)
      ..lineTo(window.right, window.top + length)
      ..moveTo(window.right, window.bottom - length)
      ..lineTo(window.right, window.bottom)
      ..lineTo(window.right - length, window.bottom)
      ..moveTo(window.left + length, window.bottom)
      ..lineTo(window.left, window.bottom)
      ..lineTo(window.left, window.bottom - length);
    canvas.drawPath(
      corners,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Viewfinder oldDelegate) =>
      oldDelegate.window != window || oldDelegate.color != color;
}

class _ManualEntry extends StatefulWidget {
  const _ManualEntry();

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _submitted = false;
  bool _attempted = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String? _parse(String input) =>
      shortTicketCodeFromInput(input) ?? ticketCodeFromInput(input);

  void _submit() {
    if (_submitted) return;
    if (!_attempted) setState(() => _attempted = true);
    if (!_form.currentState!.validate()) return;
    _submitted = true;
    Navigator.of(context).pop(_parse(_code.text));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: pagePadding.copyWith(top: 0),
        child: Form(
          key: _form,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter ticket code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the 8-character code next to the QR on the ticket.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Check-in code',
                  hintText: 'e.g. 7K9M-2Q8R',
                ),
                validator: (value) => _parse(value ?? '') == null
                    ? 'Enter 8 characters or paste the full ticket code or link.'
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Verify ticket'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
