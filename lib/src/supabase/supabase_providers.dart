import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The one Supabase client for the whole app. All data access goes through
/// this — there is no separate backend API to call. RLS does the authorising.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams auth state so the router can react to login/logout.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The current signed-in session, or null. Kept tiny on purpose.
final sessionProvider = Provider<Session?>((ref) {
  // Re-read whenever auth state changes.
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});
