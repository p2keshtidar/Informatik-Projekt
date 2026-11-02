import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/account.dart';
import '../models/user.dart';
import '../util/money.dart';
import 'login_screen.dart';

class AccountsScreen extends StatefulWidget {
  final User user;

  const AccountsScreen({super.key, required this.user});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _api = ApiClient();
  late Future<List<Account>> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = _api.accounts(widget.user.id);
  }

  Future<void> _reload() async {
    setState(() => _accounts = _api.accounts(widget.user.id));
    await _accounts;
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hallo ${widget.user.firstName}'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Account>>(
          future: _accounts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${snapshot.error}'),
                ),
              ]);
            }
            final accounts = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final a in accounts) _AccountCard(account: a)],
            );
          },
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.name, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(formatIban(account.iban), style: text.bodySmall),
            const SizedBox(height: 16),
            Text(formatCents(account.balanceCents), style: text.headlineSmall),
          ],
        ),
      ),
    );
  }
}
