import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/csv_export.dart';
import '../../core/widgets.dart';
import 'client_form.dart';
import 'client_providers.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(clientSearchProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientListProvider);
    final canEdit = ref.watch(currentRoleProvider).canEditDelivery;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              final list = clients.valueOrNull ?? [];
              showExportDialog(
                context,
                title: 'Clients',
                headers: ['Code', 'Name', 'Segment', 'City', 'State', 'AMC', 'ERP code'],
                rows: [
                  for (final c in list)
                    [c.code, c.name, c.segment, c.city, c.state, c.amcStatus, c.erpClientCode],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => showClientForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New client'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search name or code',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onSearch('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: clients,
              onRetry: () => ref.invalidate(clientListProvider),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState('No clients yet. Add your first with “New client”.');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return ListTile(
                      leading: ClientAvatar(label: c.name),
                      title: Text(c.name),
                      subtitle: Text([c.code, c.segment, c.city].whereType<String>().join(' · ')),
                      trailing: c.amcStatus == null ? null : Text(c.amcStatus!),
                      onTap: () => context.go('/clients/${c.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
