import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/fechas_odoo.dart';
import '../features/dinero/data/dinero_repository.dart';
import '../features/dinero/domain/dinero.dart';
import '../widgets/ayuda.dart';
import '../widgets/menu_item_tile.dart';

/// Mis pagos: lo que OhmSafe le paga al instalador por cada intervención
/// completada. Cada renglón es una factura de proveedor en Odoo; nace en
/// borrador al cerrar («En revisión»), operaciones la valida («Por pagar») y
/// contabilidad la paga («Pagado»).
/// v2 (2026-10-23): encabezado de todos, totales en grupos blancos, pagos en lista agrupada con su
/// estado como punto + palabra, y «instalación» en vez de «intervención» en lo que se ve.
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  ResumenPagos? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await sl.get<DineroRepository>().pagos();
    if (!mounted) return;
    r.fold(
      (res) => setState(() {
        _resumen = res;
        _cargando = false;
        _error = null;
      }),
      (f) => setState(() {
        _cargando = false;
        _error = f.message;
      }),
    );
  }

  void _volverAIntentar() {
    setState(() => _cargando = true);
    _cargar();
  }

  Color _color(String estado, BuildContext context) => switch (estado) {
    'pagado' => context.ohm.success,
    'por_pagar' => context.ohm.warning,
    'cancelado' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.outline,
  };

  IconData _icono(String estado) => switch (estado) {
    'pagado' => Icons.check_circle_rounded,
    'por_pagar' => Icons.schedule_rounded,
    'cancelado' => Icons.cancel_rounded,
    _ => Icons.hourglass_top_rounded,
  };

  /// El concepto llega de Odoo como «Intervención i12 · S00157»; en pantalla se dice «Instalación».
  static String _concepto(String c) => c.replaceFirst(RegExp(r'^Intervención\b'), 'Instalación');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = _resumen;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoFlujo(titulo: 'Mis pagos'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargar,
                color: cs.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    if (_cargando)
                      const _Cargando('Cargando tus pagos…')
                    else if (_error != null)
                      MensajeFlujo(
                        icono: Icons.error_outline_rounded,
                        color: cs.error,
                        titulo: 'No se pudieron cargar tus pagos',
                        texto: _error,
                        accion: TextButton(onPressed: _volverAIntentar, child: const Text('Volver a intentar')),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _Total(etiqueta: 'Pagado', valor: dinero(r!.pagado), color: context.ohm.success),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Total(etiqueta: 'Por pagar', valor: dinero(r.porPagar), color: context.ohm.warning),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Total(etiqueta: 'En revisión', valor: dinero(r.pendienteValidacion), color: cs.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (r.pagos.isEmpty)
                        const _Vacio(
                          icono: Icons.payments_rounded,
                          titulo: 'Aún no hay pagos',
                          texto:
                              'Cada instalación que cierres aparece aquí con su pago: primero «En revisión», luego «Por pagar» y al final «Pagado». Para empezar, termina tu primera instalación.',
                        )
                      else ...[
                        const EtiquetaSeccion('Pagos'),
                        GrupoFilas(
                          pie:
                              'Los pagos «En revisión» se confirman cuando operaciones valida la instalación. Si un importe no coincide, repórtalo como incidencia.',
                          children: [
                            for (final p in r.pagos)
                              FilaFlujo(
                                leading: MosaicoIcono(icono: _icono(p.estado), color: _color(p.estado, context)),
                                titulo: _concepto(p.concepto),
                                subtitulo: [if (p.referencia != 'Borrador') p.referencia, FechasOdoo.fecha(p.fecha)].join(' · '),
                                // Ancho acotado: EstadoPunto lleva un Flexible y en el trailing no hay límite.
                                trailing: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 140),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(dinero(p.monto, p.moneda), style: theme.textTheme.titleSmall),
                                      const SizedBox(height: 2),
                                      EstadoPunto(estadosPago[p.estado] ?? p.estado, color: _color(p.estado, context)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color color;
  const _Total({required this.etiqueta, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TarjetaFlujo(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(etiqueta, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: theme.textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

/// «Cargando…» con frase, nunca un círculo mudo (v2).
class _Cargando extends StatelessWidget {
  const _Cargando(this.frase);
  final String frase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(frase, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vacío v2: qué es, por qué está vacío y cómo empezar.
class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.titulo, required this.texto});
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
            child: Icon(icono, size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
