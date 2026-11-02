class Account {
  final int id;
  final String type;
  final String name;
  final String iban;
  final int balanceCents;

  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.iban,
    required this.balanceCents,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as int,
        type: json['type'] as String,
        name: json['name'] as String,
        iban: json['iban'] as String,
        balanceCents: json['balanceCents'] as int,
      );
}
