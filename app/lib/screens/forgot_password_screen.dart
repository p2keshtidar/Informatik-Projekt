import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../util/password_rules.dart';
import '../widgets/code_field.dart';
import '../widgets/password_checklist.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  List<String> get _personal => personalParts(_email.text, '', '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        await _api.forgotPassword(_email.text.trim());
        setState(() => _codeSent = true);
      } else {
        await _api.resetPassword(_email.text.trim(), _code.text, _password.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort geändert. Bitte neu anmelden.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwort vergessen')),
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
                  TextFormField(
                    controller: _email,
                    enabled: !_codeSent,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'E-Mail eingeben' : null,
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    const Text('Falls die E-Mail registriert ist, haben wir einen Code geschickt.'),
                    CodeField(controller: _code),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Neues Passwort'),
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          isPasswordOk(v ?? '', _personal) ? null : 'Passwort erfüllt nicht alle Regeln',
                    ),
                    const SizedBox(height: 8),
                    PasswordChecklist(password: _password.text, personal: _personal),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading
                        ? 'Bitte warten …'
                        : _codeSent
                            ? 'Passwort ändern'
                            : 'Code schicken'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
