// Beträge kommen als Cent (int) vom Server: 123456 -> "1.234,56 €"
String formatCents(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final euros = (abs ~/ 100).toString();
  final rest = (abs % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) buffer.write('.');
    buffer.write(euros[i]);
  }
  return '${negative ? '-' : ''}$buffer,$rest €';
}

// DE89370400440532013000 -> DE89 3704 0044 0532 0130 00
String formatIban(String iban) {
  final parts = <String>[];
  for (var i = 0; i < iban.length; i += 4) {
    parts.add(iban.substring(i, i + 4 > iban.length ? iban.length : i + 4));
  }
  return parts.join(' ');
}
