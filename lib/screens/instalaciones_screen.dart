import 'package:flutter/material.dart';
import 'service_steps_screen.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
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

  /// El calendario arranca compacto (la semana en curso) y se puede expandir
  /// al mes completo. Compacto por defecto porque el caso normal del
  /// instalador es "lo de hoy"; el mes sirve para ubicar trabajo mas adelante
  /// o revisar dias pasados.
  bool _mesExpandido = false;

  /// Mes que se esta viendo en la vista expandida (dia 1 del mes).
  late DateTime _mesVisible;

  static const List<String> _diasSemana = [
    'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom', // weekday 1..7
  ];

  static const List<String> _mesesLargos = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(DateTime.now());
    _selectedDate = _today;
    _mesVisible = DateTime(_today.year, _today.month);
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
  /// Celdas de la cuadricula del mes: se rellena con null hasta el primer dia
  /// para que cada fecha caiga bajo su nombre de dia (semana de lunes a
  /// domingo), y se completa la ultima fila.
  List<DateTime?> _celdasDelMes(DateTime mes) {
    final primero = DateTime(mes.year, mes.month, 1);
    final diasEnMes = DateUtils.getDaysInMonth(mes.year, mes.month);
    final huecoInicial = primero.weekday - 1; // lunes = 0
    final celdas = <DateTime?>[
      ...List.filled(huecoInicial, null),
      ...List.generate(diasEnMes, (i) => DateTime(mes.year, mes.month, i + 1)),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }
    return celdas;
  }

  /// ¿Sigue siendo trabajo por hacer? Regla base de las tarjetas: una orden
  /// completada o cancelada sale de la lista y del conteo del calendario.
  bool _esTrabajoVivo(Orden o) {
    if (widget.completedTicketTitle == o.titulo) return false;
    if (widget.cancelledTicketTitle == o.titulo) return false;
    return o.estado != 'completo' && o.estado != 'cancelado';
  }

  int _countForDay(DateTime day) => _ordenes
      .where(_esTrabajoVivo)
      .where((o) {
        final d = _agendadaDate(o);
        return d != null && DateUtils.isSameDay(d, day);
      })
      .length;

  /// Trae las instalaciones del backend.
  ///
  /// [silencioso] lo usa el gesto de jalar-para-recargar: el indicador propio
  /// del gesto ya comunica el progreso, y prender `_loading` reemplazaria la
  /// lista por un spinner de pantalla completa a media animacion.
  Future<void> _cargar({bool silencioso = false}) async {
    setState(() {
      if (!silencioso) _loading = true;
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
                        child: const NotificationBell(),
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

                // Calendario: semana compacta o mes completo (ver _buildCalendario).
                _buildCalendario(theme, cs, ohm, isDark),

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
    // REGLA 1 — la lista de trabajo solo muestra órdenes vivas. Una terminada
    // o cancelada ya no es trabajo por hacer: vive en Historial. Antes seguía
    // apareciendo en su día y ofreciendo "Iniciar ruta" sobre un servicio ya
    // cerrado (y esa acción vuelve a avisarle al cliente).
    final activas = _ordenes.where(_esTrabajoVivo).toList();

    final agendadasDia = activas.where((o) {
      final d = _agendadaDate(o);
      return d != null && DateUtils.isSameDay(d, _selectedDate);
    }).toList();
    // Pendientes de agendar (sin fecha): sección aparte, siempre visible.
    final pendientes = activas.where((o) => _agendadaDate(o) == null).toList();

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

    // Jalar hacia abajo vuelve a pedir las ordenes al backend: un ticket que
    // se agrega, cambia de etapa o se borra en Odoo se refleja sin salir de
    // la pantalla.
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        // AlwaysScrollable: el gesto debe funcionar aunque haya una sola
        // orden y la lista no llegue a desbordar la pantalla.
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: children,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendario
  // ---------------------------------------------------------------------------

  /// Selecciona un día y cierra la tarjeta abierta (que pertenecía a otro día).
  void _seleccionarDia(DateTime day) {
    setState(() {
      _selectedDate = day;
      _openId = null;
    });
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + delta);
    });
  }

  Widget _buildCalendario(ThemeData theme, ColorScheme cs, dynamic ohm, bool isDark) {
    final mesTitulo =
        '${_mesesLargos[_mesVisible.month - 1]} ${_mesVisible.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surface : ohm.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCabeceraMes(theme, cs, mesTitulo),
            // El cambio entre semana y mes se anima para que se lea como la
            // misma superficie creciendo, no como dos pantallas distintas.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _mesExpandido
                  ? _buildCuadriculaMes(theme, cs, isDark)
                  : _buildTiraSemana(theme, cs, isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// Encabezado: mes visible, navegación entre meses (solo con el mes abierto)
  /// y el botón que alterna semana/mes.
  Widget _buildCabeceraMes(ThemeData theme, ColorScheme cs, String mesTitulo) {
    final color = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // Se capitaliza solo la inicial: "septiembre 2026" -> "Septiembre 2026".
              mesTitulo[0].toUpperCase() + mesTitulo.substring(1),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (_mesExpandido) ...[
            _botonIcono(
              icono: Icons.chevron_left_rounded,
              tooltip: 'Mes anterior',
              color: color,
              onTap: () => _cambiarMes(-1),
            ),
            _botonIcono(
              icono: Icons.chevron_right_rounded,
              tooltip: 'Mes siguiente',
              color: color,
              onTap: () => _cambiarMes(1),
            ),
          ],
          _botonIcono(
            icono: _mesExpandido
                ? Icons.expand_less_rounded
                : Icons.calendar_month_rounded,
            tooltip: _mesExpandido ? 'Ver solo la semana' : 'Ver el mes completo',
            color: _mesExpandido ? cs.primary : color,
            onTap: () => setState(() {
              _mesExpandido = !_mesExpandido;
              // Al abrir el mes se muestra el del día seleccionado, no uno
              // arbitrario: así el día activo siempre está a la vista.
              if (_mesExpandido) {
                _mesVisible = DateTime(_selectedDate.year, _selectedDate.month);
              }
            }),
          ),
        ],
      ),
    );
  }

  /// Botón de icono con área táctil de 44x44 (mínimo de la guía).
  Widget _botonIcono({
    required IconData icono,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icono, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  /// Vista compacta: los días desde hoy, desplazable en horizontal.
  Widget _buildTiraSemana(ThemeData theme, ColorScheme cs, bool isDark) {
    return SizedBox(
      key: const ValueKey('tira-semana'),
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _calendarDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final day = _calendarDays[i];
          return SizedBox(
            width: 52,
            child: _celdaDia(theme, cs, isDark, day, mostrarNombreDia: true),
          );
        },
      ),
    );
  }

  /// Vista expandida: el mes completo en cuadrícula.
  Widget _buildCuadriculaMes(ThemeData theme, ColorScheme cs, bool isDark) {
    final celdas = _celdasDelMes(_mesVisible);
    final tenue = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5);

    return Column(
      key: const ValueKey('cuadricula-mes'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final d in _diasSemana)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tenue,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (int fila = 0; fila * 7 < celdas.length; fila++)
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: celdas[fila * 7 + col] == null
                      // Hueco de relleno: ocupa lugar para no descuadrar la fila.
                      ? const SizedBox(height: 48)
                      : _celdaDia(
                          theme,
                          cs,
                          isDark,
                          celdas[fila * 7 + col]!,
                          mostrarNombreDia: false,
                        ),
                ),
            ],
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Celda de un día, compartida por la tira y la cuadrícula: mismo aspecto y
  /// mismo significado del punto (hay instalaciones agendadas ese día).
  Widget _celdaDia(
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
    DateTime day, {
    required bool mostrarNombreDia,
  }) {
    final isActive = DateUtils.isSameDay(day, _selectedDate);
    final isToday = DateUtils.isSameDay(day, _today);
    final count = _countForDay(day);

    return Semantics(
      button: true,
      selected: isActive,
      label: '${day.day} de ${_mesesLargos[day.month - 1]}'
          '${count > 0 ? ', $count ${count == 1 ? 'instalación' : 'instalaciones'}' : ''}'
          '${isToday ? ', hoy' : ''}',
      child: GestureDetector(
        onTap: () => _seleccionarDia(day),
        // El hueco entre celdas tambien debe responder al toque: sin esto el
        // objetivo real es menor que la celda que se ve.
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: mostrarNombreDia ? null : 48,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? cs.onSurfaceVariant : cs.onSurface)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isActive
                ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.4)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mostrarNombreDia) ...[
                Text(
                  _diasSemana[day.weekday - 1],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.8)
                        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                ),
              ),
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
      ),
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
                if (orden.fechaPagoConfirmado?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  _detailRow(theme, "Pago confirmado: ", _formatFechaAgendada(orden.fechaPagoConfirmado!)),
                ],
                const SizedBox(height: 6),
                _detailRow(theme, "Contrato firmado: ", orden.contratoFirmado ? "Sí" : "Pendiente"),
                // Lo que el instalador debe saber ANTES de llegar: malla,
                // vegetación, mascotas, acceso... Se resalta si hay algo.
                if (orden.condicionesTerreno.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detailRow(theme, "Condiciones del terreno: ", orden.condicionesTerreno.join(', ')),
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
                    // Si el servicio ya arrancó, la acción retoma el paso
                    // pendiente; "iniciar ruta" solo aplica al primer paso
                    // (y es el único que avisa al cliente).
                    // Sin acción cuando no hay trabajo que hacer: cerrada,
                    // cancelada o aún sin agendar.
                    onPressed: (cancelado || !_esTrabajoVivo(orden) || orden.pasoActual == 'agendar')
                        ? null
                        : orden.enCurso
                            ? () => _retomarServicio(orden)
                            : () => _showConfirmationDialog(context, orden),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cancelado ? (isDark ? cs.outline : cs.outlineVariant) : cs.primary,
                      foregroundColor: cancelado ? (isDark ? Colors.white30 : Colors.white70) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(_etiquetaAccion(orden), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
  /// Texto del botón según el paso pendiente. "Continuar ·" deja claro que
  /// no se reinicia nada.
  String _etiquetaAccion(Orden orden) {
    switch (orden.pasoActual) {
      // REGLA 2 — una orden cerrada no ofrece acción de trabajo. Si llegara a
      // pintarse (p. ej. justo al volver del cierre, antes de refrescar), el
      // botón lo dice en vez de invitar a reiniciar el servicio.
      case 'completo':
        return "Servicio completado";
      case 'cancelado':
        return "Servicio cancelado";
      // REGLA 3 — sin fecha agendada no hay ruta que iniciar: agendar es de
      // operaciones, no del instalador.
      case 'agendar':
        return "Pendiente de agendar";
      case 'marcar_llegada':
        return "Continuar · Marcar llegada";
      case 'inspeccion':
        return "Continuar · Inspección del perímetro";
      case 'instalacion':
        return "Continuar · Registrar instalación";
      case 'vinculacion':
        return "Continuar · Vincular energizador";
      case 'cierre':
        return "Continuar · Cierre y firma";
      default:
        return "Iniciar ruta de servicio";
    }
  }

  /// Abre el flujo directamente en el paso pendiente, sin la animación de
  /// salida ni volver a marcar "en ruta" (eso ya quedó registrado en Odoo).
  Future<void> _retomarServicio(Orden orden) async {
    const paso = {
      'marcar_llegada': 1,
      'inspeccion': 2,
      'instalacion': 3,
      'vinculacion': 4,
      'cierre': 5,
    };
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceStepsScreen(
          ticket: orden.toTicketMap(),
          pasoInicial: paso[orden.pasoActual] ?? 1,
        ),
      ),
    );
    // Al volver, la orden pudo avanzar o completarse: se refresca.
    if (mounted) _cargar(silencioso: true);
  }

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
