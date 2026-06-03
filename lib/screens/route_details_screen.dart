import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'instalaciones_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const RouteDetailsScreen({super.key, required this.ticket});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  bool _isCancelling = false;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final details = widget.ticket["details"] as Map<String, String>;
    final isUrgent = widget.ticket["isUrgent"] as bool? ?? false;

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
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: theme.iconTheme.color?.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Back arrow and centered Title
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
                            "Detalles de Ruta",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
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

                // Content View
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Ticket details card for consistency and clarity
                      Card(
                        elevation: 0,
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.dividerColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.ticket["title"]!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
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
                              const SizedBox(height: 12),
                              Divider(height: 1, color: theme.dividerColor),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.ticket["user"]!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isUrgent)
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          "Urgente",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Route Details Actions Box
                      if (!_isCancelling) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              print("Llegada marcada");
                              Navigator.pop(context, 'arrived');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Marcar llegada",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isCancelling = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Cancelar instalación",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Motivo de la cancelación",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _reasonController,
                                maxLines: 3,
                                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                decoration: InputDecoration(
                                  hintText: "Escribe aquí el motivo...",
                                  hintStyle: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final reason = _reasonController.text.trim();
                                    print("Instalación cancelada. Motivo: $reason");
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InstalacionesScreen(
                                          cancelledTicketTitle: widget.ticket["title"],
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Confirmar cancelación",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isCancelling = false;
                                      _reasonController.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.textTheme.bodyMedium?.color,
                                  ),
                                  child: const Text(
                                    "Volver",
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar
          const AppBottomNav(),
        ],
      ),
    );
  }
}
