import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../finance/stub_financial_provider.dart';
import 'settings_repository.dart';

/// Admin settings: the company profile and — the key piece — the Finsys ERP
/// company code the financial seam scopes outstanding to. Read-only for
/// non-admins (RLS also enforces this server-side).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/overview')),
        title: const Text('Settings'),
      ),
      body: AsyncValueView(
        value: settings,
        onRetry: () => ref.invalidate(appSettingsProvider),
        data: (map) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SeamCard(erpCode: map[SettingKeys.erpCompanyCode]),
            const SizedBox(height: 16),
            _SettingField(
              label: 'Company name',
              value: map[SettingKeys.companyName],
              hint: 'Finsys Infotech',
              editable: isAdmin,
              onSave: (v) => _save(ref, SettingKeys.companyName, v),
            ),
            _SettingField(
              label: 'Finsys ERP company code',
              value: map[SettingKeys.erpCompanyCode],
              hint: 'e.g. FG01',
              helper: 'The ERP is multi-company. This is the company code the '
                  'outstanding sync reads AR for. Per-client linkage uses each '
                  "client's own ERP client code.",
              editable: isAdmin,
              onSave: (v) => _save(ref, SettingKeys.erpCompanyCode, v),
            ),
            if (!isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Only an Admin can change these settings.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, String key, String? value) async {
    await ref.read(settingsRepositoryProvider).set(key, value);
    ref.invalidate(appSettingsProvider);
  }
}

class _SeamCard extends StatelessWidget {
  const _SeamCard({required this.erpCode});
  final String? erpCode;

  @override
  Widget build(BuildContext context) {
    final linked = financialSeamLive;
    final hasCode = erpCode != null && erpCode!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(linked ? Icons.link : Icons.link_off,
                  color: linked ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              Text('ERP financial seam', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text(
              linked
                  ? 'Live. The app reads outstanding from client_financial_snapshot.'
                  : 'Stubbed (default). Outstanding shows “not linked” everywhere. '
                      'Deploy the sync-financials Edge Function and build with '
                      '--dart-define=FINANCIAL_SEAM_LIVE=true to turn it on.',
            ),
            const SizedBox(height: 4),
            Text(
              hasCode
                  ? 'Company code set: $erpCode'
                  : 'No ERP company code set yet — set it below before enabling the seam.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingField extends StatefulWidget {
  const _SettingField({
    required this.label,
    required this.value,
    required this.editable,
    required this.onSave,
    this.hint,
    this.helper,
  });
  final String label;
  final String? value;
  final bool editable;
  final Future<void> Function(String?) onSave;
  final String? hint;
  final String? helper;

  @override
  State<_SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<_SettingField> {
  late final TextEditingController _c = TextEditingController(text: widget.value ?? '');
  bool _dirty = false;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _c,
              enabled: widget.editable && !_busy,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                helperText: widget.helper,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (widget.editable) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(
                onPressed: (!_dirty || _busy)
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.onSave(_c.text);
                        if (mounted) {
                          setState(() {
                            _busy = false;
                            _dirty = false;
                          });
                        }
                      },
                child: const Text('Save'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
