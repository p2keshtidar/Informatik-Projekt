import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/code_field.dart';
import 'accounts_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  // true: kommt von der Anmeldung (E-Mail war noch nicht bestätigt), false: direkt nach der Registrierung
  final bool fromLogin;

  const VerifyEmailScreen({super.key, required this.email, this.fromLogin = false});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _api = ApiClient();

  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.verifyEmail(widget.email, _code.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AccountsScreen(user: user)),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _api.resendCode(widget.email);
      setState(() => _info = 'Neuer Code ist unterwegs (frühestens alle 60 Sekunden).');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.fromLogin
                      ? 'Deine E-Mail-Adresse ist noch nicht bestätigt. Wir haben einen 6-stelligen '
                          'Code an ${widget.email} geschickt. Er gilt 10 Minuten.'
                      : 'Wir haben einen 6-stelligen Code an ${widget.email} geschickt. '
                          'Er gilt 10 Minuten.'),
                  const SizedBox(height: 16),
                  CodeField(controller: _code),
                  if (_info != null) Text(_info!),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: Text(_loading ? 'Bitte warten …' : 'Bestätigen'),
                  ),
                  TextButton(onPressed: _resend, child: const Text('Code erneut senden')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
