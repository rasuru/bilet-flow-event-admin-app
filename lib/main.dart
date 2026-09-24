import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'src/api.dart';
import 'src/models.dart';
import 'src/pages/event_page.dart';
import 'src/pages/events_page.dart';
import 'src/pages/login_page.dart';
import 'src/pages/scan_page.dart';
import 'src/pages/search_page.dart';
import 'src/pages/ticket_page.dart';
import 'src/session.dart';
import 'src/theme.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

final sessionProvider = Provider<SessionController>((ref) => throw StateError('Session not initialized'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = EventAdminApi(apiBaseUrl);
  final session = SessionController(api, const FlutterSecureStorage());
  await session.restore();
  runApp(ProviderScope(
    overrides: [sessionProvider.overrideWithValue(session)],
    child: const EventAdminApp(),
  ));
}

class EventAdminApp extends ConsumerStatefulWidget {
  const EventAdminApp({super.key});

  @override
  ConsumerState<EventAdminApp> createState() => _EventAdminAppState();
}

class _EventAdminAppState extends ConsumerState<EventAdminApp> {
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    router = GoRouter(
      initialLocation: '/events',
      refreshListenable: session,
      redirect: (context, state) {
        final atLogin = state.uri.path == '/login';
        if (!session.isSignedIn) return atLogin ? null : '/login';
        return atLogin ? '/events' : null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(path: '/events', builder: (context, state) => const EventsPage()),
        GoRoute(
          path: '/events/:eventId',
          builder: (context, state) => EventPage(eventId: state.pathParameters['eventId']!),
          routes: [
            GoRoute(
              path: 'scan',
              builder: (context, state) => ScanPage(eventId: state.pathParameters['eventId']!),
            ),
            GoRoute(
              path: 'search',
              builder: (context, state) => SearchPage(eventId: state.pathParameters['eventId']!),
            ),
            GoRoute(
              path: 'tickets/:code',
              builder: (context, state) => TicketPage(
                eventId: state.pathParameters['eventId']!,
                code: state.pathParameters['code']!,
                fromSearch: state.uri.queryParameters['from'] == 'search',
                searchTicket: state.extra is EventTicket ? state.extra as EventTicket : null,
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page unavailable')),
        body: Center(child: FilledButton(
          onPressed: () => context.go('/events'),
          child: const Text('Back to events'),
        )),
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BiletFlow Check-in',
    theme: eventAdminTheme,
    routerConfig: router,
    debugShowCheckedModeBanner: false,
  );
}
