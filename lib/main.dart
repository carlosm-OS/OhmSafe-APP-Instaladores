import 'package:flutter/material.dart';
import 'controllers/app_state.dart';
import 'controllers/app_state_provider.dart';
import 'core/config/env_config.dart';
import 'core/di/injection_container.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de entorno. useMock=true → la app corre 100% sin backend
  // (datasources Mock con la forma del contrato). Para enchufar el backend
  // real (local): pon useMock=false. apiBaseUrl ya apunta al backend local.
  //   - Web/desktop en la Mac → http://localhost:3001/v1
  //   - Simulador iOS         → http://localhost:3001/v1 (mismo host)
  //   - Emulador Android      → usa http://10.0.2.2:3001/v1
  const env = EnvConfig(
    environment: Environment.development,
    apiBaseUrl: 'http://localhost:3001/v1',
    hubspotApiKey: '',
    useMock: true, // ← cambiar a false cuando el backend local esté arriba
  );
  await sl.init(env);

  runApp(const OhmSafeAppContainer());
}

class OhmSafeAppContainer extends StatefulWidget {
  const OhmSafeAppContainer({super.key});

  @override
  State<OhmSafeAppContainer> createState() => _OhmSafeAppContainerState();
}

class _OhmSafeAppContainerState extends State<OhmSafeAppContainer> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      notifier: _appState,
      child: const OhmSafeApp(),
    );
  }
}

class OhmSafeApp extends StatefulWidget {
  const OhmSafeApp({super.key});

  @override
  State<OhmSafeApp> createState() => _OhmSafeAppState();
}

class _OhmSafeAppState extends State<OhmSafeApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const orangeAccent = Color(0xFFFF5A00);
    const darkBlueBg = Color(0xFF0B0F19);
    const darkBlueCard = Color(0xFF1E293B);

    return MaterialApp(
      title: 'OhmSafe Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      
      // Light Theme configuration
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: orangeAccent,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFECECF1),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'System',
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF1E293B),
            fontFamily: 'System',
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF64748B),
            fontFamily: 'System',
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orangeAccent,
          brightness: Brightness.light,
          primary: orangeAccent,
          surface: const Color(0xFFF8F8FA),
        ),
        useMaterial3: true,
      ),

      // Dark Theme configuration
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: orangeAccent,
        scaffoldBackgroundColor: darkBlueBg,
        cardColor: darkBlueCard,
        dividerColor: const Color(0xFF334155),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'System',
          ),
          bodyLarge: TextStyle(
            color: Color(0xFFF8FAFC),
            fontFamily: 'System',
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'System',
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orangeAccent,
          brightness: Brightness.dark,
          primary: orangeAccent,
          background: darkBlueBg,
          surface: const Color(0xFF111827),
        ),
        useMaterial3: true,
      ),
      
      home: LoginScreen(onToggleTheme: _toggleTheme),
    );
  }
}
