import 'package:shared_preferences/shared_preferences.dart';

/// Speichert Access- und Refresh-Token auf dem Gerät (shared_preferences),
/// damit man nach einem Neustart der App angemeldet bleibt.
///
/// Es gibt genau eine Instanz: [TokenStore.instance]. Alle Screens und jedes
/// `ApiClient()` benutzen dieselbe, auch wenn jeder Screen sein eigenes
/// `ApiClient()` erzeugt.
class TokenStore {
  TokenStore._();

  static final instance = TokenStore._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // Zwischenspeicher, damit nicht jeder Request auf shared_preferences wartet
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessKey);
    _refreshToken = prefs.getString(_refreshKey);
    _loaded = true;
  }

  Future<String?> readAccessToken() async {
    await _load();
    return _accessToken;
  }

  Future<String?> readRefreshToken() async {
    await _load();
    return _refreshToken;
  }

  Future<void> save(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
  }
}
