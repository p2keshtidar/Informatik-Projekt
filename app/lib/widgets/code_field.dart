import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Eingabefeld für den 6-stelligen Code aus der Mail
class CodeField extends StatelessWidget {
  final TextEditingController controller;

  const CodeField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Code aus der E-Mail', counterText: ''),
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(letterSpacing: 6, fontSize: 20),
      validator: (v) => v == null || v.length != 6 ? '6 Ziffern eingeben' : null,
    );
  }
}
