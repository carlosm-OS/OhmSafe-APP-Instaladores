import '../core/utils/como_llegar.dart';
import 'package:flutter/material.dart';
import 'service_steps_screen.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ayuda.dart';
import '../widgets/movimiento.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/utils/fechas_odoo.dart';
import '../widgets/hoja_decision.dart';

/// Sección Instalaciones. Carga las órdenes de instalación desde el
/// repositorio (Mock o Api según `EnvConfig.useMock`). Cada orden arranca
/// el flujo de servicio (5 pasos).
class InstalacionesScreen extends StatefulWidget {
  final String? cancelledTicketTitle;
  final String? completedTicketTitle;

  /// Tipo de servicio que lista: instalacion (por defecto), mantenimiento, reparacion, reemplazo.
  final String tipo;
  final String titulo;
  const InstalacionesScreen({super.key, this.cancelledTicketTitle, this.completedTicketTitle, this.tipo = 'instalacion', this.titulo = 'Instalaciones'});

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

  /// Id de la tarjeta abierta (con todos sus datos). null = todas con lo esencial.
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

  static const List<String> _diasLargos = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

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
    if (!o.agendado) return null;
    // Odoo guarda en UTC; el dia se decide ya en la zona del dispositivo.
    return FechasOdoo.soloDia(o.fechaAgendada);
  }

  /// Días del calendario: 7 desde hoy, extendidos hasta la última fecha
  /// agendada si cae más adelante (para que ese día sea alcanzable). Se
  /// renderizan en un strip horizontal desplazable.
  List<DateTime> get _calendarDays {
    DateTime last = _today.add(const Duration(days: 6));
    for (final o in _ordenes) {
      final d = FechasOdoo.soloDia(o.fechaFin) ?? _agendadaDate(o);
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
    final celdas = <DateTime?>[...List.filled(huecoInicial, null), ...List.generate(diasEnMes, (i) => DateTime(mes.year, mes.month, i + 1))];
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

  /// ¿La orden ocupa [day]? Una instalación de varios días ocupa cada día de su rango.
  bool _ocupaDia(Orden o, DateTime day) => o.agendado && FechasOdoo.cubreDia(o.fechaAgendada, o.fechaFin, day);

  int _countForDay(DateTime day) => _ordenes.where(_esTrabajoVivo).where((o) => _ocupaDia(o, day)).length;

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
    final result = await _repo.getOrdenes(tipo: widget.tipo);
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

  /// «instalaciones» en los textos de vacío y error (o el título de la sección, si lista otro tipo).
  String get _plural => widget.tipo == 'instalacion' ? 'instalaciones' : widget.titulo.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // v2 (2026-10-23): encabezado único, sin logo repetido.
                EncabezadoFlujo(titulo: widget.titulo),

                // Calendario: semana compacta o mes completo (ver _buildCalendario).
                _buildCalendario(theme),

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
      return const AgendaCargando(frase: 'Cargando tu agenda…');
    }
    // Jalar hacia abajo vuelve a pedir las ordenes al backend: un ticket que
    // se agrega, cambia de etapa o se borra en Odoo se refleja sin salir de
    // la pantalla. v2: también en vacío y en error.
    Future<void> recargar() => _cargar(silencioso: true);
    if (_error != null) {
      return AgendaError(titulo: 'No pudimos cargar tus $_plural', texto: _error!, alRecargar: recargar, alVolverAIntentar: _cargar);
    }
    // Agendadas para el día seleccionado.
    // REGLA 1 — la lista de trabajo solo muestra órdenes vivas. Una terminada
    // o cancelada ya no es trabajo por hacer: vive en Historial. Antes seguía
    // apareciendo en su día y ofreciendo "Iniciar ruta" sobre un servicio ya
    // cerrado (y esa acción vuelve a avisarle al cliente).
    // Opción A de Carlos (2026-10-20): lo que no tiene fecha no se muestra (el backend ya no lo manda;
    // se filtra también aquí por si el servidor es viejo). Antes salía todos los días como
    // «Pendientes de agendar» y confundía al instalador.
    final activas = _ordenes.where(_esTrabajoVivo).where((o) => _agendadaDate(o) != null).toList();

    final agendadasDia = activas.where((o) => _ocupaDia(o, _selectedDate)).toList();

    if (agendadasDia.isEmpty) {
      return AgendaVacia(
        icono: Icons.event_available_rounded,
        titulo: 'Sin $_plural este día',
        texto: 'Cuando operaciones te asigne una, aparece aquí y te llega un aviso.',
        alRecargar: recargar,
      );
    }

    return RefreshIndicator(
      onRefresh: recargar,
      color: theme.colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        // AlwaysScrollable: el gesto debe funcionar aunque haya una sola
        // orden y la lista no llegue a desbordar la pantalla.
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          EtiquetaSeccion(_tituloDia()),
          for (var i = 0; i < agendadasDia.length; i++)
            EntradaSuave(key: ValueKey('tarjeta-${agendadasDia[i].id}'), index: i, child: _buildTicketCard(agendadasDia[i], _openId == agendadasDia[i].id)),
        ],
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

  Widget _buildCalendario(ThemeData theme) {
    final mesTitulo = '${mesesLargos[_mesVisible.month - 1]} ${_mesVisible.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      // v2: grupo blanco sin borde.
      child: TarjetaFlujo(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCabeceraMes(theme, mesTitulo),
            // El cambio entre semana y mes se anima para que se lea como la
            // misma superficie creciendo, no como dos pantallas distintas.
            AnimatedSize(
              duration: AppMotion.of(context, AppDurations.spring),
              curve: AppCurves.standard,
              alignment: Alignment.topCenter,
              child: _mesExpandido ? _buildCuadriculaMes(theme) : _buildTiraSemana(theme),
            ),
          ],
        ),
      ),
    );
  }

  /// Encabezado: mes visible, navegación entre meses (solo con el mes abierto)
  /// y el botón que alterna semana/mes.
  Widget _buildCabeceraMes(ThemeData theme, String mesTitulo) {
    final color = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // Se capitaliza solo la inicial: "septiembre 2026" -> "Septiembre 2026".
              mesTitulo[0].toUpperCase() + mesTitulo.substring(1),
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (_mesExpandido) ...[
            _botonIcono(icono: Icons.chevron_left_rounded, tooltip: 'Mes anterior', color: color, onTap: () => _cambiarMes(-1)),
            _botonIcono(icono: Icons.chevron_right_rounded, tooltip: 'Mes siguiente', color: color, onTap: () => _cambiarMes(1)),
          ],
          _botonIcono(
            icono: _mesExpandido ? Icons.expand_less_rounded : Icons.calendar_month_rounded,
            tooltip: _mesExpandido ? 'Ver solo la semana' : 'Ver el mes completo',
            color: theme.colorScheme.primary,
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
  Widget _botonIcono({required IconData icono, required String tooltip, required VoidCallback onTap, Color? color}) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(width: 44, height: 44, child: Icon(icono, size: 22, color: color)),
        ),
      ),
    );
  }

  /// Vista compacta: los días desde hoy, desplazable en horizontal.
  Widget _buildTiraSemana(ThemeData theme) {
    return SizedBox(
      key: const ValueKey('tira-semana'),
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _calendarDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final day = _calendarDays[i];
          return SizedBox(width: 52, child: _celdaDia(theme, day, mostrarNombreDia: true));
        },
      ),
    );
  }

  /// Vista expandida: el mes completo en cuadrícula.
  Widget _buildCuadriculaMes(ThemeData theme) {
    final celdas = _celdasDelMes(_mesVisible);

    return Column(
      key: const ValueKey('cuadricula-mes'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final d in _diasSemana)
              Expanded(
                child: Center(child: Text(d, style: theme.textTheme.bodySmall)),
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
                      : _celdaDia(theme, celdas[fila * 7 + col]!, mostrarNombreDia: false),
                ),
            ],
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Celda de un día, compartida por la tira y la cuadrícula: mismo aspecto y
  /// mismo significado del punto (hay instalaciones agendadas ese día).
  /// v2 (2026-10-23): el día elegido va en tinta (`inverseSurface`), sin naranja.
  Widget _celdaDia(ThemeData theme, DateTime day, {required bool mostrarNombreDia}) {
    final cs = theme.colorScheme;
    final isActive = DateUtils.isSameDay(day, _selectedDate);
    final isToday = DateUtils.isSameDay(day, _today);
    final count = _countForDay(day);
    final tinta = isActive ? cs.onInverseSurface : cs.onSurface;

    return Semantics(
      button: true,
      selected: isActive,
      label:
          '${day.day} de ${mesesLargos[day.month - 1]}'
          '${count > 0 ? ', $count ${count == 1 ? 'instalación' : 'instalaciones'}' : ''}'
          '${isToday ? ', hoy' : ''}',
      child: GestureDetector(
        onTap: () => _seleccionarDia(day),
        // El hueco entre celdas tambien debe responder al toque: sin esto el
        // objetivo real es menor que la celda que se ve.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppDurations.base),
          curve: AppCurves.standard,
          height: mostrarNombreDia ? null : 48,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? cs.inverseSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isActive ? Border.all(color: cs.outlineVariant, width: 1.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mostrarNombreDia) ...[
                Text(
                  _diasSemana[day.weekday - 1],
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.1, color: isActive ? cs.onInverseSurface : cs.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
              ],
              Text('${day.day}', style: theme.textTheme.titleSmall?.copyWith(height: 1.1, color: tinta)),
              const SizedBox(height: 3),
              // Punto indicador si hay instalaciones agendadas ese día.
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: count > 0 ? (isActive ? cs.onInverseSurface : cs.primary) : Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Título del día seleccionado, en tipo oración: «Hoy · miércoles 21», «Mañana · jueves 22» o
  /// «Viernes 24 de octubre».
  String _tituloDia() {
    final dia = _diasLargos[_selectedDate.weekday - 1];
    if (DateUtils.isSameDay(_selectedDate, _today)) return 'Hoy · $dia ${_selectedDate.day}';
    if (DateUtils.isSameDay(_selectedDate, _today.add(const Duration(days: 1)))) return 'Mañana · $dia ${_selectedDate.day}';
    return '${dia[0].toUpperCase()}${dia.substring(1)} ${_selectedDate.day} de ${mesesLargos[_selectedDate.month - 1]}';
  }

  Widget _buildTicketCard(Orden orden, bool isOpen) {
    final status = _estadoDisplay(orden);
    final cancelado = status == "Cancelado";
    final destino = DestinoServicio.deDetalles(orden.toTicketMap()['details'] as Map);

    final extras = <(String, String)>[
      if (orden.plan.isNotEmpty) ('Plan', orden.plan),
      if (orden.ordenVenta.isNotEmpty) ('Orden de venta', orden.ordenVenta),
      // Hoja de trabajo de Odoo (intervenciones): lo que ya se registró en sitio.
      for (final campo in orden.hojaTrabajo.where((c) => c['valor'] != null && c['valor'] != false && '${c['valor']}'.isNotEmpty))
        ('${campo['etiqueta']}', campo['valor'] == true ? 'Sí' : '${campo['valor']}'),
      if (orden.agendado && (orden.fechaAgendada?.isNotEmpty ?? false)) ('Agendada', FechasOdoo.rango(orden.fechaAgendada, orden.fechaFin)),
      if (orden.fechaPagoConfirmado?.isNotEmpty ?? false) ('Pago confirmado', _formatFechaAgendada(orden.fechaPagoConfirmado!)),
      ('Contrato firmado', orden.contratoFirmado ? "Sí" : "Pendiente"),
    ];

    return TarjetaOrden(
      orden: orden,
      estado: status,
      abierta: isOpen,
      alTocar: () => setState(() => _openId = isOpen ? null : orden.id),
      extras: extras,
      destino: destino,
      accion: !orden.agendado
          ? const PendienteDeAgendar()
          : OhmGradientButton(
              // Si el servicio ya arrancó, la acción retoma el paso
              // pendiente; "iniciar ruta" solo aplica al primer paso
              // (y es el único que avisa al cliente).
              // Sin acción cuando no hay trabajo que hacer: cerrada,
              // cancelada o aún sin agendar.
              label: _etiquetaAccion(orden),
              icon: orden.enCurso || cancelado || !_esTrabajoVivo(orden) ? null : Icons.local_shipping_rounded,
              onPressed: (cancelado || !_esTrabajoVivo(orden) || orden.pasoActual == 'agendar')
                  ? null
                  : orden.enCurso
                  ? () => _retomarServicio(orden)
                  : () => _showConfirmationDialog(context, orden),
            ),
    );
  }

  /// Fecha UTC de Odoo ("2026-09-15 16:00:00") en hora local del dispositivo,
  /// legible como "15/09/2026 10:00". Si no parsea, devuelve el texto original.
  String _formatFechaAgendada(String raw) => FechasOdoo.fechaHora(raw);

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
      case 'prueba':
        return "Continuar · Probar energizador";
      case 'dispositivos':
        return "Continuar · Dispositivos y cierre";
      case 'cierre':
        return "Continuar · Cierre y firma";
      default:
        return "Iniciar ruta";
    }
  }

  /// Abre el flujo directamente en el paso pendiente, sin la animación de
  /// salida ni volver a marcar "en ruta" (eso ya quedó registrado en Odoo).
  Future<void> _retomarServicio(Orden orden) async {
    // Energizador opcional (2026-10-20): «vincular» y «prueba» viven dentro de «Agregar dispositivos» (paso 4).
    const paso = {'marcar_llegada': 1, 'inspeccion': 2, 'instalacion': 3, 'vinculacion': 4, 'prueba': 4, 'dispositivos': 4, 'cierre': 5};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceStepsScreen(ticket: orden.toTicketMap(), pasoInicial: paso[orden.pasoActual] ?? 1),
      ),
    );
    // Al volver, la orden pudo avanzar o completarse: se refresca.
    if (mounted) _cargar(silencioso: true);
  }

  /// «Iniciar ruta»: hoja desde abajo que avisa al cliente UNA vez (auditoría 2026-10-23: antes el
  /// botón seguía vivo mientras enviaba y un segundo toque avisaba dos veces; al volver no se refrescaba).
  Future<void> _showConfirmationDialog(BuildContext context, Orden orden) async {
    final nombre = orden.cliente.trim().split(' ').first;
    final ok = await mostrarHojaDecision(
      context,
      titulo: '¿Salir hacia el domicilio?',
      texto: nombre.isEmpty ? 'Le avisamos al cliente que vas en camino.' : 'Le avisamos a $nombre que vas en camino.',
      seguir: 'Iniciar ruta',
      salir: 'Ahora no',
      cargandoTexto: 'Avisando al cliente…',
      alSeguir: () async {
        final r = await _repo.iniciarRuta(orden.id);
        return r.isSuccess ? null : 'No pudimos avisar al cliente. Revisa tu señal y vuelve a intentar.';
      },
    );
    if (ok != true || !mounted) return;
    await Navigator.push(this.context, MaterialPageRoute(builder: (_) => TruckAnimationPage(ticket: orden.toTicketMap())));
    if (mounted) _cargar(silencioso: true);
  }
}

// =============================================================================
// Piezas de la agenda v2 (2026-10-23), compartidas con Reparaciones.
// =============================================================================

const List<String> mesesLargos = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// «Creada el 14 de octubre, 9:00» (hora del teléfono). Vacío si la fecha no parsea.
String creadaEl(String? raw) {
  final f = FechasOdoo.aLocal(raw);
  if (f == null) return '';
  return 'Creada el ${f.day} de ${mesesLargos[f.month - 1]}, ${f.hour}:${f.minute.toString().padLeft(2, '0')}';
}

/// Tarjeta de una instalación o reparación en la agenda (v2): título y estado (punto + palabra),
/// «i76 · Creada el …», los datos en columnas etiqueta/valor, «Cómo llegar» como píldora y la acción
/// principal. Al tocarla muestra los datos de más ([extras]).
class TarjetaOrden extends StatelessWidget {
  const TarjetaOrden({
    super.key,
    required this.orden,
    required this.estado,
    required this.abierta,
    required this.alTocar,
    required this.destino,
    this.accion,
    this.extras = const [],
  });

  final Orden orden;

  /// «Por hacer», «En curso», «Completo», «Cancelado».
  final String estado;
  final bool abierta;
  final VoidCallback alTocar;
  final DestinoServicio destino;
  final Widget? accion;
  final List<(String, String)> extras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final colorEstado = switch (estado) {
      'Por hacer' => ohm.info,
      'En curso' => ohm.warning,
      'Completo' => ohm.success,
      'Cancelado' => cs.error,
      _ => cs.onSurfaceVariant,
    };
    final creada = creadaEl(orden.fechaCreacion);
    final linea = [if (orden.numero.isNotEmpty) orden.numero, if (creada.isNotEmpty) creada].join(' · ');
    final direccion = [orden.direccion, orden.ciudad, orden.cp].where((s) => s.trim().isNotEmpty).join(', ');
    final datos = <(String, String)>[
      ('Cliente', orden.cliente),
      if (direccion.isNotEmpty) ('Dirección', direccion),
      if (orden.telefono.isNotEmpty) ('Teléfono', orden.telefono),
      if (orden.metraje.isNotEmpty) ('Metraje', orden.metraje),
      // Lo que el instalador debe saber ANTES de llegar: malla, vegetación, mascotas, acceso...
      if (orden.condicionesTerreno.isNotEmpty) ('Terreno', orden.condicionesTerreno.join(', ')),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(orden.titulo, style: theme.textTheme.titleLarge)),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: EstadoPunto(estado, color: colorEstado),
                    ),
                  ],
                ),
                if (linea.isNotEmpty || orden.urgente) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (linea.isNotEmpty) Text(linea, style: theme.textTheme.bodySmall),
                      if (orden.urgente) const InsigniaUrgente(),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                for (final d in datos) DatoColumna(etiqueta: d.$1, valor: d.$2),
                AnimatedSize(
                  duration: AppMotion.of(context, AppDurations.spring),
                  curve: AppCurves.standard,
                  alignment: Alignment.topCenter,
                  child: abierta
                      ? Column(
                          children: [for (final d in extras) DatoColumna(etiqueta: d.$1, valor: d.$2)],
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (extras.isNotEmpty)
                  Semantics(
                    button: true,
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Text(abierta ? 'Ver menos' : 'Ver más datos', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          Icon(abierta ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                if (!destino.vacio || accion != null) const SizedBox(height: 4),
                if (!destino.vacio)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BotonFila(etiqueta: 'Cómo llegar', icono: Icons.directions_rounded, onPressed: () => mostrarComoLlegar(context, destino)),
                  ),
                if (accion != null) ...[const SizedBox(height: 8), accion!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renglón «Dirección   Av. Reforma 222…»: etiqueta gris en su columna y el valor al lado (v2).
class DatoColumna extends StatelessWidget {
  const DatoColumna({super.key, required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(etiqueta, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(valor, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Insignia «Urgente»: texto rojo sobre rojo claro (v2).
class InsigniaUrgente extends StatelessWidget {
  const InsigniaUrgente({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: cs.error),
          const SizedBox(width: 4),
          Text(
            'Urgente',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Aviso (no tocable) cuando la orden aún no está agendada: el instalador no puede iniciar la ruta
/// hasta que operaciones confirme día y hora.
class PendienteDeAgendar extends StatelessWidget {
  const PendienteDeAgendar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule_rounded, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Pendiente de agendar. Operaciones confirmará el día y la hora con el cliente.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Cargando con frase: nunca un círculo mudo (v2).
class AgendaCargando extends StatelessWidget {
  const AgendaCargando({super.key, required this.frase});

  final String frase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Text(frase, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Lista desplazable que siempre acepta «jalar para recargar», aunque su contenido no la llene.
class _Recargable extends StatelessWidget {
  const _Recargable({required this.alRecargar, required this.child, this.alineacion = Alignment.center});

  final Future<void> Function() alRecargar;
  final Widget child;
  final AlignmentGeometry alineacion;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: alRecargar,
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (c.maxHeight - 108).clamp(0, double.infinity)),
            child: Align(alignment: alineacion, child: child),
          ),
        ),
      ),
    );
  }
}

/// Vacío: qué es, por qué está vacío y qué sigue. Se jala para recargar.
class AgendaVacia extends StatelessWidget {
  const AgendaVacia({super.key, required this.icono, required this.titulo, required this.texto, required this.alRecargar});

  final IconData icono;
  final String titulo;
  final String texto;
  final Future<void> Function() alRecargar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Recargable(
      alRecargar: alRecargar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(icono, size: 32, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error al cargar: qué pasó, el mensaje humano del repositorio y «Volver a intentar».
class AgendaError extends StatelessWidget {
  const AgendaError({super.key, required this.titulo, required this.texto, required this.alRecargar, required this.alVolverAIntentar});

  final String titulo;
  final String texto;
  final Future<void> Function() alRecargar;
  final VoidCallback alVolverAIntentar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Recargable(
      alRecargar: alRecargar,
      alineacion: Alignment.topCenter,
      child: MensajeFlujo(
        icono: Icons.error_outline_rounded,
        color: cs.error,
        titulo: titulo,
        texto: texto,
        accion: BotonFila(etiqueta: 'Volver a intentar', icono: Icons.refresh_rounded, onPressed: alVolverAIntentar),
      ),
    );
  }
}
