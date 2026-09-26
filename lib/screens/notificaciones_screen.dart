import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../controllers/app_state_provider.dart';
import '../features/notificaciones/data/notificaciones_repository.dart';
import '../features/notificaciones/domain/notificacion.dart';
import '../core/utils/fechas_odoo.dart';

/// Centro de notificaciones del instalador: asignaciones, reagendas,
/// cancelaciones y mensajes de operaciones.
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
            .map((n) => Notificacion(
                  id: n.id,
                  tipo: n.tipo,
                  titulo: n.titulo,
                  cuerpo: n.cuerpo,
                  fecha: n.fecha,
                  leida: true,
                  ordenId: n.ordenId,
                ))
            .toList();
      });
    }, (_) {});
  }

  /// Odoo entrega la fecha en UTC sin zona; se pasa a hora del dispositivo y
  /// se muestra en relativo, que es lo útil en una bandeja.
  String _relativo(String fecha) {
    final dt = FechasOdoo.aLocal(fecha);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    if (d.inDays < 7) return 'hace ${d.inDays} días';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  ({IconData icono, Color color}) _estilo(String tipo, ColorScheme cs) {
    switch (tipo) {
      case 'asignacion':
        return (icono: Icons.assignment_turned_in_rounded, color: cs.primary);
      case 'agenda':
        return (icono: Icons.event_repeat_rounded, color: Colors.blueAccent);
      case 'cancelacion':
        return (icono: Icons.cancel_rounded, color: Colors.redAccent);
      default:
        return (icono: Icons.chat_bubble_outline_rounded, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        color: cs.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _estadoError(theme)
                : _items.isEmpty
                    ? _estadoVacio(theme)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _tarjeta(theme, cs, _items[i]),
                      ),
      ),
    );
  }

  Widget _tarjeta(ThemeData theme, ColorScheme cs, Notificacion n) {
    final e = _estilo(n.tipo, cs);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.leida ? theme.dividerColor : cs.primary.withValues(alpha: 0.5),
          width: n.leida ? 1 : 1.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: e.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(e.icono, size: 20, color: e.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.titulo,
                        style: TextStyle(
                          fontWeight: n.leida ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _relativo(n.fecha),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (n.cuerpo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.cuerpo,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (n.ordenId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Orden #${n.ordenId}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(ThemeData theme) => ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.notifications_off_outlined,
              size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Center(
            child: Text('Sin notificaciones',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Aquí verás tus asignaciones y avisos',
                style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
          ),
        ],
      );

  Widget _estadoError(ThemeData theme) => ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Center(
            child: Text('No se pudieron cargar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
}
