import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../supabase/supabase_providers.dart';

/// A row of module_master (Sales, Purchase, …). Reference data.
class Module {
  const Module({required this.id, required this.code, required this.name, required this.seq});
  final String id;
  final String code;
  final String name;
  final int seq;

  factory Module.fromMap(Map<String, dynamic> m) => Module(
        id: m['id'] as String,
        code: m['code'] as String,
        name: m['name'] as String,
        seq: (m['seq'] as int?) ?? 0,
      );
}

final modulesProvider = FutureProvider<List<Module>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('module_master')
      .select()
      .eq('is_active', true)
      .order('seq');
  return (rows as List).map((e) => Module.fromMap(e as Map<String, dynamic>)).toList();
});

/// id → Module, for quick lookups in lists.
final moduleByIdProvider = FutureProvider<Map<String, Module>>((ref) async {
  final list = await ref.watch(modulesProvider.future);
  return {for (final m in list) m.id: m};
});
