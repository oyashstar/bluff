import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_value_widget.dart';
import 'client_model.dart';
import 'client_providers.dart';
import 'client_repository.dart';

/// Create or edit a client. Minimal required fields (code, name); the rest is
/// optional and editable later.
Future<void> showClientForm(BuildContext context, WidgetRef ref, {Client? existing}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ClientFormDialog(existing: existing),
  );
  if (saved == true) {
    ref.invalidate(clientListProvider);
    if (existing != null) ref.invalidate(clientProvider(existing.id));
  }
}

class _ClientFormDialog extends ConsumerStatefulWidget {
  const _ClientFormDialog({this.existing});
  final Client? existing;

  @override
  ConsumerState<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _segment;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _erpVersion;
  late final TextEditingController _amcStatus;
  late final TextEditingController _erpClientCode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _segment = TextEditingController(text: e?.segment ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _erpVersion = TextEditingController(text: e?.erpVersion ?? '');
    _amcStatus = TextEditingController(text: e?.amcStatus ?? '');
    _erpClientCode = TextEditingController(text: e?.erpClientCode ?? '');
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _segment, _city, _state, _erpVersion, _amcStatus, _erpClientCode]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nz(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(clientRepositoryProvider);
    final model = Client(
      id: widget.existing?.id ?? '',
      code: _code.text.trim(),
      name: _name.text.trim(),
      segment: _nz(_segment),
      city: _nz(_city),
      state: _nz(_state),
      erpVersion: _nz(_erpVersion),
      amcStatus: _nz(_amcStatus),
      erpClientCode: _nz(_erpClientCode),
      amcExpiry: widget.existing?.amcExpiry,
      onboardedOn: widget.existing?.onboardedOn,
      accountOwnerUserId: widget.existing?.accountOwnerUserId,
    );
    try {
      if (widget.existing == null) {
        await repo.create(model);
      } else {
        await repo.update(widget.existing!.id, model);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not save: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New client' : 'Edit client'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: 'Code *'),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ]),
                TextFormField(controller: _segment, decoration: const InputDecoration(labelText: 'Segment')),
                Row(children: [
                  Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State'))),
                ]),
                Row(children: [
                  Expanded(child: TextFormField(controller: _erpVersion, decoration: const InputDecoration(labelText: 'ERP version'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _amcStatus, decoration: const InputDecoration(labelText: 'AMC status'))),
                ]),
                TextFormField(
                  controller: _erpClientCode,
                  decoration: const InputDecoration(
                    labelText: 'ERP client code',
                    helperText: 'Hand-entered. The only future ERP join key.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
