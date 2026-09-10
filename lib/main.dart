import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'controllers/app_state.dart';
import 'controllers/app_state_provider.dart';
import 'core/config/env_config.dart';
import 'core/di/injection_container.dart';
import 'core/push/push_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/instalaciones_screen.dart';
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
    apiBaseUrl: 'https://api-dev.dashboard.ohmsafe.com/v1',
    hubspotApiKey: '',
    useMock: false, // backend en dev (api-dev). Local: http://localhost:3001/v1
  );
  await sl.init(env);

  // Push (FCM) solo en Android/iOS; en macOS/desktop no hay Firebase configurado.
  if (PushService.soportado) {
    try {
      await Firebase.initializeApp();
      await PushService.instance.setupListeners();
    } catch (_) {
      // Nunca romper el arranque por push.
    }
  }

  runApp(const OhmSafeAppContainer());
}

/// Navegación global (para abrir pantallas al tocar una notificación push).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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

  @override
  void initState() {
    super.initState();
    // Al tocar la notificación de "instalación asignada", abre la lista.
    PushService.instance.onOpenInstalacion = (_) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const InstalacionesScreen()),
      );
    };
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sistema de tema "Faena" (lib/core/theme). Alto contraste para exterior,
    // áreas táctiles grandes y bordes en vez de sombras. Ver AppTheme.
    return MaterialApp(
      title: 'OhmSafe Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      themeMode: _themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: LoginScreen(onToggleTheme: _toggleTheme),
    );
  }
}
