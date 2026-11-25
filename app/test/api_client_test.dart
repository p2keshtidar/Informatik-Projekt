import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:girokonto_app/api/api_client.dart';
import 'package:girokonto_app/api/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Antwort von /login, /verify-email und /refresh (AuthResponse im Backend)
String authJson(String access, String refresh) => jsonEncode({
      'accessToken': access,
      'refreshToken': refresh,
      'user': {'id': 1, 'email': 'anna@test.de', 'firstName': 'Anna', 'lastName': 'Muster'},
    });

const accountsJson =
    '[{"id":7,"type":"MAIN","name":"Girokonto","iban":"DE00123","balanceCents":1000000}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStore.instance.clear();
    ApiClient.onSessionExpired = null;
  });

  test('Login speichert die Tokens', () async {
    final api = ApiClient(client: MockClient((req) async {
      expect(req.url.path, '/api/auth/login');
      return http.Response(authJson('access-1', 'refresh-1'), 200);
    }));

    final user = await api.login('anna@test.de', 'Kontor!Blau7Wald', code: '123456');

    expect(user.firstName, 'Anna');
    expect(await TokenStore.instance.readAccessToken(), 'access-1');
    expect(await TokenStore.instance.readRefreshToken(), 'refresh-1');
    expect(await ApiClient.isLoggedIn(), isTrue);

    // dauerhaft gespeichert, nicht nur im Speicher
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), 'access-1');
  });

  test('verifyEmail speichert die Tokens', () async {
    final api = ApiClient(client: MockClient((req) async {
      return http.Response(authJson('access-v', 'refresh-v'), 200);
    }));

    await api.verifyEmail('anna@test.de', '123456');

    expect(await TokenStore.instance.readAccessToken(), 'access-v');
  });

  test('Header Authorization wird mitgeschickt', () async {
    await TokenStore.instance.save('access-1', 'refresh-1');
    String? header;
    final api = ApiClient(client: MockClient((req) async {
      header = req.headers['Authorization'];
      return http.Response(accountsJson, 200);
    }));

    final accounts = await api.accounts();

    expect(header, 'Bearer access-1');
    expect(accounts.single.balanceCents, 1000000);
  });

  test('401 → Refresh wird versucht und der Request wiederholt', () async {
    await TokenStore.instance.save('alt', 'refresh-1');
    final calls = <String>[];
    final api = ApiClient(client: MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path == '/api/auth/refresh') {
        expect(jsonDecode(req.body)['refreshToken'], 'refresh-1');
        return http.Response(authJson('neu', 'refresh-2'), 200);
      }
      if (req.headers['Authorization'] == 'Bearer neu') {
        return http.Response(accountsJson, 200);
      }
      return http.Response('{"message":"Anmeldung abgelaufen"}', 401);
    }));

    final accounts = await api.accounts();

    expect(calls, ['/api/accounts', '/api/auth/refresh', '/api/accounts']);
    expect(accounts, hasLength(1));
    expect(await TokenStore.instance.readAccessToken(), 'neu');
    expect(await TokenStore.instance.readRefreshToken(), 'refresh-2');
  });

  test('401 und Refresh klappt nicht → Tokens weg, zurück zum Login', () async {
    await TokenStore.instance.save('alt', 'refresh-alt');
    var expired = false;
    ApiClient.onSessionExpired = () => expired = true;
    final api = ApiClient(client: MockClient((req) async {
      return http.Response('{"message":"Die Anmeldung ist abgelaufen."}', 401);
    }));

    await expectLater(api.accounts(), throwsA(isA<ApiException>()));

    expect(expired, isTrue);
    expect(await ApiClient.isLoggedIn(), isFalse);
  });
}
