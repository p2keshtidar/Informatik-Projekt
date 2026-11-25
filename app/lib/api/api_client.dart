import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/user.dart';
import 'token_store.dart';

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

  // Wird aufgerufen, wenn die Anmeldung abgelaufen ist (auch der Refresh klappt nicht mehr).
  // main.dart setzt hier "zurück zum Login".
  static void Function()? onSessionExpired;

  // Läuft gerade ein Refresh, warten alle anderen Requests darauf. Der Server macht den
  // alten Refresh-Token beim Erneuern ungültig, zwei gleichzeitige Refreshs würden also scheitern.
  static Future<bool>? _refreshing;

  // Tokens liegen in token_store.dart, gemeinsam für alle Screens
  static Future<bool> isLoggedIn() async =>
      await TokenStore.instance.readAccessToken() != null;

  static Future<void> clearTokens() => TokenStore.instance.clear();

  final http.Client _http;
  final TokenStore _tokens = TokenStore.instance;

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

  // Schritt 2: Code aus der Mail, danach gibt es das Girokonto und man ist direkt angemeldet
  Future<User> verifyEmail(String email, String code) async {
    final json = await _post('/api/auth/verify-email', {'email': email, 'code': code});
    return _loggedIn(json);
  }

  Future<void> resendCode(String email) => _post('/api/auth/resend-code', {'email': email});

  // ohne code: Server schickt Code und antwortet 428, mit code: angemeldet
  Future<User> login(String email, String password, {String? code}) async {
    final json = await _post('/api/auth/login', {
      'email': email,
      'password': password,
      if (code != null) 'code': code,
    });
    return _loggedIn(json);
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

  // Antwort von Login, Bestätigung und Refresh: { accessToken, refreshToken, user }
  Future<User> _loggedIn(dynamic json) async {
    final map = json as Map<String, dynamic>;
    await _tokens.save(map['accessToken'] as String, map['refreshToken'] as String);
    return User.fromJson(map['user'] as Map<String, dynamic>);
  }

  Future<dynamic> _get(String path) =>
      _send(path, () async => _http.get(_uri(path), headers: await _headers()));

  Future<dynamic> _post(String path, Map<String, dynamic> data) => _send(
      path,
      () async => _http.post(_uri(path), headers: await _headers(), body: jsonEncode(data)));

  // Jeder Request schickt den Token mit. Bei 401 einmal /api/auth/refresh und den Request
  // wiederholen, klappt das nicht: Tokens löschen und zurück zum Login.
  // Für /api/auth/... (Login, Refresh selbst) nicht, dort heißt 401 etwas anderes.
  Future<dynamic> _send(String path, Future<http.Response> Function() request) async {
    var res = await request();
    if (res.statusCode == 401 && !path.startsWith('/api/auth/')) {
      if (await _refresh()) res = await request();
      if (res.statusCode == 401) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
    }
    return _decode(res);
  }

  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final token = await _tokens.readRefreshToken();
    if (token == null) return false;
    try {
      await _loggedIn(await _post('/api/auth/refresh', {'refreshToken': token}));
      return true;
    } on ApiException {
      return false;
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, String>> _headers() async {
    final token = await _tokens.readAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
