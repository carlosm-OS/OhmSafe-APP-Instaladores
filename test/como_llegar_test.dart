import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/como_llegar.dart';
import 'package:ohmsafe_app/features/ordenes/data/models/orden_model.dart';

void main() {
  final json = {
    'id': 'i24', 'tipo': 'instalacion', 'titulo': 'Instalación', 'estado': 'por_hacer', 'cliente': 'Carlos',
    'direccion': 'Nellie Campobello 12', 'ciudad': 'CDMX', 'cp': '01180', 'telefono': '55',
    'direccionCompleta': 'Nellie Campobello 12, Carola, 01180 CDMX, Ciudad de México, Mexico',
    'coordenadas': {'lat': 19.38, 'lng': -99.2},
  };

  test('el ticket sigue siendo Map<String, String> (route_details y service_steps lo castean así)', () {
    final details = OrdenModel.fromJson(json).toTicketMap()['details'];
    expect(details, isA<Map<String, String>>());
    final d = DestinoServicio.deDetalles(details as Map<String, String>);
    expect(d.tieneCoordenadas, isTrue);
    expect(d.consulta, '19.38,-99.2');
  });

  test('enlaces de cada app: coordenadas si las hay, dirección si no', () {
    const conCoord = DestinoServicio(direccion: 'Calle 1, CDMX', lat: 19.38, lng: -99.2);
    const soloTexto = DestinoServicio(direccion: 'Calle 1, CDMX');
    expect(rutaEn(AppMapas.google, conCoord).toString(), 'https://www.google.com/maps/dir/?api=1&destination=19.38%2C-99.2&travelmode=driving');
    expect(rutaEn(AppMapas.google, soloTexto).queryParameters['destination'], 'Calle 1, CDMX');
    expect(rutaEn(AppMapas.waze, conCoord).queryParameters, {'ll': '19.38,-99.2', 'navigate': 'yes'});
    expect(rutaEn(AppMapas.waze, soloTexto).queryParameters['q'], 'Calle 1, CDMX');
    expect(rutaEn(AppMapas.apple, soloTexto).queryParameters['daddr'], 'Calle 1, CDMX');
  });

  test('sin direccionCompleta (backend viejo) arma el texto con calle, CP y ciudad', () {
    final d = DestinoServicio.deDetalles({'direccion': 'Calle 1', 'cp': '72000', 'ciudad': 'Puebla', 'lat': '', 'lng': ''});
    expect(d.direccion, 'Calle 1, 72000 Puebla, México');
    expect(d.tieneCoordenadas, isFalse);
  });

  testWidgets('el botón abre la hoja con las apps y copiar dirección; sin destino no se pinta', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      BotonComoLlegar(destino: DestinoServicio(direccion: 'Calle 1, CDMX')),
      BotonComoLlegar(destino: DestinoServicio(direccion: '')),
    ]))));
    expect(find.text('Cómo llegar'), findsOneWidget);
    await t.tap(find.text('Cómo llegar'));
    await t.pumpAndSettle();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
    expect(find.text('Copiar dirección'), findsOneWidget);
  });
}
