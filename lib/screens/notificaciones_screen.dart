import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../controllers/app_state_provider.dart';
import '../features/notificaciones/data/notificaciones_repository.dart';
import '../features/notificaciones/domain/notificacion.dart';
import '../core/utils/fechas_odoo.dart';
import '../widgets/ayuda.dart';
import '../widgets/menu_item_tile.dart';

/// Centro de notificaciones del instalador: asignaciones, reagendas,
/// cancelaciones y mensajes de operaciones.
/// v2 (2026-10-23; lienzo «V3 · Notificaciones v2»): agrupadas por día, punto naranja en las que
/// llegaron sin leer, ícono en mosaico por tipo y «Todas / Sin leer (N)».
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final NotificacionesRepository _repo;
  List<Notificacion> _items = [];
  bool _loading = true;
  String? _error;

  /// Las que venían sin leer al abrir. Abrir el centro las marca leídas en el servidor, pero
  /// mientras estás aquí conservan su punto naranja para que sepas cuáles son nuevas.
  Set<String> _nuevas = {};
  bool _soloSinLeer = false;

  @override
  void initState() {
    super.initState();
    _repo = sl.get<NotificacionesRepository>();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _loading = true);
    final res = await _repo.listar();
    if (!mounted) return;
    res.fold(
      (data) {
        setState(() {
          _items = data.items;
          _nuevas = {
            ..._nuevas,
            for (final n in data.items)
              if (!n.leida) n.id,
          };
          _error = null;
          _loading = false;
        });
        // Abrir el centro es el gesto de "ya lo vi": se marca leído y el
        // badge de la campana se limpia en todas las pantallas.
        if (data.noLeidas > 0) _marcarLeidas();
      },
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
    );
  }

  Future<void> _marcarLeidas() async {
    final res = await _repo.marcarLeidas();
    if (!mounted) return;
    res.fold((_) {
      AppStateProvider.of(context).setNotificacionesNoLeidas(0);
      // La lista se repinta sin el resalte de "nuevo".
      setState(() {
        _items = _items
            .map((n) => Notificacion(id: n.id, tipo: n.tipo, titulo: n.titulo, cuerpo: n.cuerpo, fecha: n.fecha, leida: true, ordenId: n.ordenId))
            .toList();
      });
    }, (_) {});
  }

  bool _esNueva(Notificacion n) => !n.leida || _nuevas.contains(n.id);

  /// Grupo por día en hora del teléfono (Odoo entrega UTC sin zona).
  static String _grupo(DateTime? dt, DateTime ahora) {
    if (dt == null) return 'Antes';
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(dt.year, dt.month, dt.day);
    final dias = hoy.difference(dia).inDays;
    if (dias <= 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    if (dias < 7) return 'Esta semana';
    return 'Antes';
  }

  static const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  /// Hora para Hoy y Ayer, día de la semana para Esta semana y fecha para lo de antes.
  static String _cuando(DateTime? dt, String grupo) {
    if (dt == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return switch (grupo) {
      'Hoy' || 'Ayer' => '${dt.hour}:${dos(dt.minute)}',
      'Esta semana' => _diasSemana[dt.weekday - 1],
      _ => '${dos(dt.day)}/${dos(dt.month)}/${dt.year}',
    };
  }

  ({IconData icono, Color color}) _estilo(String tipo, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (tipo) {
      case 'asignacion':
        return (icono: Icons.event_available_rounded, color: cs.primary);
      case 'agenda':
        return (icono: Icons.event_repeat_rounded, color: context.ohm.info);
      case 'cancelacion':
        return (icono: Icons.event_busy_rounded, color: cs.error);
      default:
        return (icono: Icons.chat_bubble_outline_rounded, color: cs.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ya estás en Notificaciones: sin campana.
            const EncabezadoFlujo(titulo: 'Notificaciones', campana: false),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _cargar(silencioso: true),
                color: cs.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: _loading
                      ? [_cargando(theme)]
                      : _error != null
                      ? [_estadoError(theme)]
                      : _items.isEmpty
                      ? [_estadoVacio(theme)]
                      : _lista(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lista(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ahora = DateTime.now();
    final sinLeer = _items.where(_esNueva).length;
    final visibles = _soloSinLeer ? _items.where(_esNueva).toList() : _items;
    // Mismo orden que entrega el servidor; sólo se cortan en grupos por día.
    final grupos = <String, List<Notificacion>>{};
    for (final n in visibles) {
      grupos.putIfAbsent(_grupo(FechasOdoo.aLocal(n.fecha), ahora), () => []).add(n);
    }
    return [
      if (sinLeer > 0) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          // Control segmentado al estilo iPhone: gris con la opción elegida en blanco.
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cs.surface : cs.surfaceContainerHighest),
              foregroundColor: WidgetStatePropertyAll(cs.onSurface),
              side: WidgetStatePropertyAll(BorderSide(color: cs.surfaceContainerHighest, width: 2)),
              textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
            segments: [
              const ButtonSegment(value: false, label: Text('Todas')),
              ButtonSegment(value: true, label: Text('Sin leer ($sinLeer)')),
            ],
            selected: {_soloSinLeer},
            onSelectionChanged: (s) => setState(() => _soloSinLeer = s.first),
          ),
        ),
      ],
      for (final g in grupos.entries) ...[
        EtiquetaSeccion(g.key),
        GrupoFilas(children: [for (final n in g.value) _fila(context, n, g.key)]),
      ],
    ];
  }

  Widget _fila(BuildContext context, Notificacion n, String grupo) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = _estilo(n.tipo, context);
    final nueva = _esNueva(n);
    final cuando = _cuando(FechasOdoo.aLocal(n.fecha), grupo);
    return Semantics(
      container: true,
      label: nueva ? 'Sin leer' : null,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MosaicoIcono(icono: e.icono, color: e.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(n.titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: nueva ? FontWeight.w600 : FontWeight.w500)),
                          ),
                          if (cuando.isNotEmpty) ...[const SizedBox(width: 8), Text(cuando, style: theme.textTheme.bodySmall)],
                        ],
                      ),
                      if (n.cuerpo.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(n.cuerpo, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                      if (n.ordenId != null) ...[const SizedBox(height: 4), Text('Instalación ${n.ordenId}', style: theme.textTheme.bodySmall)],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Punto naranja a la izquierda del ícono: llegó sin leer.
          if (nueva)
            Positioned(
              left: 5,
              top: 25,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cargando(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 32),
    child: Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text('Cargando tus notificaciones…', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    ),
  );

  Widget _estadoVacio(ThemeData theme) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
            child: Icon(Icons.notifications_none_rounded, size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('Sin notificaciones', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Aquí te avisamos cuando OhmSafe te asigne, cambie o cancele una instalación. Todavía no tienes avisos; no tienes que hacer nada, llegan solos. Jala hacia abajo para revisar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _estadoError(ThemeData theme) => MensajeFlujo(
    icono: Icons.error_outline_rounded,
    color: theme.colorScheme.error,
    titulo: 'No se pudieron cargar tus notificaciones',
    texto: _error,
    accion: TextButton(onPressed: _cargar, child: const Text('Volver a intentar')),
  );
}
