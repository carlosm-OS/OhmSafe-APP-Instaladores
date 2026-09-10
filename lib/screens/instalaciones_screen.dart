import 'package:flutter/material.dart';
import 'service_steps_screen.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

/// Sección Instalaciones. Carga las órdenes de instalación desde el
/// repositorio (Mock o Api según `EnvConfig.useMock`). Cada orden arranca
/// el flujo de servicio (5 pasos).
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
  late final OrdenesRepository _repo;

  List<Orden> _ordenes = [];
  bool _loading = true;
  String? _error;

  /// Hoy (solo fecha) — origen del calendario horizontal.
  late final DateTime _today;

  /// Día seleccionado en el calendario (solo fecha). Filtra las instalaciones
  /// agendadas para ese día. Por defecto, hoy.
  late DateTime _selectedDate;

  /// Id de la tarjeta abierta (expandida). null = todas cerradas.
  String? _openId;

  static const List<String> _diasSemana = [
    'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom', // weekday 1..7
  ];

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(DateTime.now());
    _selectedDate = _today;
    _repo = sl.get<OrdenesRepository>();
    _cargar();
  }

  /// Fecha agendada (solo día) de una orden, o null si aún no está agendada
  /// o la fecha no parsea. Se usa para colocar cada instalación en su día.
  DateTime? _agendadaDate(Orden o) {
    if (!o.agendado || (o.fechaAgendada?.isEmpty ?? true)) return null;
    final dt = DateTime.tryParse(o.fechaAgendada!.replaceFirst(' ', 'T'));
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Días del calendario: 7 desde hoy, extendidos hasta la última fecha
  /// agendada si cae más adelante (para que ese día sea alcanzable). Se
  /// renderizan en un strip horizontal desplazable.
  List<DateTime> get _calendarDays {
    DateTime last = _today.add(const Duration(days: 6));
    for (final o in _ordenes) {
      final d = _agendadaDate(o);
      if (d != null && d.isAfter(last)) last = d;
    }
    final count = last.difference(_today).inDays + 1;
    return List.generate(count, (i) => _today.add(Duration(days: i)));
  }

  /// Cuántas instalaciones hay agendadas para [day] (para el badge del strip).
  int _countForDay(DateTime day) => _ordenes
      .where((o) {
        final d = _agendadaDate(o);
        return d != null && DateUtils.isSameDay(d, day);
      })
      .length;

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getOrdenes(tipo: 'instalacion');
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

  /// Estado a mostrar, aplicando el override de completado/cancelado que llega
  /// al volver del flujo de servicio.
  String _estadoDisplay(Orden orden) {
    if (widget.completedTicketTitle == orden.titulo) return 'Completo';
    if (widget.cancelledTicketTitle == orden.titulo) return 'Cancelado';
    switch (orden.estado) {
      case 'por_hacer':
        return 'Por hacer';
      case 'en_curso':
        return 'En curso';
      case 'completo':
        return 'Completo';
      case 'cancelado':
        return 'Cancelado';
      default:
        return orden.estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
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
                // Header
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

                // Back + title
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
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.titleLarge?.color),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(padding: const EdgeInsets.all(6), shape: const CircleBorder()),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Calendario horizontal (días reales desde hoy, desplazable).
                // Cada día filtra las instalaciones agendadas para esa fecha.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? cs.surface : ohm.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _calendarDays.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 4),
                        itemBuilder: (context, i) {
                          final day = _calendarDays[i];
                          final isActive = DateUtils.isSameDay(day, _selectedDate);
                          final isToday = DateUtils.isSameDay(day, _today);
                          final count = _countForDay(day);
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedDate = day;
                              _openId = null;
                            }),
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? (isDark ? cs.onSurfaceVariant : cs.onSurface) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isToday && !isActive
                                    ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.4)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_diasSemana[day.weekday - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isActive ? Colors.white.withValues(alpha: 0.8) : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5))),
                                  const SizedBox(height: 3),
                                  Text('${day.day}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isActive ? Colors.white : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8))),
                                  const SizedBox(height: 3),
                                  // Punto indicador si hay instalaciones agendadas ese día.
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: count > 0
                                          ? (isActive ? Colors.white : cs.primary)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Lista / carga / error / vacío
                Expanded(child: _buildBody(theme)),
              ],
            ),
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    if (_error != null) {
      return _buildErrorState(theme);
    }
    // Agendadas para el día seleccionado.
    final agendadasDia = _ordenes.where((o) {
      final d = _agendadaDate(o);
      return d != null && DateUtils.isSameDay(d, _selectedDate);
    }).toList();
    // Pendientes de agendar (sin fecha): sección aparte, siempre visible.
    final pendientes = _ordenes.where((o) => _agendadaDate(o) == null).toList();

    if (agendadasDia.isEmpty && pendientes.isEmpty) {
      return _buildEmptyState(theme);
    }

    final children = <Widget>[];

    // Sección: instalaciones del día.
    children.add(_sectionHeader(theme, _tituloDia(), Icons.event_available_rounded));
    if (agendadasDia.isEmpty) {
      children.add(_sinAgendadasHint(theme));
    } else {
      children.addAll(agendadasDia.map((o) => _buildTicketCard(o, _openId == o.id)));
    }

    // Sección: pendientes de agendar.
    if (pendientes.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(_sectionHeader(theme, 'Pendientes de agendar', Icons.schedule_rounded));
      children.addAll(pendientes.map((o) => _buildTicketCard(o, _openId == o.id)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  /// Título del día seleccionado ("Hoy", "Mañana" o "Vie 12 sep").
  String _tituloDia() {
    if (DateUtils.isSameDay(_selectedDate, _today)) return 'Hoy';
    if (DateUtils.isSameDay(_selectedDate, _today.add(const Duration(days: 1)))) return 'Mañana';
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${_diasSemana[_selectedDate.weekday - 1]} ${_selectedDate.day} ${meses[_selectedDate.month - 1]}';
  }

  Widget _sectionHeader(ThemeData theme, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  /// Aviso cuando el día seleccionado no tiene instalaciones agendadas.
  Widget _sinAgendadasHint(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Sin instalaciones agendadas para este día.',
        style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55), height: 1.4),
      ),
    );
  }

  Widget _buildTicketCard(Orden orden, bool isOpen) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    final status = _estadoDisplay(orden);

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
      case "Cancelado":
        statusBgColor = cs.errorContainer;
        statusTextColor = cs.error;
        break;
      default:
        statusBgColor = ohm.surfaceContainer;
        statusTextColor = cs.onSurfaceVariant;
    }
    final cancelado = status == "Cancelado";

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _openId = isOpen ? null : orden.id),
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
                    child: Text(orden.titulo, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4, color: theme.textTheme.bodyLarge?.color)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(status == "Cancelado" ? "CANCELADO" : status, style: TextStyle(color: statusTextColor, fontSize: 11, fontWeight: FontWeight.w700)),
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
                if (orden.plan.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detailRow(theme, "Plan: ", orden.plan),
                ],
                if (orden.agendado && (orden.fechaAgendada?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  _detailRow(theme, "Agendada: ", _formatFechaAgendada(orden.fechaAgendada!)),
                ],
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(orden.cliente, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: 18),
                if (!orden.agendado)
                  _pendienteAgendarPill(theme, cs, ohm)
                else
                  ElevatedButton(
                    onPressed: cancelado ? null : () => _showConfirmationDialog(context, orden),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cancelado ? (isDark ? cs.outline : cs.outlineVariant) : cs.primary,
                      foregroundColor: cancelado ? (isDark ? Colors.white30 : Colors.white70) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("Iniciar ruta de servicio", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
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

  /// Formatea la fecha ISO del backend ("2026-09-15 10:00:00") a algo legible
  /// como "15/09/2026 10:00". Si no parsea, devuelve el string original.
  String _formatFechaAgendada(String raw) {
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  /// Píldora informativa (no interactiva) cuando la orden aún no está agendada.
  /// El instalador no puede iniciar la ruta hasta que servicio confirme día/hora.
  Widget _pendienteAgendarPill(ThemeData theme, ColorScheme cs, OhmColors ohm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ohm.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Pendiente de agendar — el equipo de servicio confirmará día y hora",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: cs.onSurfaceVariant),
            ),
          ),
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
        MaterialPageRoute(builder: (_) => TruckAnimationPage(ticket: orden.toTicketMap())),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo iniciar la ruta: ${failure.message}")),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, Orden orden) {
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
                Text("¿Estás seguro de iniciar la ruta?", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 12),
                Text("El cliente será notificado que tu servicio está en camino", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), height: 1.4)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _iniciarServicio(orden);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
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
                  style: TextButton.styleFrom(foregroundColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text("Cancelar", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
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
          Text("No se pudieron cargar las instalaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), height: 1.4)),
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
          Icon(Icons.inbox_rounded, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text("Sin instalaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "No tienes tickets de instalaciones asignados para este día.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
