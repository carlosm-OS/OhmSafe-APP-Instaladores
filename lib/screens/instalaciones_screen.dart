import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import 'service_steps_screen.dart';
import '../widgets/app_bottom_nav.dart';

class InstalacionesScreen extends StatefulWidget {
  final String? cancelledTicketTitle;
  final String? completedTicketTitle;
  const InstalacionesScreen({
    super.key,
    this.cancelledTicketTitle,
    this.completedTicketTitle,
  });

  @override
  State<InstalacionesScreen> createState() => _InstalacionesScreenState();
}

class _InstalacionesScreenState extends State<InstalacionesScreen> {
  String _activeDay = "8"; // Lunes 8 activo por defecto
  int? _openTicketIndex = 0; // Primer ticket abierto por defecto

  final List<Map<String, String>> _calendarDays = [
    {"name": "Lun", "num": "8"},
    {"name": "Mar", "num": "9"},
    {"name": "Mie", "num": "10"},
    {"name": "Jue", "num": "11"},
    {"name": "Vie", "num": "12"},
    {"name": "Sab", "num": "13"},
    {"name": "Dom", "num": "14"},
  ];

  final Map<String, int> _defaultCountsByDay = {
    "8": 3,
    "9": 0,
    "10": 2,
    "11": 0,
    "12": 4,
    "13": 1,
    "14": 0,
  };

  final List<Map<String, dynamic>> _ticketTemplates = [
    {
      "title": "Ticket de Instalación Fortress + Pago Anual",
      "status": "Por hacer",
      "isUrgent": false,
      "details": {
        "openDays": "1",
        "createdDate": "7/02/2026",
        "metraje": "70m",
        "direccion": "Nellie Campobello 129 Col. Sn Pedro, Alcaldía A.Obregón",
        "ciudad": "CDMX",
        "cp": "10820",
        "telefono": "55 1455 6678"
      },
      "user": "Alfredo López"
    },
    {
      "title": "Ticket de Instalación Hogar Seguro Pago Mensual",
      "status": "Por hacer",
      "isUrgent": false,
      "details": {
        "openDays": "3",
        "createdDate": "22/05/2026",
        "metraje": "35m",
        "direccion": "Av. Universidad 1200 Col. Xoco, Benito Juárez",
        "ciudad": "CDMX",
        "cp": "03330",
        "telefono": "55 9876 5432"
      },
      "user": "Sonia Morales"
    },
    {
      "title": "Ticket de Instalación Hogar Seguro Pago Mensual",
      "status": "Completo",
      "isUrgent": false,
      "details": {
        "openDays": "4",
        "createdDate": "18/05/2026",
        "metraje": "40m",
        "direccion": "Insurgentes Sur 800 Col. Del Valle, Benito Juárez",
        "ciudad": "CDMX",
        "cp": "03100",
        "telefono": "55 1234 5678"
      },
      "user": "Sonia Morales"
    },
    {
      "title": "Ticket de Instalación Cerradura Inteligente",
      "status": "En curso",
      "isUrgent": true,
      "details": {
        "openDays": "2",
        "createdDate": "20/05/2026",
        "metraje": "15m",
        "direccion": "Temístocles 89, Miguel Hidalgo, CDMX",
        "ciudad": "CDMX",
        "cp": "11560",
        "telefono": "55 6677 8899"
      },
      "user": "Sonia Morales"
    }
  ];

  @override
  void initState() {
    super.initState();
    if (widget.cancelledTicketTitle != null) {
      for (var ticket in _ticketTemplates) {
        if (ticket["title"] == widget.cancelledTicketTitle) {
          ticket["status"] = "Cancelado";
        }
      }
    }
    if (widget.completedTicketTitle != null) {
      Map<String, dynamic>? completedTicket;
      for (var ticket in _ticketTemplates) {
        if (ticket["title"] == widget.completedTicketTitle) {
          ticket["status"] = "Completo";
          completedTicket = ticket;
          break;
        }
      }
      if (completedTicket != null) {
        _ticketTemplates.remove(completedTicket);
        _ticketTemplates.add(completedTicket);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    final count = state.instalacionesCount;
    final List<Map<String, dynamic>> displayedTickets = [];
    for (int i = 0; i < count; i++) {
      if (i < _ticketTemplates.length) {
        displayedTickets.add(_ticketTemplates[i]);
      } else {
        displayedTickets.add({
          "title": "Ticket de Instalación Adicional #${i + 1}",
          "status": "Por hacer",
          "isUrgent": false,
          "details": {
            "openDays": "0",
            "createdDate": DateTime.now().toLocal().toString().split(' ')[0],
            "metraje": "30m",
            "direccion": "Dirección de prueba adicional, CDMX",
            "ciudad": "CDMX",
            "cp": "11000",
            "telefono": "55 0000 0000"
          },
          "user": "Técnico Asignado"
        });
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Logo centrado, iconos derecha)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "OHM",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const Text(
                              "SAFE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5A00),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                isDark ? Icons.light_mode : Icons.dark_mode,
                                color: theme.iconTheme.color?.withOpacity(0.7),
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.notifications_none_rounded,
                                color: theme.iconTheme.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Back arrow and centered Title Row using a Stack for perfect centering
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Text(
                            "Instalaciones",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(6),
                              shape: const CircleBorder(),
                            ),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: theme.iconTheme.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Horizontal Calendar Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _calendarDays.map((day) {
                        final isActive = day["num"] == _activeDay;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeDay = day["num"]!;
                              _openTicketIndex = 0;
                              final dayCount = _defaultCountsByDay[_activeDay] ?? 0;
                              state.adjustCount('instalaciones', dayCount - state.instalacionesCount);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark ? const Color(0xFF475569) : const Color(0xFF1E293B))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  day["name"]!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? Colors.white.withOpacity(0.8)
                                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  day["num"]!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? Colors.white
                                        : theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Tickets List
                Expanded(
                  child: displayedTickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), // Extra bottom padding for bottom bar space
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayedTickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(displayedTickets[index], index, index == _openTicketIndex);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Barra de navegación compartida
          const AppBottomNav(),
        ], // Cierre del Stack
      ), // Cierre del Scaffold
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, int index, bool isOpen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final details = ticket["details"] as Map<String, String>;

    final status = ticket["status"] as String;
    Color statusBgColor;
    Color statusTextColor;
    switch (status) {
      case "Por hacer":
        statusBgColor = isDark ? const Color(0x331E40AF) : const Color(0xFFDBEAFE);
        statusTextColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF);
        break;
      case "Completo":
        statusBgColor = isDark ? const Color(0x33166534) : const Color(0xFFDCFCE7);
        statusTextColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534);
        break;
      case "En curso":
        statusBgColor = isDark ? const Color(0x3392400E) : const Color(0xFFFEF3C7);
        statusTextColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
        break;
      case "Cancelado":
        statusBgColor = isDark ? const Color(0x33EF4444) : const Color(0xFFFEE2E2);
        statusTextColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        break;
      default:
        statusBgColor = isDark ? const Color(0x33475569) : const Color(0xFFF1F5F9);
        statusTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _openTicketIndex = isOpen ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ticket Header: Title and Status Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket["title"]!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == "Cancelado" ? "CANCELADO" : status,
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (isOpen) ...[
                const SizedBox(height: 16),
                Text(
                  "Abierto por ${details["openDays"]} días",
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                    children: [
                      const TextSpan(text: "Fecha de Creación: ", style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: details["createdDate"]),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                    children: [
                      const TextSpan(text: "Metraje: ", style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: details["metraje"]),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                    children: [
                      const TextSpan(text: "Dirección: ", style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: details["direccion"]),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                        children: [
                          const TextSpan(text: "Ciudad: ", style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: details["ciudad"]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                        children: [
                          const TextSpan(text: "CP: ", style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: details["cp"]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                    children: [
                      const TextSpan(text: "Teléfono: ", style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: details["telefono"]),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket["user"]!,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              if (isOpen) ...[
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: status == "Cancelado"
                      ? null
                      : () => _showConfirmationDialog(context, ticket),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == "Cancelado"
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                        : const Color(0xFFFF5A00),
                    foregroundColor: status == "Cancelado"
                        ? (isDark ? Colors.white30 : Colors.white70)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Iniciar ruta de servicio",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "¿Estás seguro de iniciar la ruta?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "El cliente será notificado que tu servicio está en camino",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      print("Ruta iniciada");
                      Navigator.pop(context); // Cerrar modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TruckAnimationPage(ticket: ticket),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Iniciar ruta de servicio",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            "Sin instalaciones",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "No tienes tickets de instalaciones asignados para el día de hoy.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
