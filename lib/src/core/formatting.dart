import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens. Dates are shown in the
/// office's local sense; the database stores timestamptz.

final _dateFmt = DateFormat('d MMM yyyy');
final _dateTimeFmt = DateFormat('d MMM yyyy, HH:mm');

String fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d.toLocal());
String fmtDateTime(DateTime? d) =>
    d == null ? '—' : _dateTimeFmt.format(d.toLocal());

String fmtDateOnly(DateTime? d) => d == null ? '—' : _dateFmt.format(d);

/// "3 days ago", "today", "in 2 days".
String fmtRelativeDays(DateTime? d) {
  if (d == null) return '—';
  final days = DateTime.now().difference(d).inDays;
  if (days == 0) return 'today';
  if (days > 0) return '$days day${days == 1 ? '' : 's'} ago';
  final ahead = -days;
  return 'in $ahead day${ahead == 1 ? '' : 's'}';
}

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String fmtMoney(num? v) => v == null ? '—' : _money.format(v);

/// Health score → colour. Green ≥ 75, amber 50–74, red < 50. Grey when unknown.
Color healthColor(int? score, ColorScheme scheme) {
  if (score == null) return scheme.outline;
  if (score >= 75) return const Color(0xFF2F9E44);
  if (score >= 50) return const Color(0xFFF08C00);
  return const Color(0xFFE03131);
}

String healthLabel(int? score) {
  if (score == null) return 'Not scored';
  if (score >= 75) return 'Healthy';
  if (score >= 50) return 'At risk';
  return 'Critical';
}

/// Severity → colour for chips.
Color severityColor(String severity) => switch (severity) {
      'S1' => const Color(0xFFE03131),
      'S2' => const Color(0xFFF08C00),
      'S3' => const Color(0xFF1971C2),
      _ => const Color(0xFF868E96),
    };
