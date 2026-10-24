import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ayuda.dart';
import '../core/theme/app_theme_extension.dart';

/// Historial de instalaciones completadas y canceladas (instalaciones y reparaciones).
/// Permite buscar por texto y filtrar por rango: última semana, último
/// mes o todo el histórico.
/// v2 (2026-10-23): raíz de pestaña con el encabezado de todos, filtro segmentado, lista agrupada con
/// el número («i67») en cada fila, y carga / error / vacío con frase.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

enum _Rango { semana, mes, todo }

class _HistorialScreenState extends State<HistorialScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _Rango _rango = _Rango.todo;

  /// Mientras llega la primera respuesta del backend (la frase «Cargando tu historial…»).
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    // El historial vive en el backend (completadas y canceladas en sitio).
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    await AppStateProvider.of(context).cargarHistorial();
    if (mounted) setState(() => _cargando = false);
  }

  bool _esCancelada(Map<String, dynamic> t) => (t['status']?.toString().toLowerCase() ?? '') == 'cancelada';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _esReparacion(Map<String, dynamic> t) {
    final type = (t['type'] as String?)?.toLowerCase() ?? '';
    if (type.contains('reparacion') || type.contains('reparación')) return true;
    final title = (t['title'] as String?)?.toLowerCase() ?? '';
    return title.contains('reparacion') || title.contains('reparación');
  }

  bool _dentroDeRango(DateTime? fecha) {
    if (_rango == _Rango.todo) return true;
    if (fecha == null) return false;
    final now = DateTime.now();
    final dias = _rango == _Rango.semana ? 7 : 30;
    return fecha.isAfter(now.subtract(Duration(days: dias)));
  }

  bool _coincideBusqueda(Map<String, dynamic> t) {
    if (_query.trim().isEmpty) return true;
    final q = _query.toLowerCase();
    final details = (t['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final campos = [
      t['title']?.toString() ?? '',
      t['user']?.toString() ?? '',
      details['direccion']?.toString() ?? '',
      details['ciudad']?.toString() ?? '',
      details['cp']?.toString() ?? '',
      _numero(t), // «i67»
    ];
    return campos.any((c) => c.toLowerCase().contains(q));
  }

  String _fecha(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return "$dd/$mm/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = AppStateProvider.of(context);

    final tickets = state.history.where((t) => _dentroDeRango(t['completedAt'] as DateTime?)).where(_coincideBusqueda).toList();
    // Sin respuesta del backend: si no hay nada que mostrar, se dice qué pasó (antes: «Aún no hay historial»).
    final fallo = !_cargando && !state.historialCargado;

    final Widget contenido;
    if (_cargando && state.history.isEmpty) {
      contenido = _cargandoFila(theme);
    } else if (fallo && state.history.isEmpty) {
      contenido = MensajeFlujo(
        icono: Icons.error_outline_rounded,
        color: cs.error,
        titulo: 'No se pudo cargar tu historial',
        texto: 'Revisa tu señal y vuelve a intentar.',
        accion: TextButton(onPressed: _cargar, child: const Text('Volver a intentar')),
      );
    } else if (tickets.isEmpty) {
      contenido = _emptyState(theme);
    } else {
      contenido = GrupoFilas(children: [for (final t in tickets) _ticketCard(theme, t)]);
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
                const EncabezadoFlujo(titulo: 'Historial', volver: false),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargar,
                    color: cs.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      children: [
                        TextField(
                          controller: _searchController,
                          style: theme.textTheme.bodyLarge,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: "Busca por cliente, dirección o número",
                            prefixIcon: const Icon(Icons.search_rounded, size: 22),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Borrar búsqueda',
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Control segmentado al estilo iPhone: gris con el periodo elegido en blanco.
                        SegmentedButton<_Rango>(
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                            backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cs.surface : cs.surfaceContainerHighest),
                            foregroundColor: WidgetStatePropertyAll(cs.onSurface),
                            side: WidgetStatePropertyAll(BorderSide(color: cs.surfaceContainerHighest, width: 2)),
                            textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                          segments: const [
                            ButtonSegment(value: _Rango.semana, label: Text('Última semana')),
                            ButtonSegment(value: _Rango.mes, label: Text('Último mes')),
                            ButtonSegment(value: _Rango.todo, label: Text('Todo')),
                          ],
                          selected: {_rango},
                          onSelectionChanged: (s) => setState(() => _rango = s.first),
                        ),
                        const SizedBox(height: 20),
                        if (tickets.isNotEmpty) EtiquetaSeccion("${tickets.length} ${tickets.length == 1 ? 'instalación' : 'instalaciones'}"),
                        contenido,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const AppBottomNav(currentTab: "Historial"),
        ],
      ),
    );
  }

  Widget _cargandoFila(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text('Cargando tu historial…', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    ),
  );

  /// Número de intervención («i67»): el mismo de la lista de instalaciones y de Odoo (Carlos, 2026-10-20).
  static String _numero(Map<String, dynamic> t) {
    final id = t['id']?.toString() ?? '';
    return RegExp(r'^i\d+$').hasMatch(id) ? id : '';
  }

  Widget _ticketCard(ThemeData theme, Map<String, dynamic> t) {
    final cs = theme.colorScheme;
    final numero = _numero(t);
    final ohm = context.ohm;
    final esRep = _esReparacion(t);
    final cancelada = _esCancelada(t);
    final details = (t['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final fecha = _fecha(t['completedAt'] as DateTime?);
    final motivo = t['motivo']?.toString() ?? '';
    final apoyo = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    final estadoColor = cancelada ? cs.error : (esRep ? ohm.info : ohm.success);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(t['title']?.toString() ?? 'Instalación', style: theme.textTheme.titleMedium)),
              if (numero.isNotEmpty) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: 'Instalación $numero',
                  excludeSemantics: true,
                  child: Text(numero, style: apoyo),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          EstadoPunto(cancelada ? "Cancelada" : (esRep ? "Reparación" : "Instalación"), color: estadoColor),
          const SizedBox(height: 6),
          if (cancelada) ...[
            _infoRow(theme, Icons.cancel_rounded, "Cancelada el $fecha"),
            if (motivo.isNotEmpty) ...[const SizedBox(height: 4), _infoRow(theme, Icons.notes_rounded, "Motivo: $motivo")],
          ] else
            _infoRow(theme, Icons.check_circle_outline_rounded, "Completada el $fecha"),
          if ((t['user']?.toString() ?? '').isNotEmpty) ...[const SizedBox(height: 4), _infoRow(theme, Icons.person_outline_rounded, t['user'].toString())],
          if ((details['direccion']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            _infoRow(
              theme,
              Icons.location_on_rounded,
              "${details['direccion']}${(details['ciudad']?.toString() ?? '').isNotEmpty ? ', ${details['ciudad']}' : ''}",
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  /// Vacío v2: qué es, por qué está vacío y cómo seguir.
  Widget _emptyState(ThemeData theme) {
    final cs = theme.colorScheme;
    final hayHistorial = AppStateProvider.of(context).history.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
            child: Icon(hayHistorial ? Icons.search_off_rounded : Icons.history_rounded, size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(hayHistorial ? "Sin resultados" : "Aún no hay historial", textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            hayHistorial
                ? "Ninguna instalación coincide con tu búsqueda en este periodo. Cambia lo que escribiste o elige «Todo»."
                : "Aquí aparecen las instalaciones que terminas o cancelas. Cuando cierres la primera, la verás aquí.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
