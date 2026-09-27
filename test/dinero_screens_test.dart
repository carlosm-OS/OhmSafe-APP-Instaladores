// Pantallas de dinero (fase 5): Mis pagos y Cotizar venta renderizan el
// contrato y el formulario arma la cotización correcta sin tocar la red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/dinero/data/dinero_repository.dart';
import 'package:ohmsafe_app/features/dinero/domain/dinero.dart';
import 'package:ohmsafe_app/screens/cotizaciones_screen.dart';
import 'package:ohmsafe_app/screens/pagos_screen.dart';

class _FakeDinero extends DineroRepository {
  _FakeDinero() : super(dioClient: DioClient(envConfig: const EnvConfig(environment: Environment.development, apiBaseUrl: 'http://127.0.0.1:1', hubspotApiKey: '')));

  Map<String, dynamic>? ultimaCotizacion;

  @override
  Future<Result<ResumenPagos>> pagos() async => Success(ResumenPagos.fromJson({
        'pagos': [
          {'id': '224', 'referencia': 'Borrador', 'concepto': 'Intervención i12 · S00157', 'ordenId': 'i12', 'fecha': '2026-09-25', 'monto': 0, 'pendiente': 0, 'moneda': 'MXN', 'estado': 'pendiente_validacion'},
          {'id': '1', 'referencia': 'BILL/2026/0001', 'concepto': 'Intervención i10 · S00150', 'ordenId': 'i10', 'fecha': '2026-09-20', 'monto': 650, 'pendiente': 0, 'moneda': 'MXN', 'estado': 'pagado'},
        ],
        'totales': {'pagado': 650, 'porPagar': 0, 'pendienteValidacion': 0, 'moneda': 'MXN'},
      }));

  @override
  Future<Result<List<ProductoCatalogo>>> catalogo() async => const Success([
        ProductoCatalogo(id: 31, codigo: 'MO-ENERG-BAT', nombre: 'Cambio energizador con batería', descripcion: '', precio: 1500, categoria: 'Servicios', esServicio: true),
        ProductoCatalogo(id: 32, codigo: 'MO-MTTO-ANUAL', nombre: 'Mantenimiento preventivo anual', descripcion: '', precio: 1800, categoria: 'Servicios', esServicio: true),
      ]);

  @override
  Future<Result<List<Cotizacion>>> cotizaciones() async => const Success([
        Cotizacion(id: '158', referencia: 'S00158', cliente: 'Ana Prueba', fecha: '2026-09-25 21:06:52', total: 116.93, moneda: 'MXN', estado: 'enviada', urlPortal: 'https://odoo.test/my/orders/158'),
      ]);

  @override
  Future<Result<Cotizacion>> cotizar({required String nombre, required String email, String? telefono, String? direccion, String? ciudad, String? cp, required Map<int, double> lineas, String? nota}) async {
    ultimaCotizacion = {'nombre': nombre, 'email': email, 'lineas': Map.of(lineas), 'nota': nota};
    return const Success(Cotizacion(id: '159', referencia: 'S00159', cliente: 'Ana Prueba', fecha: '2026-09-25 22:00:00', total: 1740, moneda: 'MXN', estado: 'enviada'));
  }
}

Widget _app(Widget home) => AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  late _FakeDinero fake;
  setUp(() {
    fake = _FakeDinero();
    sl.registerSingleton<DineroRepository>(fake);
  });

  testWidgets('Mis pagos muestra totales y cada pago con su estado', (tester) async {
    await tester.pumpWidget(_app(const PagosScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Mis pagos'), findsOneWidget);
    expect(find.text('Intervención i12 · S00157'), findsOneWidget);
    expect(find.text('En revisión'), findsWidgets); // total + etiqueta del pago
    expect(find.text('Pagado'), findsWidgets);
    expect(find.text(r'$650.00'), findsWidgets);
    expect(find.text('BILL/2026/0001 · 20/09/2026'), findsOneWidget);
  });

  testWidgets('Cotizar venta lista mis cotizaciones con enlace de portal', (tester) async {
    await tester.pumpWidget(_app(const CotizacionesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Ana Prueba · S00158'), findsOneWidget);
    expect(find.text('Enviada'), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(find.text('Cotizar'), findsOneWidget);
  });

  testWidgets('el formulario arma la cotización con cliente, cantidades y nota', (tester) async {
    await tester.pumpWidget(_app(const NuevaCotizacionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cambio energizador con batería'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana Prueba');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo (ahí le llega la cotización)'), 'ana@example.com');
    // +1 energizador con batería, +2 mantenimiento
    final agregar = find.byTooltip('Agregar');
    await tester.tap(agregar.at(0));
    await tester.pump();
    await tester.tap(agregar.at(1));
    await tester.pump();
    await tester.tap(agregar.at(1));
    await tester.pump();
    await tester.dragUntilVisible(find.text(r'$5,100.00'), find.byType(ListView), const Offset(0, -200)); // 1500 + 2×1800
    expect(find.text(r'$5,100.00'), findsOneWidget);

    await tester.dragUntilVisible(find.widgetWithText(TextField, 'Nota para el cliente (opcional)'), find.byType(ListView), const Offset(0, -200));
    await tester.enterText(find.widgetWithText(TextField, 'Nota para el cliente (opcional)'), 'Barda de 40 m');
    await tester.dragUntilVisible(find.text('Cotizar y enviar al cliente'), find.byType(ListView), const Offset(0, -200));
    await tester.tap(find.text('Cotizar y enviar al cliente'));
    await tester.pumpAndSettle();

    expect(fake.ultimaCotizacion, isNotNull);
    expect(fake.ultimaCotizacion!['nombre'], 'Ana Prueba');
    expect(fake.ultimaCotizacion!['email'], 'ana@example.com');
    expect(fake.ultimaCotizacion!['lineas'], {31: 1.0, 32: 2.0});
    expect(fake.ultimaCotizacion!['nota'], 'Barda de 40 m');
  });

  testWidgets('sin productos no envía y avisa', (tester) async {
    await tester.pumpWidget(_app(const NuevaCotizacionScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana Prueba');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo (ahí le llega la cotización)'), 'ana@example.com');
    await tester.dragUntilVisible(find.text('Cotizar y enviar al cliente'), find.byType(ListView), const Offset(0, -200));
    await tester.tap(find.text('Cotizar y enviar al cliente'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Agrega al menos un producto.'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Agrega al menos un producto.'), findsOneWidget);
    expect(fake.ultimaCotizacion, isNull);
  });
}
