import '../core/utils/como_llegar.dart';
import 'package:flutter/material.dart';
import 'instalaciones_screen.dart';
import 'service_steps_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ayuda.dart';
import '../widgets/hoja_decision.dart';
import '../widgets/movimiento.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
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

  Future<void> _cargar({bool silencioso = false}) async {
    setState(() {
      if (!silencioso) _loading = true;
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
                const EncabezadoFlujo(titulo: 'Reparaciones'),

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
      return const AgendaCargando(frase: 'Cargando tus reparaciones…');
    }
    // Jalar para recargar también en vacío y en error (v2).
    Future<void> recargar() => _cargar(silencioso: true);
    if (_error != null) {
      return AgendaError(titulo: 'No pudimos cargar tus reparaciones', texto: _error!, alRecargar: recargar, alVolverAIntentar: _cargar);
    }
    if (_ordenes.isEmpty) {
      return AgendaVacia(
        icono: Icons.build_circle_outlined,
        titulo: 'Sin reparaciones',
        texto: 'Cuando operaciones te asigne una, aparece aquí y te llega un aviso.',
        alRecargar: recargar,
      );
    }
    return RefreshIndicator(
      onRefresh: recargar,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _ordenes.length,
        itemBuilder: (context, index) =>
            EntradaSuave(key: ValueKey('tarjeta-${_ordenes[index].id}'), index: index, child: _buildTicketCard(_ordenes[index], index, index == _openIndex)),
      ),
    );
  }

  Widget _buildTicketCard(Orden orden, int index, bool isOpen) {
    return TarjetaOrden(
      orden: orden,
      estado: _estadoLabel(orden.estado),
      abierta: isOpen,
      alTocar: () => setState(() => _openIndex = isOpen ? null : index),
      destino: DestinoServicio.deDetalles(orden.toTicketMap()['details'] as Map),
      accion: OhmGradientButton(label: 'Iniciar ruta', icon: Icons.local_shipping_rounded, onPressed: () => _showConfirmationDialog(context, orden)),
    );
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
