import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  // 428: Code per Mail nötig, 403: E-Mail noch nicht bestätigt
  bool get codeRequired => statusCode == 428;
  bool get emailNotVerified => statusCode == 403;

  @override
  String toString() => message;
}

class ApiClient {
  // Serveradresse, änderbar mit --dart-define=API_URL=...
  static const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  // Tokens der aktuellen Anmeldung, gemeinsam für alle Screens (nur im Speicher,
  // dauerhaftes Speichern kommt mit token_store.dart)
  static String? _accessToken;
  static String? _refreshToken;

  static bool get isLoggedIn => _accessToken != null;

  static void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  final http.Client _http;

  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  // Schritt 1: legt den Nutzer an, der Server schickt einen Code per Mail
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime birthDate,
  }) async {
    await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'birthDate': birthDate.toIso8601String().substring(0, 10),
    });
  }

  // Schritt 2: Code aus der Mail, danach gibt es das Girokonto
  Future<User> verifyEmail(String email, String code) async {
    final json = await _post('/api/auth/verify-email', {'email': email, 'code': code});
    return _loggedIn(json as Map<String, dynamic>);
  }

  Future<void> resendCode(String email) => _post('/api/auth/resend-code', {'email': email});

  // ohne code: Server schickt Code und antwortet 428, mit code: angemeldet
  Future<User> login(String email, String password, {String? code}) async {
    final json = await _post('/api/auth/login', {
      'email': email,
      'password': password,
      if (code != null) 'code': code,
    });
    return _loggedIn(json as Map<String, dynamic>);
  }

  Future<void> forgotPassword(String email) => _post('/api/auth/password/forgot', {'email': email});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _post('/api/auth/password/reset', {'email': email, 'code': code, 'newPassword': newPassword});

  // Konten des angemeldeten Nutzers (der Server erkennt ihn am Token)
  Future<List<Account>> accounts() async {
    final body = await _get('/api/accounts');
    return (body as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Antwort von Login und Bestätigung: { accessToken, refreshToken, user }
  User _loggedIn(Map<String, dynamic> json) {
    _accessToken = json['accessToken'] as String;
    _refreshToken = json['refreshToken'] as String;
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  // GET mit Token. Ist der Access-Token abgelaufen (401), einmal mit dem Refresh-Token erneuern.
  Future<dynamic> _get(String path) async {
    var res = await _http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders());
    if (res.statusCode == 401 && await _refresh()) {
      res = await _http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders());
    }
    return _decode(res);
  }

  Future<bool> _refresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final json = await _post('/api/auth/refresh', {'refreshToken': token});
      _loggedIn(json as Map<String, dynamic>);
      return true;
    } on ApiException {
      clearTokens();
      return false;
    }
  }

  Map<String, String> _authHeaders() => {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  // Fehler kommen vom Server immer im gleichen Format (ApiError)
  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    var message = 'Fehler ${res.statusCode}';
    if (body is Map<String, dynamic>) {
      message = body['message'] as String? ?? message;
      final fields = body['fields'];
      if (fields is Map && fields.isNotEmpty) {
        message += ': ${fields.entries.map((e) => '${e.key} ${e.value}').join(', ')}';
      }
    }
    throw ApiException(res.statusCode, message);
  }
}
