import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/app_bottom_nav.dart';

/// Historial de tickets completados (instalaciones y reparaciones).
/// Permite buscar por texto y filtrar por rango: última semana, último
/// mes o todo el histórico.
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

  static const orange = Color(0xFFFF5A00);

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
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    final tickets = state.history
        .where((t) => _dentroDeRango(t['completedAt'] as DateTime?))
        .where(_coincideBusqueda)
        .toList();

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
                            const Text("SAFE", style: TextStyle(fontWeight: FontWeight.w900, color: orange)),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.notifications_none_rounded, color: theme.iconTheme.color?.withOpacity(0.7)),
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
                            "Historial",
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

                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "Buscar por cliente, dirección o ticket...",
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),

                // Filter chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      _filtroChip("Última semana", _Rango.semana),
                      const SizedBox(width: 8),
                      _filtroChip("Último mes", _Rango.mes),
                      const SizedBox(width: 8),
                      _filtroChip("Todo", _Rango.todo),
                    ],
                  ),
                ),

                // Count
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    "${tickets.length} ${tickets.length == 1 ? 'ticket' : 'tickets'}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: tickets.isEmpty
                      ? _emptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                          physics: const BouncingScrollPhysics(),
                          itemCount: tickets.length,
                          itemBuilder: (context, i) => _ticketCard(theme, isDark, tickets[i]),
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

  Widget _filtroChip(String label, _Rango value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _rango == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rango = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? orange : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? orange : theme.dividerColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ticketCard(ThemeData theme, bool isDark, Map<String, dynamic> t) {
    final esRep = _esReparacion(t);
    final details = (t['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final fecha = _fecha(t['completedAt'] as DateTime?);

    final badgeColor = esRep ? const Color(0xFF4F46E5) : orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t['title']?.toString() ?? 'Ticket',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  esRep ? "Reparación" : "Instalación",
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(theme, Icons.check_circle_outline_rounded, const Color(0xFF15803D), "Completado el $fecha"),
          if ((t['user']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(theme, Icons.person_outline_rounded, theme.textTheme.bodyMedium?.color?.withOpacity(0.6), t['user'].toString()),
          ],
          if ((details['direccion']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(theme, Icons.location_on_outlined, theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                "${details['direccion']}${details['ciudad'] != null ? ', ${details['ciudad']}' : ''}"),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, Color? color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(ThemeData theme) {
    final hayHistorial = AppStateProvider.of(context).history.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 48, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            hayHistorial ? "Sin resultados" : "Aún no hay historial",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              hayHistorial
                  ? "Ajusta la búsqueda o el filtro de fechas."
                  : "Los tickets que completes aparecerán aquí.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
