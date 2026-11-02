import 'package:flutter/material.dart';

import '../util/password_rules.dart';

class PasswordChecklist extends StatelessWidget {
  final String password;
  final List<String> personal;

  const PasswordChecklist({super.key, required this.password, required this.personal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in passwordRules)
          Builder(builder: (context) {
            final ok = rule.ok(password, personal);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(children: [
                Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16, color: ok ? scheme.primary : scheme.outline),
                const SizedBox(width: 8),
                Text(rule.label, style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
          }),
      ],
    );
  }
}
