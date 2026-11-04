import 'package:flutter/material.dart';

import 'enums.dart';
import 'formatting.dart';

/// A rounded pill: coloured dot + score on a tinted background, with the health
/// breakdown on hover/long-press.
class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.score, this.breakdown});
  final int? score;
  final Map<String, dynamic>? breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = healthColor(score, scheme);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(score?.toString() ?? '—',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
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
    return lines.isEmpty ? null : 'Health breakdown\n${lines.join('\n')}';
  }
}

class SeverityChip extends StatelessWidget {
  const SeverityChip(this.severity, {super.key});
  final QuerySeverity severity;

  @override
  Widget build(BuildContext context) {
    final c = severityColor(severity.wire);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
      child: Text(severity.short,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Deterministic coloured initials avatar for a client / entity.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.label, this.radius = 20});
  final String label;
  final double radius;

  static const _palette = [
    Color(0xFF3B5BDB), Color(0xFF0CA678), Color(0xFFE8590C), Color(0xFF9C36B5),
    Color(0xFF1098AD), Color(0xFFD6336C), Color(0xFF5C940D), Color(0xFF1864AB),
  ];

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '?' : label.trim();
    final initials = text.length >= 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase();
    final color = _palette[text.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(initials,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: radius * 0.7)),
    );
  }
}

/// A titled section divider for forms and detail screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Text(title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  )),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// A KPI card: icon chip, big value, label. Shared by Overview and dashboards.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });
  final String label;
  final Widget value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                child: value,
              ),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact SLA chip for an open ticket, or null when there is nothing worth
/// flagging (on-track / closed). Approximate (wall-clock, ignores paused-time
/// extension) — the SLA board view is the authoritative, business-hours source.
Widget? slaChip({required bool open, required bool paused, DateTime? resolutionDue}) {
  if (!open) return null;
  if (paused) {
    return const StatusChip('Paused', color: Color(0xFFF08C00), icon: Icons.pause_circle_outline);
  }
  if (resolutionDue == null) return null;
  final now = DateTime.now();
  if (now.isAfter(resolutionDue)) {
    return const StatusChip('SLA breach', color: Color(0xFFE03131), icon: Icons.error_outline);
  }
  if (resolutionDue.difference(now).inHours <= 4) {
    return const StatusChip('At risk', color: Color(0xFFF08C00), icon: Icons.warning_amber_rounded);
  }
  return null;
}

Color stageStatusColor(StageStatus s, ColorScheme scheme) => switch (s) {
      StageStatus.done => const Color(0xFF2F9E44),
      StageStatus.inProgress => const Color(0xFF1971C2),
      StageStatus.blocked => const Color(0xFFE03131),
      StageStatus.skipped => scheme.outline,
      StageStatus.pending => scheme.outlineVariant,
    };

Color queryStatusColor(QueryStatus s, ColorScheme scheme) => switch (s) {
      QueryStatus.newQuery => const Color(0xFF7048E8),
      QueryStatus.acknowledged || QueryStatus.inProgress || QueryStatus.reopened =>
        const Color(0xFF1971C2),
      QueryStatus.awaitingClient || QueryStatus.awaitingDev => const Color(0xFFF08C00),
      QueryStatus.resolved || QueryStatus.closed => const Color(0xFF2F9E44),
      QueryStatus.cancelled => scheme.outline,
    };
