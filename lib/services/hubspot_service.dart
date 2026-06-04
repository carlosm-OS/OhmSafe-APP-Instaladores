import 'dart:math';
import '../models/ticket.dart';

class HubspotService {
  static final List<Ticket> staticTicketsMock = [
    Ticket(
      id: 1,
      title: "Ticket de Instalación Fortress + Pago Anual",
      isUrgent: true,
      details: [
        "Abierto por 1 días",
        "Fecha de Creación: 7/02/2026",
        "Metraje: 70m",
        "Dirección: Nellie Campobello 129 Col. Sn Pedro, CDMX"
      ],
      user: "Alfredo López",
    ),
    Ticket(
      id: 2,
      title: "Ticket de Instalación Hogar Seguro Pago Mensual",
      isUrgent: false,
      details: [
        "Abierto por 3 días",
        "Fecha de Creación: 22/05/2026",
        "Metraje: 35m",
        "Dirección: Av. Universidad 1200 Col. Xoco, Benito Juárez"
      ],
      user: "Sonia Morales",
    ),
    Ticket(
      id: 3,
      title: "Ticket de Instalación Cámara Exterior PoE + Alarma",
      isUrgent: false,
      details: [
        "Abierto por 0 días",
        "Fecha de Creación: 25/05/2026",
        "Metraje: 40m",
        "Dirección: Av. Horacio 450, Polanco, CDMX"
      ],
      user: "Alfredo López",
    ),
    Ticket(
      id: 4,
      title: "Ticket de Instalación Cerradura Inteligente",
      isUrgent: true,
      details: [
        "Abierto por 3 días",
        "Fecha de Creación: 22/05/2026",
        "Metraje: 15m",
        "Dirección: Temístocles 89, Miguel Hidalgo, CDMX"
      ],
      user: "Sonia Morales",
    ),
  ];

  final Random _random = Random();

  Future<Map<String, int>> simulateSync() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    return {
      'instalaciones': _random.nextInt(5), // 0 to 4
      'reparaciones': _random.nextInt(3), // 0 to 2
      'mantenimientos': _random.nextInt(2), // 0 to 1
      'reemplazo': 0,
      'incidencias': _random.nextDouble() > 0.6 ? 1 : 0,
    };
  }

  List<Ticket> getTicketsForCount(int count) {
    List<Ticket> list = [];
    for (int i = 0; i < count; i++) {
      if (i < staticTicketsMock.length) {
        list.add(staticTicketsMock[i]);
      } else {
        list.add(
          Ticket(
            id: i + 1,
            title: "Ticket de Instalación Adicional #${i + 1}",
            isUrgent: false,
            details: [
              "Abierto por 0 días",
              "Fecha de Creación: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
              "Dirección: Dirección de prueba, CDMX"
            ],
            user: "Técnico Asignado",
          ),
        );
      }
    }
    return list;
  }
}
