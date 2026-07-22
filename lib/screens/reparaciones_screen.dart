import 'package:flutter/material.dart';
import 'service_steps_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Sección Reparaciones (accesible desde el Home).
/// Lista los tickets de reparación asignados; cada uno arranca el flujo
/// de servicio, donde el paso 3 es la variante de Reparación
/// (ReparacionScreen) porque el ticket lleva type: "reparacion".
class ReparacionesScreen extends StatefulWidget {
  const ReparacionesScreen({super.key});

  @override
  State<ReparacionesScreen> createState() => _ReparacionesScreenState();
}

class _ReparacionesScreenState extends State<ReparacionesScreen> {
  int? _openTicketIndex = 0; // Primer ticket abierto por defecto

  /// Tickets de reparación. En producción vienen del backend
  /// (HubSpot/Odoo); aquí como datos de prueba. El `type: "reparacion"`
  /// es lo que dispara la variante de Reparación en el paso 3.
  final List<Map<String, dynamic>> _repairTickets = [
    {
      "title": "Reparación de Cerca Eléctrica",
      "type": "reparacion",
      "status": "Por hacer",
      "isUrgent": true,
      "details": {
        "openDays": "1",
        "createdDate": "21/07/2026",
        "metraje": "65m",
        "direccion": "Cerrada de Puebla 45 Col. Roma Norte, Cuauhtémoc",
        "ciudad": "CDMX",
        "cp": "06700",
        "telefono": "55 2233 4455"
      },
      "user": "Mariana Ríos"
    },
    {
      "title": "Reparación por daño de energizador",
      "type": "reparacion",
      "status": "Por hacer",
      "isUrgent": false,
      "details": {
        "openDays": "2",
        "createdDate": "20/07/2026",
        "metraje": "40m",
        "direccion": "Av. Coyoacán 1500 Col. Del Valle, Benito Juárez",
        "ciudad": "CDMX",
        "cp": "03100",
        "telefono": "55 7788 9900"
      },
      "user": "Ernesto Padilla"
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Logo centrado, icono notificaciones derecha)
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
                            Text("OHM", style: TextStyle(fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color)),
                            const Text("SAFE", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5A00))),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.notifications_none_rounded, color: theme.iconTheme.color?.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Back arrow + centered title
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
                            "Reparaciones",
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
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tickets list
                Expanded(
                  child: _repairTickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _repairTickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(_repairTickets[index], index, index == _openTicketIndex);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Barra de navegación compartida
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, int index, bool isOpen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final details = ticket["details"] as Map<String, String>;
    final status = ticket["status"] as String;
    final isUrgent = ticket["isUrgent"] as bool? ?? false;

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
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _openTicketIndex = isOpen ? null : index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket["title"]!,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(status, style: TextStyle(color: statusTextColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: 16),
                Text("Abierto por ${details["openDays"]} días", style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(height: 6),
                _detailRow(theme, "Fecha de Creación: ", details["createdDate"]),
                const SizedBox(height: 6),
                _detailRow(theme, "Metraje: ", details["metraje"]),
                const SizedBox(height: 6),
                _detailRow(theme, "Dirección: ", details["direccion"]),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _detailRow(theme, "Ciudad: ", details["ciudad"]),
                    const SizedBox(width: 24),
                    _detailRow(theme, "CP: ", details["cp"]),
                  ],
                ),
                const SizedBox(height: 6),
                _detailRow(theme, "Teléfono: ", details["telefono"]),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text(
                        ticket["user"]!,
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (isUrgent)
                    Row(
                      children: const [
                        Icon(Icons.circle, size: 8, color: Colors.red),
                        SizedBox(width: 6),
                        Text("Urgente", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => _showConfirmationDialog(context, ticket),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text("Iniciar ruta de servicio", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String? value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
        children: [
          TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "¿Estás seguro de iniciar la ruta?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 12),
                Text(
                  "El cliente será notificado que tu servicio está en camino",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7), height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TruckAnimationPage(ticket: ticket)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("Iniciar ruta de servicio", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7)),
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
          Icon(Icons.build_circle_outlined, size: 48, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text("Sin reparaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "No tienes tickets de reparación asignados para hoy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
