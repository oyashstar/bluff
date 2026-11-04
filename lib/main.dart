import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    // Fail loud and early rather than halfway through a screen. The app is
    // useless without a Supabase URL + anon key passed via --dart-define.
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The public client key (legacy "anon" key or the newer publishable key).
    // Still the anon/publishable key only — the service-role key never ships.
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FinsysTrackerApp()));
}

class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SUPABASE_URL and SUPABASE_ANON_KEY are not set.\n\n'
              'Pass them with --dart-define at build/run time.\n'
              'The service-role key must never be used here.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
