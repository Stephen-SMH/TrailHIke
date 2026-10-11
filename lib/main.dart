import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'config.dart';
import 'services/backend.dart';
import 'services/fake_backend.dart';
import 'services/key_value_store.dart';
import 'services/location_source.dart';
import 'services/sos_message.dart';
import 'services/station_finder.dart';
import 'services/supabase_backend.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Backend backend;
  FakeBackend? demo;
  if (Env.hasBackend) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
    backend = SupabaseBackend(Supabase.instance.client);
  } else {
    backend = demo = FakeBackend(); // no server configured: demo mode
  }

  final app = AppState(
    backend: backend,
    kv: PrefsStore(await SharedPreferences.getInstance()),
    location: DeviceLocation(),
    stations: StationFinder(),
    launcher: PhoneLauncher(),
  );
  await app.load();
  if (demo != null) {
    app.updateLocation().then((f) {
      if (f != null) demo!.seedDemoHikers(f.lat, f.lon);
    });
  }
  runApp(TrailMarkApp(app));
}

/// Dark is the default.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

class TrailMarkApp extends StatelessWidget {
  final AppState app;
  const TrailMarkApp(this.app, {super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder: (_, mode, _) => MaterialApp(
      title: 'TrailMark',
      debugShowCheckedModeBanner: false,
      theme: DS.light(),
      darkTheme: DS.dark(),
      themeMode: mode,
      builder: (context, child) => PhoneFrame(child: child!),
      home: Shell(app, banner: Env.banner),
    ),
  );
}
