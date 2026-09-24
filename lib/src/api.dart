import 'package:dio/dio.dart';

import 'models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class EventAdminApi {
  EventAdminApi(String baseUrl) : _dio = Dio(BaseOptions(
    baseUrl: '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  final Dio _dio;
  String? _token;
  Future<void> Function()? onUnauthorized;

  void setToken(String? token) => _token = token;

  Options get _auth => Options(headers: {if (_token != null) 'Authorization': 'Bearer $_token'});

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 && _token != null) await onUnauthorized?.call();
      final body = error.response?.data;
      final detail = body is Map ? body['detail'] : null;
      final message = switch (status) {
        401 => 'Invalid credentials or session expired. Sign in again.',
        403 => 'You are not assigned to this event.',
        404 => 'Ticket or event not found. Check the code and selected event.',
        409 => detail is String && detail.isNotEmpty ? detail : 'Ticket state changed. Refresh and try again.',
        _ => detail is String && detail.isNotEmpty ? detail :
          status == null ? 'Cannot reach the server. Check the server address and connection.' : 'Request failed (HTTP $status).',
      };
      throw ApiFailure(message, statusCode: status);
    }
  }

  Future<String> signIn(String username, String password) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>('/authenticate',
      data: {'username': username, 'password': password, 'rememberMe': false});
    return response.data!['id_token'] as String;
  });

  Future<List<AssignedEvent>> assignedEvents() => _run(() async {
    final response = await _dio.get<List<dynamic>>('/events/assigned-for-check-in', options: _auth);
    return response.data!.map((item) => AssignedEvent.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  });

  String _checkInPath(String eventId) => '/events/$eventId/check-in';

  Future<CheckInCounts> counts(String eventId) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>('${_checkInPath(eventId)}/counts', options: _auth);
    return CheckInCounts.fromJson(response.data!);
  });

  Future<List<EventTicket>> search(String eventId, String email) => _run(() async {
    final response = await _dio.get<List<dynamic>>('${_checkInPath(eventId)}/attendees',
      queryParameters: {'email': email}, options: _auth);
    return response.data!.map((item) => EventTicket.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  });

  Future<TicketValidation> validate(String eventId, String code) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>('${_checkInPath(eventId)}/tickets/$code/validation', options: _auth);
    return TicketValidation.fromJson(response.data!);
  });

  Future<EventTicket> checkIn(String eventId, String code) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>('${_checkInPath(eventId)}/tickets/$code', options: _auth);
    return EventTicket.fromJson(response.data!);
  });

  Future<EventTicket> reverse(String eventId, String code) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>('${_checkInPath(eventId)}/tickets/$code/reverse', options: _auth);
    return EventTicket.fromJson(response.data!);
  });
}
