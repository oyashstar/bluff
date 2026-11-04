import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phase 4 export. Builds RFC-4180 CSV (opens cleanly in Excel) from in-memory
/// rows that were already fetched from a view, and offers it via a preview +
/// copy-to-clipboard dialog. This compiles on web, Android and iOS with no
/// platform plugin; a native file-save (file_saver/share_plus) can be layered
/// on later without changing call sites.
String buildCsv(List<String> headers, List<List<Object?>> rows) {
  String cell(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  final buffer = StringBuffer()..writeln(headers.map(cell).join(','));
  for (final r in rows) {
    buffer.writeln(r.map(cell).join(','));
  }
  return buffer.toString();
}

Future<void> showExportDialog(
  BuildContext context, {
  required String title,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final csv = buildCsv(headers, rows);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Export · $title'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rows.length} rows. Copy and paste into Excel or a .csv file.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(csv,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: csv));
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
              Navigator.pop(ctx);
            }
          },
          icon: const Icon(Icons.copy_all),
          label: const Text('Copy CSV'),
        ),
      ],
    ),
  );
}
