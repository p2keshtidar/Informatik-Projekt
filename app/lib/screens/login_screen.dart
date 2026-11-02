import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/code_field.dart';
import 'accounts_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _api = ApiClient();

  // true, sobald der Server einen Code per Mail geschickt hat (Schritt 2)
  bool _codeStep = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.login(
        _email.text.trim(),
        _password.text,
        code: _codeStep ? _code.text : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AccountsScreen(user: user)),
      );
    } on ApiException catch (e) {
      if (e.codeRequired) {
        setState(() {
          _codeStep = true;
          _info = e.message;
        });
      } else if (e.emailNotVerified) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: _email.text.trim(), fromLogin: true),
        ));
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    setState(() {
      _codeStep = false;
      _code.clear();
      _info = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
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
                  Text('PHD Kontor',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    enabled: !_codeStep,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'E-Mail eingeben' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !_codeStep,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Passwort eingeben' : null,
                  ),
                  if (_codeStep) ...[
                    const SizedBox(height: 16),
                    if (_info != null) Text(_info!),
                    CodeField(controller: _code),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: Text(_loading
                        ? 'Bitte warten …'
                        : _codeStep
                            ? 'Code bestätigen'
                            : 'Anmelden'),
                  ),
                  if (_codeStep)
                    TextButton(onPressed: _back, child: const Text('Zurück'))
                  else ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      ),
                      child: const Text('Passwort vergessen?'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Noch kein Konto? Registrieren'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
