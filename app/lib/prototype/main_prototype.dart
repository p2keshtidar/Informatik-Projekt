import 'package:flutter/material.dart';

import 'features.dart';
import 'schema.dart';

// Start: flutter run -d chrome -t lib/prototype/main_prototype.dart
void main() {
  runApp(const PrototypeApp());
}

class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHD Kontor – Prototyp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6B52), useMaterial3: true),
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static const _tabs = [kontoTab, ueberweisenTab, sparenTab, karteTab];
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isMore = _index == _tabs.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(isMore ? 'Weitere Bereiche' : _tabs[_index].title),
        actions: [
          IconButton(
            tooltip: 'Benachrichtigungen',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => _open(context, mehrFeatures.firstWhere((f) => f.title == 'Benachrichtigungen')),
          ),
        ],
      ),
      body: Column(children: [
        const _Banner(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: isMore ? _MoreList(onOpen: (f) => _open(context, f)) : SchemaView(feature: _tabs[_index]),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), label: t.title),
          const NavigationDestination(icon: Icon(Icons.apps), label: 'Mehr'),
        ],
      ),
    );
  }

  void _open(BuildContext context, Feature f) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(f.title)),
        body: Column(children: [
          const _Banner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SchemaView(feature: f),
              ),
            ),
          ),
        ]),
      ),
    ));
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'Prototyp: zeigt nur den Aufbau der App, ohne Funktion und ohne Daten.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MoreList extends StatelessWidget {
  final void Function(Feature) onOpen;

  const _MoreList({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final f in mehrFeatures)
          ListTile(
            leading: Icon(f.icon),
            title: Text(f.title),
            subtitle: Text(f.purpose, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: StatusChip(implemented: f.implemented),
            onTap: () => onOpen(f),
          ),
      ],
    );
  }
}
