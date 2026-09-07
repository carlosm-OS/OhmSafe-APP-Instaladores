import 'package:flutter/material.dart';
import 'service_steps_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

/// Sección Reparaciones (accesible desde el Home).
/// Carga las órdenes de reparación desde el repositorio (Mock o Api según
/// `EnvConfig.useMock`) y cada una arranca el flujo de servicio, donde el
/// paso 3 es la variante de Reparación.
class ReparacionesScreen extends StatefulWidget {
  const ReparacionesScreen({super.key});

  @override
  State<ReparacionesScreen> createState() => _ReparacionesScreenState();
}

class _ReparacionesScreenState extends State<ReparacionesScreen> {
  late final OrdenesRepository _repo;

  List<Orden> _ordenes = [];
  bool _loading = true;
  String? _error;
  int? _openIndex = 0;

  @override
  void initState() {
    super.initState();
    _repo = sl.get<OrdenesRepository>();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getOrdenes(tipo: 'reparacion');
    if (!mounted) return;
    result.fold(
      (ordenes) => setState(() {
        _ordenes = ordenes;
        _loading = false;
      }),
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
    );
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'por_hacer':
        return 'Por hacer';
      case 'en_curso':
        return 'En curso';
      case 'completo':
        return 'Completo';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                            Text("SAFE", style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.notifications_none_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
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

                // Lista / carga / error / vacío
                Expanded(child: _buildBody(theme)),
              ],
            ),
          ),

          // Barra de navegación compartida
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    if (_error != null) {
      return _buildErrorState(theme);
    }
    if (_ordenes.isEmpty) {
      return _buildEmptyState(theme);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _ordenes.length,
      itemBuilder: (context, index) =>
          _buildTicketCard(_ordenes[index], index, index == _openIndex),
    );
  }

  Widget _buildTicketCard(Orden orden, int index, bool isOpen) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    final status = _estadoLabel(orden.estado);

    Color statusBgColor;
    Color statusTextColor;
    switch (status) {
      case "Por hacer":
        statusBgColor = ohm.infoContainer;
        statusTextColor = ohm.info;
        break;
      case "Completo":
        statusBgColor = ohm.successContainer;
        statusTextColor = ohm.success;
        break;
      case "En curso":
        statusBgColor = ohm.warningContainer;
        statusTextColor = isDark ? ohm.warning : ohm.onWarningContainer;
        break;
      default:
        statusBgColor = ohm.surfaceContainer;
        statusTextColor = isDark ? cs.outline : cs.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _openIndex = isOpen ? null : index),
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
                      orden.titulo,
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
                Text("Abierto por ${orden.diasAbierto} días", style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(height: 6),
                _detailRow(theme, "Fecha de Creación: ", orden.fechaCreacion),
                const SizedBox(height: 6),
                _detailRow(theme, "Metraje: ", orden.metraje),
                const SizedBox(height: 6),
                _detailRow(theme, "Dirección: ", orden.direccion),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _detailRow(theme, "Ciudad: ", orden.ciudad),
                    const SizedBox(width: 24),
                    _detailRow(theme, "CP: ", orden.cp),
                  ],
                ),
                const SizedBox(height: 6),
                _detailRow(theme, "Teléfono: ", orden.telefono),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text(
                        orden.cliente,
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (orden.urgente)
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
                  onPressed: () => _showConfirmationDialog(context, orden),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
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
        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85)),
        children: [
          TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  /// Reporta el inicio de ruta al backend (repo) y, si va bien, entra al flujo.
  Future<void> _iniciarServicio(Orden orden) async {
    final result = await _repo.iniciarRuta(orden.id);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.push(
        context,
        // Compat: el flujo de servicio aún consume Map<String,dynamic>.
        MaterialPageRoute(builder: (_) => TruckAnimationPage(ticket: orden.toTicketMap())),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo iniciar la ruta: ${failure.message}")),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, Orden orden) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar modal
                      _iniciarServicio(orden);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
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
                    foregroundColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text("No se pudieron cargar las reparaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Reintentar"),
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text("Sin reparaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "No tienes tickets de reparación asignados para hoy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
