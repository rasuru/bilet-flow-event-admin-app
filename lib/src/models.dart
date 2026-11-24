class AssignedEvent {
  const AssignedEvent({required this.id, required this.title, required this.startAt, required this.status, this.venueName});

  final String id;
  final String title;
  final DateTime startAt;
  final String status;
  final String? venueName;

  factory AssignedEvent.fromJson(Map<String, dynamic> json) => AssignedEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    startAt: DateTime.parse(json['startAt'] as String),
    status: json['status'] as String,
    venueName: (json['venue'] as Map<String, dynamic>?)?['name'] as String?,
  );
}

class CheckInCounts {
  const CheckInCounts({required this.registered, required this.checkedIn});
  final int registered;
  final int checkedIn;

  factory CheckInCounts.fromJson(Map<String, dynamic> json) => CheckInCounts(
    registered: json['registered'] as int,
    checkedIn: json['checkedIn'] as int,
  );
}

class TicketValidation {
  const TicketValidation({required this.ticketId, required this.eventId, required this.status, required this.validForEntry, this.seatId});
  final String ticketId;
  final String eventId;
  final String status;
  final bool validForEntry;
  final String? seatId;

  factory TicketValidation.fromJson(Map<String, dynamic> json) => TicketValidation(
    ticketId: json['ticketId'] as String,
    eventId: json['eventId'] as String,
    status: json['status'] as String,
    validForEntry: json['validForEntry'] as bool,
    seatId: json['seatId'] as String?,
  );
}

class EventTicket {
  const EventTicket({
    required this.id,
    required this.ticketCode,
    required this.attendeeEmail,
    required this.status,
    this.seatId,
    this.manualCode,
  });
  final String id;
  final String ticketCode;
  final String? manualCode;
  final String attendeeEmail;
  final String status;
  final String? seatId;

  factory EventTicket.fromJson(Map<String, dynamic> json) => EventTicket(
    id: json['id'] as String,
    ticketCode: json['ticketCode'] as String,
    manualCode: json['manualCode'] as String?,
    attendeeEmail: json['attendeeEmail'] as String,
    status: json['status'] as String,
    seatId: json['seatId'] as String?,
  );
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// The current backend stores an opaque UUID ticketCode, not a signed QR payload.
String? ticketCodeFromInput(String value) {
  final input = value.trim();
  if (_uuid.hasMatch(input)) return input.toLowerCase();
  final uri = Uri.tryParse(input);
  if (uri == null || !uri.hasScheme) return null;
  for (final candidate in [uri.queryParameters['ticketCode'], uri.queryParameters['code'],
    if (uri.pathSegments.isNotEmpty) uri.pathSegments.last]) {
    if (candidate != null && _uuid.hasMatch(candidate)) return candidate.toLowerCase();
  }
  return null;
}

final _shortTicketCode = RegExp(r'^[0-9A-HJKMNP-TV-Z]{8}$');

String? shortTicketCodeFromInput(String input) {
  final code = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  return _shortTicketCode.hasMatch(code) ? code : null;
}

String formatShortTicketCode(String code) =>
    '${code.substring(0, 4)}-${code.substring(4)}';
