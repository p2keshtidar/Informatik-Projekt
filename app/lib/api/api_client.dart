import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  // Serveradresse, änderbar mit --dart-define=API_URL=...
  static const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  final http.Client _http;

  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime birthDate,
  }) async {
    final json = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'birthDate': birthDate.toIso8601String().substring(0, 10),
    });
    return User.fromJson(json);
  }

  Future<User> login(String email, String password) async {
    final json = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return User.fromJson(json);
  }

  Future<List<Account>> accounts(int userId) async {
    final res = await _http.get(Uri.parse('$baseUrl/api/users/$userId/accounts'));
    final body = _decode(res);
    return (body as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _decode(res) as Map<String, dynamic>;
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
    throw ApiException(message);
  }
}
