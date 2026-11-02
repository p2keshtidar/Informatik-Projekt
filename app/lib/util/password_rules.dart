// Gleiche Regeln wie PasswordPolicy.java im Backend, hier für die Checkliste beim Tippen
class PasswordRule {
  final String label;
  final bool Function(String password, List<String> personal) ok;
  const PasswordRule(this.label, this.ok);
}

const _common = {
  'passwort', 'password', 'qwertz', 'qwerty', 'qwertzuiop', 'qwertyuiop', 'hallo', 'letmein',
  'willkommen', 'welcome', 'geheim', 'admin', 'iloveyou', 'sommer', 'winter', 'fussball',
  'football', 'schatz', 'dragon', 'monkey',
};

final passwordRules = <PasswordRule>[
  PasswordRule('Mindestens 12 Zeichen', (p, _) => p.length >= 12),
  PasswordRule('Kleinbuchstabe', (p, _) => p.contains(RegExp(r'\p{Ll}', unicode: true))),
  PasswordRule('Großbuchstabe', (p, _) => p.contains(RegExp(r'\p{Lu}', unicode: true))),
  PasswordRule('Ziffer', (p, _) => p.contains(RegExp(r'[0-9]'))),
  PasswordRule('Sonderzeichen', (p, _) => p.contains(RegExp(r'[^\p{L}0-9]', unicode: true))),
  PasswordRule('Kein Name und keine E-Mail', (p, personal) {
    final lower = p.toLowerCase();
    return !personal.any(lower.contains);
  }),
  PasswordRule('Keine Folgen wie 1234, abcd oder aaaa', (p, _) => !hasRunOrSequence(p.toLowerCase())),
  PasswordRule('Kein bekanntes Passwort', (p, _) => !isCommonPassword(p.toLowerCase())),
];

List<String> personalParts(String email, String firstName, String lastName) {
  final parts = <String>[];
  void add(String text, Pattern sep) {
    for (final s in text.toLowerCase().split(sep)) {
      if (s.length >= 3 && s.contains(RegExp(r'\p{L}', unicode: true))) parts.add(s);
    }
  }

  final at = email.indexOf('@');
  if (at > 0) add(email.substring(0, at), RegExp(r'[^\p{L}0-9]+', unicode: true));
  add(firstName, RegExp(r'[\s-]+'));
  add(lastName, RegExp(r'[\s-]+'));
  return parts;
}

bool hasRunOrSequence(String s) {
  final c = s.runes.toList();
  for (var i = 0; i + 3 < c.length; i++) {
    final d1 = c[i + 1] - c[i], d2 = c[i + 2] - c[i + 1], d3 = c[i + 3] - c[i + 2];
    final same = d1 == 0 && d2 == 0 && d3 == 0;
    final isLetterOrDigit = RegExp(r'[\p{L}0-9]', unicode: true).hasMatch(String.fromCharCode(c[i]));
    final step = isLetterOrDigit && d1 == d2 && d2 == d3 && d1.abs() == 1;
    if (same || step) return true;
  }
  return false;
}

bool isCommonPassword(String lower) {
  final letters = lower.replaceAll(RegExp(r'[^\p{L}0-9]', unicode: true), '');
  return _common.contains(letters) || _common.contains(letters.replaceAll(RegExp(r'[0-9]+$'), ''));
}

bool isPasswordOk(String password, List<String> personal) =>
    passwordRules.every((r) => r.ok(password, personal));
