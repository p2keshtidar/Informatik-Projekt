import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../util/password_rules.dart';
import '../widgets/password_checklist.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient();

  DateTime? _birthDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _personal => personalParts(_email.text, _firstName.text, _lastName.text);

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _error = 'Bitte Geburtsdatum wählen');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      await _api.register(
        email: email,
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
        birthDate: _birthDate!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null;

  @override
  Widget build(BuildContext context) {
    final d = _birthDate;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrieren')),
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
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Vorname'),
                    validator: _required,
                    onChanged: (_) => setState(() {}),
                  ),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Nachname'),
                    validator: _required,
                    onChanged: (_) => setState(() {}),
                  ),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'E-Mail eingeben' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        isPasswordOk(v ?? '', _personal) ? null : 'Passwort erfüllt nicht alle Regeln',
                  ),
                  const SizedBox(height: 8),
                  PasswordChecklist(password: _password.text, personal: _personal),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _pickBirthDate,
                    child: Text(d == null
                        ? 'Geburtsdatum wählen'
                        : 'Geboren am ${d.day}.${d.month}.${d.year}'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _register,
                    child: Text(_loading ? 'Bitte warten …' : 'Weiter'),
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
