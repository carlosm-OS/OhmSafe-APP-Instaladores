import 'package:flutter/material.dart';
import '../controllers/app_state.dart';

class SimulationDrawer extends StatefulWidget {
  final AppState state;

  const SimulationDrawer({super.key, required this.state});

  @override
  State<SimulationDrawer> createState() => _SimulationDrawerState();
}

class _SimulationDrawerState extends State<SimulationDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.state.isSyncing) {
      _spinnerController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SimulationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isSyncing) {
      _spinnerController.repeat();
    } else {
      _spinnerController.stop();
    }
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hubspotColor = const Color(0xFFFF7A59);

    return Drawer(
      backgroundColor: theme.cardColor.withOpacity(0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListenableBuilder(
            listenable: widget.state,
            builder: (context, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Simulador",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: hubspotColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "HUBSPOT",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Modifica los contadores de tickets manualmente para validar la reactividad del home en tiempo real.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Controls List
                  Expanded(
                    child: ListView(
                      children: [
                        _buildControlRow("Instalaciones", "instalaciones", widget.state.instalacionesCount),
                        _buildControlRow("Reparaciones", "reparaciones", widget.state.reparacionesCount),
                        _buildControlRow("Mantenimientos", "mantenimientos", widget.state.mantenimientosCount),
                        _buildControlRow("Reemplazo equipo", "reemplazo", widget.state.reemplazoCount),
                        _buildControlRow("Reportar incidencias", "incidencias", widget.state.incidenciasCount),
                      ],
                    ),
                  ),

                  // Sync Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: widget.state.isSyncing
                            ? null
                            : () {
                                widget.state.syncWithHubspot();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hubspotColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: hubspotColor.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: hubspotColor.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.state.isSyncing) ...[
                              RotationTransition(
                                turns: _spinnerController,
                                child: const Icon(Icons.sync, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Sincronizando HubSpot...",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ] else ...[
                              const Icon(Icons.sync, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                "Sincronizar con HubSpot",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.state.syncStatusMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildControlRow(String label, String itemId, int count) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => widget.state.adjustCount(itemId, -1),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  shape: const CircleBorder(),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                ),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                child: Text(
                  "$count",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => widget.state.adjustCount(itemId, 1),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  shape: const CircleBorder(),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
