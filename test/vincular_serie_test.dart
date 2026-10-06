import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/core/utils/serie_qr.dart';
import 'package:ohmsafe_app/core/utils/ligado_cliente.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/link_energizer_screen.dart';

class _RepoSerieInstalada implements OrdenesRepository {
  final llamadas = <String>[];
  @override
  Future<Result<Map<String, dynamic>>> diagnosticoEnergizador(String serie, {String ordenId = ''}) async {
    llamadas.add('$serie@$ordenId');
    return FailureResult(ServerFailure('El número de serie $serie ya está registrado como instalado con otro cliente. Revisa la etiqueta del equipo o avisa a operaciones.', 'SERIE_YA_INSTALADA'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('serieDesdeQr', () {
    test('serie sola, dentro de texto o de un enlace', () {
      expect(serieDesdeQr(' ohm-carlos-dev-2 '), 'OHM-CARLOS-DEV-2');
      expect(serieDesdeQr('Energizador OhmSafe OHM-A1B2-C3 lote 4'), 'OHM-A1B2-C3');
      expect(serieDesdeQr('https://ohmsafe.com/e?serie=XY-99'), 'XY-99');
      expect(serieDesdeQr('ABC123'), 'ABC123');
      expect(serieDesdeQr('   '), '');
    });

    test('formato del inventario de Ohmbox (OS-OBV01-####), solo, en texto o en enlace', () {
      expect(serieDesdeQr('os-obv01-0007'), 'OS-OBV01-0007');
      expect(serieDesdeQr('OhmSafe Ohmbox OS-OBV01-0042 hecho en MX'), 'OS-OBV01-0042');
      expect(serieDesdeQr('https://ohmsafe.com/e?serie=OS-OBV01-0050'), 'OS-OBV01-0050');
    });
  });

  group('avisoLigadoCliente', () {
    test('ligado: sin aviso; sin cuenta u otro titular: aviso claro', () {
      expect(avisoLigadoCliente({'ligado': true}), isNull);
      expect(avisoLigadoCliente({'ligado': false, 'motivo': 'CLIENTE_SIN_CUENTA'}), contains('todavía no tiene cuenta'));
      expect(avisoLigadoCliente({'ligado': false, 'motivo': 'EQUIPO_DE_OTRO_TITULAR'}), contains('otro cliente'));
      expect(avisoLigadoCliente({'ligado': false}), contains('operaciones'));
    });
  });

  testWidgets('«Vincular» valida la serie escrita y el error de serie ya instalada sale ahí, sin cámara simulada', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 2.5; // 480 x 1680: la pantalla completa sin desplazar
    addTearDown(t.view.reset);
    final repo = _RepoSerieInstalada();
    sl.registerSingleton<OrdenesRepository>(repo);
    await t.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: const LinkEnergizerScreen(ticket: {'id': 'i24', 'title': 'Instalación'})),
    ));
    expect(find.text('Vincular'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'OHM-CARLOS-DEV-2');
    await t.tap(find.text('Vincular'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(repo.llamadas, ['OHM-CARLOS-DEV-2@i24'], reason: 'manda la orden para revisar la serie contra Odoo');
    expect(find.textContaining('ya está registrado como instalado'), findsOneWidget);
    expect(find.textContaining('No se pudo leer el equipo'), findsNothing);
    await t.pump(const Duration(seconds: 5)); // deja vencer los temporizadores del aviso
  });
}
