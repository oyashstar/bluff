import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_providers.dart';

/// Reads/writes the app_setting key/value store. Writes are Admin-only (RLS).
class SettingsRepository {
  SettingsRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, String?>> all() async {
    final rows = await _client.from('app_setting').select('key, value');
    return {
      for (final r in (rows as List)) r['key'] as String: r['value'] as String?,
    };
  }

  Future<void> set(String key, String? value) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('app_setting').upsert({
      'key': key,
      'value': (value == null || value.trim().isEmpty) ? null : value.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': uid,
    }, onConflict: 'key');
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(supabaseClientProvider));
});

final appSettingsProvider = FutureProvider<Map<String, String?>>((ref) async {
  return ref.watch(settingsRepositoryProvider).all();
});

/// Keys used by the app. Kept here so there is one source of truth.
class SettingKeys {
  const SettingKeys._();
  static const companyName = 'company_name';
  static const erpCompanyCode = 'erp_company_code';
}
