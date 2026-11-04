import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';
import '../supabase/supabase_providers.dart';

/// A row of public.app_user — an internal user. Mirrors auth.users.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;
  final bool isActive;

  String get displayName => name.isNotEmpty ? name : email;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        role: AppRole.fromWire(m['role'] as String?),
        isActive: (m['is_active'] as bool?) ?? true,
      );
}

/// The signed-in user's app_user row (role, name, …). Null while loading or if
/// the login has not been provisioned yet (RLS then shows them nothing).
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final row = await client
      .from('app_user')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();
  return row == null ? null : AppUser.fromMap(row);
});

/// The current user's role, defaulting to Viewer until loaded.
final currentRoleProvider = Provider<AppRole>((ref) {
  return ref.watch(currentAppUserProvider).maybeWhen(
        data: (u) => u?.role ?? AppRole.viewer,
        orElse: () => AppRole.viewer,
      );
});

/// All active internal users — for owner / assignee pickers.
final activeUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('app_user')
      .select()
      .eq('is_active', true)
      .order('name');
  return (rows as List).map((e) => AppUser.fromMap(e as Map<String, dynamic>)).toList();
});
