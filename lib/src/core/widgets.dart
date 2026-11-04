import 'package:flutter/material.dart';

import 'enums.dart';
import 'formatting.dart';

/// A small coloured dot + score, with the health breakdown on hover/long-press.
class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.score, this.breakdown});
  final int? score;
  final Map<String, dynamic>? breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = healthColor(score, scheme);
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(score?.toString() ?? '—', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
    final tip = _breakdownText(breakdown);
    return tip == null ? chip : Tooltip(message: tip, child: chip);
  }

  static String? _breakdownText(Map<String, dynamic>? b) {
    if (b == null || b.isEmpty) return null;
    String line(String key, String label) {
      final part = b[key];
      if (part is Map && part['score'] != null) return '$label: ${part['score']}';
      return '';
    }
    final lines = [
      line('stage_overrun', 'Stage overrun'),
      line('open_severity', 'Open severity'),
      line('staleness', 'Staleness'),
      line('signoff_pending', 'Sign-off pending'),
      line('golive_revisions', 'Go-live revisions'),
    ].where((l) => l.isNotEmpty);
    return lines.isEmpty ? null : lines.join('\n');
  }
}

class SeverityChip extends StatelessWidget {
  const SeverityChip(this.severity, {super.key});
  final QuerySeverity severity;

  @override
  Widget build(BuildContext context) {
    final c = severityColor(severity.wire);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(severity.short, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

Color stageStatusColor(StageStatus s, ColorScheme scheme) => switch (s) {
      StageStatus.done => const Color(0xFF2E7D32),
      StageStatus.inProgress => const Color(0xFF1565C0),
      StageStatus.blocked => const Color(0xFFC62828),
      StageStatus.skipped => scheme.outline,
      StageStatus.pending => scheme.outlineVariant,
    };

Color queryStatusColor(QueryStatus s, ColorScheme scheme) => switch (s) {
      QueryStatus.newQuery => const Color(0xFF6A1B9A),
      QueryStatus.acknowledged || QueryStatus.inProgress || QueryStatus.reopened =>
        const Color(0xFF1565C0),
      QueryStatus.awaitingClient || QueryStatus.awaitingDev => const Color(0xFFF9A825),
      QueryStatus.resolved || QueryStatus.closed => const Color(0xFF2E7D32),
      QueryStatus.cancelled => scheme.outline,
    };
