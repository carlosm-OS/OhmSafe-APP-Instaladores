// Primer ingreso del instalador: correo → (contraseña | código) → bienvenida → crear contraseña.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/auth/session_manager.dart';
import 'package:ohmsafe_app/core/auth/session_store.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/auth/domain/entities/acceso.dart';
import 'package:ohmsafe_app/features/auth/domain/entities/sesion.dart';
import 'package:ohmsafe_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:ohmsafe_app/screens/acceso_instalador_screens.dart';
import 'package:ohmsafe_app/screens/login_screen.dart';

class _FakeAuth implements AuthRepository {
  AccesoSiguiente siguiente = const AccesoSiguiente(siguiente: 'codigo', esperaSegundos: 60);
  Result<CodigoVerificado> codigo = const Success(CodigoVerificado(activacion: 'tok', primeraVez: true, nombre: 'Ana López', numeroInstalador: '55555'));
  final llamadas = <String>[];
  String? passwordEnviada;

  @override
  Future<Result<AccesoSiguiente>> solicitarAcceso({required String email, bool olvide = false}) async {
    llamadas.add('correo:$email:$olvide');
    return Success(olvide ? const AccesoSiguiente(siguiente: 'codigo', esperaSegundos: 60) : siguiente);
  }

  @override
  Future<Result<CodigoVerificado>> verificarCodigo({required String email, required String codigo}) async {
    llamadas.add('codigo:$codigo');
    return this.codigo;
  }

  @override
  Future<Result<Sesion>> activar({required String email, required String activacion, required String password}) async {
    passwordEnviada = password;
    return const FailureResult(ServerFailure('prueba: sin sesión'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home) => AppStateProvider(notifier: AppState(), child: MaterialApp(theme: AppTheme.light, home: home));

void main() {
  late _FakeAuth auth;
  setUp(() {
    auth = _FakeAuth();
    sl.registerSingleton<AuthRepository>(auth);
  });

  testWidgets('correo con contraseña ya creada: aparece el campo de contraseña y «¿Olvidaste tu contraseña?»', (t) async {
    auth.siguiente = const AccesoSiguiente(siguiente: 'password');
    await t.pumpWidget(_app(LoginScreen(onToggleTheme: () {})));
    expect(find.text('Contraseña'), findsNothing);
    await t.enterText(find.byType(TextField).first, 'juan@x.mx');
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('si en el teléfono ya entró alguien, abre directo en la contraseña y sin el aviso de primera vez', (t) async {
    final store = MemorySessionStore();
    await store.escribir(ClavesSesion.ultimoCorreo, 'cuadrilla1@ohmsafe.com');
    const env = EnvConfig(environment: Environment.development, apiBaseUrl: 'http://x', hubspotApiKey: '', useMock: false);
    sl.registerSingleton<SessionManager>(SessionManager(dio: DioClient(envConfig: env), store: store));
    // Las demás pruebas son de un teléfono donde nadie ha entrado.
    addTearDown(() => sl.registerSingleton<SessionManager>(SessionManager(dio: DioClient(envConfig: env), store: MemorySessionStore())));

    await t.pumpWidget(_app(LoginScreen(onToggleTheme: () {})));
    await t.pumpAndSettle();
    expect(find.text('cuadrilla1@ohmsafe.com'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('¿Primera vez?'), findsNothing);
    expect(auth.llamadas, isEmpty, reason: 'no debe pedir código ni consultar el correo');

    await t.tap(find.text('Cambiar'));
    await t.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('¿Primera vez?'), findsOneWidget);
  });

  testWidgets('primer ingreso: código → bienvenida de instalador certificado → crear contraseña', (t) async {
    await t.pumpWidget(_app(LoginScreen(onToggleTheme: () {})));
    await t.enterText(find.byType(TextField).first, 'ana@x.mx');
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, '123456'); // al completar 6 dígitos verifica sola
    // La foto de la bienvenida tiene un halo que pulsa sin fin: se avanza el reloj en vez de esperar a que «se asiente».
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(auth.llamadas, contains('codigo:123456'));
    expect(find.text('¡Bienvenido, Ana!'), findsOneWidget);
    expect(find.text('Instalador certificado OhmSafe'), findsOneWidget);
    expect(find.textContaining('mucho éxito'), findsOneWidget);
    expect(find.text('Instalador #55555'), findsOneWidget);

    await t.tap(find.text('Crear mi contraseña'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Crea tu contraseña'), findsOneWidget);
    final campos = find.byType(TextField);
    await t.enterText(campos.at(0), 'corta');
    await t.enterText(campos.at(1), 'corta');
    await t.tap(find.text('Crear contraseña y entrar'));
    await t.pump();
    expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
    await t.enterText(campos.at(0), 'Segura2026');
    await t.enterText(campos.at(1), 'Segura2027');
    await t.tap(find.text('Crear contraseña y entrar'));
    await t.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    await t.enterText(campos.at(1), 'Segura2026');
    await t.tap(find.text('Crear contraseña y entrar'));
    await t.pumpAndSettle();
    expect(auth.passwordEnviada, 'Segura2026');
  });

  testWidgets('código incorrecto: dice cuántos intentos quedan', (t) async {
    auth.codigo = const FailureResult(ServerFailure('El código no es correcto.', 'CODIGO_INCORRECTO', {'intentosRestantes': 3}));
    await t.pumpWidget(_app(CodigoAccesoScreen(email: 'ana@x.mx', onToggleTheme: () {})));
    await t.enterText(find.byType(TextField).first, '000000');
    await t.pumpAndSettle();
    expect(find.text('El código no es correcto. Te quedan 3 intentos.'), findsOneWidget);
  });

  testWidgets('«olvidé mi contraseña» no muestra la bienvenida: va directo a la contraseña nueva', (t) async {
    auth.codigo = const Success(CodigoVerificado(activacion: 'tok', primeraVez: false));
    await t.pumpWidget(_app(CodigoAccesoScreen(email: 'ana@x.mx', olvide: true, onToggleTheme: () {})));
    expect(find.text('Crea una contraseña nueva'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '654321');
    await t.pumpAndSettle();
    expect(find.text('Instalador certificado OhmSafe'), findsNothing);
    expect(find.text('Guardar y entrar'), findsOneWidget);
  });

  test('reglas de contraseña iguales al backend', () {
    expect(validarPasswordNueva('abc12'), isNotNull);
    expect(validarPasswordNueva('abcdefgh'), 'Combina letras y números.');
    expect(validarPasswordNueva('12345678'), 'Combina letras y números.');
    expect(validarPasswordNueva('Segura2026'), isNull);
  });

  testWidgets('crear contraseña: los campos conservan todo lo que se escribe, letra por letra', (t) async {
    await t.pumpWidget(_app(CrearPasswordScreen(email: 'ana@x.mx', activacion: 'tok', primeraVez: true, onToggleTheme: () {})));
    final campo = find.byKey(const ValueKey('password-nueva'));
    await t.tap(campo);
    var texto = '';
    for (final c in 'Segura2026'.split('')) {
      texto += c;
      await t.enterText(campo, texto);
      await t.pump();
    }
    expect(t.widget<TextField>(campo).controller!.text, 'Segura2026');
    // Sin la pista de «contraseña nueva» que dispara la sugerencia de iOS.
    expect(t.widget<TextField>(campo).autofillHints, isNot(contains(AutofillHints.newPassword)));
    expect(t.widget<TextField>(find.byKey(const ValueKey('password-confirmar'))).autofillHints ?? const <String>[], isEmpty);
  });

  testWidgets('«Pegar código» toma el código aunque se copie la frase del correo', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'Usa este código para activar tu cuenta: 211885 El código vence en 10 minutos.'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.pumpWidget(_app(CodigoAccesoScreen(email: 'ana@x.mx', onToggleTheme: () {})));
    await t.tap(find.text('Pegar código'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(auth.llamadas, contains('codigo:211885'));
  });

  testWidgets('«Pegar código» sin código en el portapapeles avisa y no verifica', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'hola'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.pumpWidget(_app(CodigoAccesoScreen(email: 'ana@x.mx', onToggleTheme: () {})));
    await t.tap(find.text('Pegar código'));
    await t.pump();
    expect(find.text('No encontramos un código de 6 dígitos en lo que copiaste.'), findsOneWidget);
    expect(auth.llamadas.where((l) => l.startsWith('codigo:')), isEmpty);
  });
}
