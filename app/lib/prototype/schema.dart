import 'package:flutter/material.dart';

// Bausteine für den Prototyp: graue, beschriftete Flächen statt echter Daten
enum Kind { area, chart, list, field, button, toggle, steps, chips }

class Part {
  final Kind kind;
  final String label;
  final List<String> items;

  const Part(this.kind, this.label, [this.items = const []]);
}

class Section {
  final String title;
  final List<Part> elements;

  const Section(this.title, this.elements);
}

class Feature {
  final String title;
  final IconData icon;
  final String purpose;
  final bool implemented;
  final List<Section> sections;

  const Feature({
    required this.title,
    required this.icon,
    required this.purpose,
    required this.sections,
    this.implemented = false,
  });
}

class StatusChip extends StatelessWidget {
  final bool implemented;

  const StatusChip({super.key, required this.implemented});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: implemented ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        implemented ? 'im Code umgesetzt' : 'geplant',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class SchemaView extends StatelessWidget {
  final Feature feature;

  const SchemaView({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text(feature.purpose, style: text.bodyMedium)),
          const SizedBox(width: 12),
          StatusChip(implemented: feature.implemented),
        ]),
        for (final s in feature.sections) ...[
          const SizedBox(height: 24),
          Text(s.title, style: text.titleMedium),
          const SizedBox(height: 8),
          for (final e in s.elements) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ElementView(element: e),
          ),
        ],
      ],
    );
  }
}

class _ElementView extends StatelessWidget {
  final Part element;

  const _ElementView({required this.element});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget box(Widget child, {double? height}) => Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        );

    switch (element.kind) {
      case Kind.area:
        return box(Text(element.label, style: muted), height: 72);
      case Kind.chart:
        return box(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(element.label, style: muted),
            const Spacer(),
            Icon(Icons.show_chart, size: 48, color: scheme.outline),
          ]),
          height: 140,
        );
      case Kind.list:
        return box(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(element.label, style: muted),
            for (final item in element.items)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.circle, size: 8, color: scheme.outline),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                  Icon(Icons.chevron_right, size: 18, color: scheme.outline),
                ]),
              ),
          ],
        ));
      case Kind.field:
        return TextField(
          enabled: false,
          decoration: InputDecoration(labelText: element.label, border: const OutlineInputBorder()),
        );
      case Kind.button:
        return FilledButton.tonal(onPressed: null, child: Text(element.label));
      case Kind.toggle:
        return box(Row(children: [
          Expanded(child: Text(element.label)),
          const Switch(value: false, onChanged: null),
        ]));
      case Kind.steps:
        return Row(children: [
          for (var i = 0; i < element.items.length; i++) ...[
            if (i > 0) Expanded(child: Divider(color: scheme.outlineVariant)),
            CircleAvatar(radius: 12, child: Text('${i + 1}', style: text.labelSmall)),
            const SizedBox(width: 6),
            Text(element.items[i], style: text.bodySmall),
          ],
        ]);
      case Kind.chips:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in element.items) Chip(label: Text(item)),
        ]);
    }
  }
}
