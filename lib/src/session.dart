import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.api, this._storage) {
    api.onUnauthorized = signOut;
  }

  static const _tokenKey = 'biletflow_event_admin_token';
  final EventAdminApi api;
  final FlutterSecureStorage _storage;
  final ValueNotifier<int> checkInRevision = ValueNotifier(0);
  String? _token;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> restore() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      api.setToken(_token);
    } catch (_) {
      _token = null;
      api.setToken(null);
    }
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    final token = await api.signIn(username, password);
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
    api.setToken(token);
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    api.setToken(null);
    notifyListeners();
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) { /* The in-memory session has already been cleared. */ }
  }
}
