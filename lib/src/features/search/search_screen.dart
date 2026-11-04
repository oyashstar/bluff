import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../supabase/supabase_providers.dart';

/// A single result row across any entity type.
class SearchHit {
  const SearchHit({required this.kind, required this.title, required this.subtitle, required this.route, required this.icon});
  final String kind;
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Searches clients, projects and queries in parallel. Small data, so a few
/// ILIKE queries with limits are plenty — no search index needed.
final searchResultsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return const [];
  final db = ref.watch(supabaseClientProvider);
  final like = '%$q%';

  final results = await Future.wait([
    db.from('client').select('id, code, name').or('name.ilike.$like,code.ilike.$like').limit(8),
    db.from('v_project_board').select('project_id, title, client_name').ilike('title', like).limit(8),
    db
        .from('query')
        .select('id, ticket_no, subject, client:client_id(name)')
        .or('subject.ilike.$like,ticket_no.ilike.$like')
        .limit(8),
  ]);

  final hits = <SearchHit>[];
  for (final c in (results[0] as List)) {
    hits.add(SearchHit(
      kind: 'Client',
      title: c['name'] as String,
      subtitle: c['code'] as String,
      route: '/clients/${c['id']}',
      icon: Icons.business_outlined,
    ));
  }
  for (final p in (results[1] as List)) {
    hits.add(SearchHit(
      kind: 'Project',
      title: p['title'] as String,
      subtitle: (p['client_name'] as String?) ?? '',
      route: '/projects/${p['project_id']}',
      icon: Icons.dashboard_outlined,
    ));
  }
  for (final qr in (results[2] as List)) {
    final client = (qr['client'] as Map?)?.cast<String, dynamic>();
    hits.add(SearchHit(
      kind: 'Query',
      title: qr['subject'] as String,
      subtitle: '${qr['ticket_no']} · ${client?['name'] ?? ''}',
      route: '/queries/${qr['id']}',
      icon: Icons.support_agent_outlined,
    ));
  }
  return hits;
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final q = ref.watch(searchQueryProvider).trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search clients, projects, queries…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: q.length < 2
          ? const EmptyState('Type at least 2 characters to search.', icon: Icons.search)
          : AsyncValueView(
              value: results,
              data: (hits) {
                if (hits.isEmpty) return EmptyState('No matches for "$q".');
                return ListView.separated(
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = hits[i];
                    return ListTile(
                      leading: Icon(h.icon),
                      title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(h.subtitle),
                      trailing: Chip(label: Text(h.kind), visualDensity: VisualDensity.compact),
                      onTap: () => context.go(h.route),
                    );
                  },
                );
              },
            ),
    );
  }
}
