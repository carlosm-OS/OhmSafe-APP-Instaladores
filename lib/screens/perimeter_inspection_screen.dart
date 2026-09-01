import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import 'instalaciones_screen.dart';

class PerimeterInspectionScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const PerimeterInspectionScreen({super.key, required this.ticket});

  @override
  State<PerimeterInspectionScreen> createState() => _PerimeterInspectionScreenState();
}

class _PerimeterInspectionScreenState extends State<PerimeterInspectionScreen> {
  bool _isCancelling = false;
  final TextEditingController _reasonController = TextEditingController();

  // Obstacles to display in the 2-column grid
  final List<String> _obstacles = [
    'Malla ciclónica',
    'Vegetación',
    'Concertina',
    'Árboles',
    'Herrería',
    'Desniveles',
    'Arcos',
    'Cableado',
    'Altura superior',
  ];

  bool _noObstaclesSelected = false;
  final Set<String> _selectedObstacles = {};

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _toggleObstacle(String obstacle) {
    setState(() {
      if (obstacle == 'Perímetro sin obstáculos') {
        _noObstaclesSelected = !_noObstaclesSelected;
        if (_noObstaclesSelected) {
          _selectedObstacles.clear();
        }
      } else {
        _noObstaclesSelected = false;
        if (_selectedObstacles.contains(obstacle)) {
          _selectedObstacles.remove(obstacle);
        } else {
          _selectedObstacles.add(obstacle);
        }
      }
    });
  }

  bool get _hasSelection => _noObstaclesSelected || _selectedObstacles.isNotEmpty;

  bool _isSending = false;

  /// Guarda la inspección de perímetro en el backend (obstáculos + bandera
  /// "sin obstáculos") y, solo si tiene éxito, regresa 'perimeter_completed'.
  Future<void> _guardarInspeccion() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    final id = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final result = await sl.get<OrdenesRepository>().guardarInspeccion(
          id,
          sinObstaculos: _noObstaclesSelected,
          obstaculos: _selectedObstacles.toList(),
        );
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'perimeter_completed'),
      (failure) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo guardar la inspección: ${failure.message}")),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final details = widget.ticket["details"] as Map<String, String>;

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

                // Back arrow and Title
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
                            "Inspección del perímetro",
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

                // Main Content Scrollable
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Client & Metraje info card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Cliente:  ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.ticket["user"] ?? "Cliente",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Metros a instalar:  ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Text(
                                  details["metraje"] ?? "0m",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!_isCancelling) ...[
                        // Section Header
                        Text(
                          "OBSTÁCULOS EN EL TERRENO",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Option: Perímetro sin obstáculos (Full-width top tile)
                        _buildObstacleTile("Perímetro sin obstáculos", _noObstaclesSelected),
                        const SizedBox(height: 12),

                        // Grid of remaining obstacles (2 columns)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.6,
                          ),
                          itemCount: _obstacles.length,
                          itemBuilder: (context, index) {
                            final name = _obstacles[index];
                            final isSelected = _selectedObstacles.contains(name);
                            return _buildObstacleTile(name, isSelected);
                          },
                        ),
                        const SizedBox(height: 32),

                        // Main action: Completar perímetro
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_hasSelection && !_isSending)
                                ? _guardarInspeccion
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A00),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              disabledForegroundColor: isDark ? Colors.white30 : Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Completar perímetro",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: _hasSelection
                                      ? Colors.white
                                      : (isDark ? Colors.white30 : Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isCancelling = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textTheme.bodyLarge?.color,
                              side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Cancelar instalación",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Cancellation Motif UI
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

          // Shared Bottom Navigation Bar
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildObstacleTile(String name, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine if this tile is disabled because "Perímetro sin obstáculos" is selected
    final bool isDisabled = _noObstaclesSelected && name != 'Perímetro sin obstáculos';

    return GestureDetector(
      onTap: isDisabled ? null : () => _toggleObstacle(name),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0x33FF5A00) : const Color(0xFFFFF0E6))
                : (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF5A00)
                  : theme.dividerColor.withOpacity(0.3),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? const Color(0xFFFF8B4D) : const Color(0xFFD43F00))
                        : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Circular checkbox matching the UI
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF5A00)
                        : (isDark ? Colors.white30 : Colors.black12),
                    width: 2,
                  ),
                  color: isSelected ? const Color(0xFFFF5A00) : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
