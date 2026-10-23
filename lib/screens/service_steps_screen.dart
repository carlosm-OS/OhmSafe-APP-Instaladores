import '../core/utils/como_llegar.dart';
import '../core/navigation/volver_a_listado.dart';
import 'dart:async';
import '../core/wifi/wifi_casa_local.dart';
import 'wifi_casa_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_motion.dart';
import '../widgets/ayuda.dart';
import '../widgets/movimiento.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ohm_gradient_button.dart';
import 'route_details_screen.dart';
import 'perimeter_inspection_screen.dart';
import 'fence_installation_screen.dart';
import 'reparacion_screen.dart';
import 'agregar_dispositivos_screen.dart';
import 'instalaciones_screen.dart';
import 'reparaciones_screen.dart';
import 'cierre_instalacion_screen.dart';
import '../controllers/app_state_provider.dart';

// --- TRUCK ANIMATION PAGE ---
class TruckAnimationPage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TruckAnimationPage({super.key, required this.ticket});

  @override
  State<TruckAnimationPage> createState() => _TruckAnimationPageState();
}

class _TruckAnimationPageState extends State<TruckAnimationPage> with TickerProviderStateMixin {
  // Ruedas, rebote y línea del camino; [_scaleController] es la salida (se encoge).
  late final AnimationController _rotationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final AnimationController _roadController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  Timer? _espera;
  bool _arrancada = false;
  bool _salio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancada) return;
    _arrancada = true;
    // v2 (2026-10-23): con «Reducir movimiento» va directo a los pasos.
    if (AppMotion.reducido(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _seguir());
      return;
    }
    _rotationController.repeat();
    _bounceController.repeat(reverse: true);
    _roadController.repeat();
    // Dura como máximo 1.2 s (900 ms de camino + 300 ms de salida) y un toque la salta (antes, 3 s fijos).
    _espera = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _scaleController.forward().then((_) => _seguir());
    });
  }

  /// Pasa a los pasos una sola vez (por tiempo o por el toque).
  void _seguir() {
    if (_salio || !mounted) return;
    _salio = true;
    _espera?.cancel();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: AppMotion.of(context, AppDurations.base),
        pageBuilder: (context, animation, secondaryAnimation) => ServiceStepsScreen(ticket: widget.ticket),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: AppCurves.standard),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _espera?.cancel();
    _rotationController.dispose();
    _bounceController.dispose();
    _scaleController.dispose();
    _roadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Iniciando la ruta. Toca para continuar.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _seguir,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              // Salida: se encoge de 1 a 0.
              final scaleValue = 1.0 - AppCurves.exit.transform(_scaleController.value);
              return Transform.scale(scale: scaleValue, child: child);
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camión animado
                  SizedBox(
                    width: 240,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Línea del camino en movimiento
                        Positioned(
                          bottom: 14,
                          left: 20,
                          right: 20,
                          child: AnimatedBuilder(
                            animation: _roadController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: RoadPainter(progress: _roadController.value, color: cs.outlineVariant),
                                size: const Size(200, 2),
                              );
                            },
                          ),
                        ),
                        // Caja y cabina con un rebote leve
                        AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            final bounceY = _bounceController.value * -3.0; // 3px bounce
                            return Transform.translate(offset: Offset(0, bounceY), child: child);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Caja naranja con la marca
                                  Container(
                                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
                                    width: 85,
                                    height: 50,
                                    child: Center(
                                      child: Text(
                                        "OHMSAFE",
                                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  // Cabina
                                  Container(
                                    width: 30,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: cs.onSurface,
                                      borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(4)),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 14,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest, // vidrio
                                              borderRadius: const BorderRadius.only(topRight: Radius.circular(4)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Ruedas girando
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    RotationTransition(turns: _rotationController, child: const WheelWidget()),
                                    RotationTransition(turns: _rotationController, child: const WheelWidget()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Iniciando la ruta…", style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text("Toca para continuar", style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- ROAD PAINTER ---
class RoadPainter extends CustomPainter {
  final double progress;
  final Color color;
  RoadPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    const dashWidth = 14.0;
    const dashSpace = 8.0;
    final totalSpacing = dashWidth + dashSpace;

    final offsetX = -progress * totalSpacing;

    double currentX = offsetX;
    while (currentX < size.width + totalSpacing) {
      if (currentX + dashWidth > 0) {
        canvas.drawLine(Offset(currentX, y), Offset(currentX + dashWidth, y), paint);
      }
      currentX += totalSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) => oldDelegate.progress != progress;
}

// --- WHEEL WIDGET ---
class WheelWidget extends StatelessWidget {
  const WheelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: cs.onSurface, shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cs.outlineVariant, shape: BoxShape.circle),
          child: CustomPaint(painter: WheelSpokesPainter(color: cs.surface)),
        ),
      ),
    );
  }
}

class WheelSpokesPainter extends CustomPainter {
  WheelSpokesPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(center, Offset(size.width / 2, 0), paint);
    canvas.drawLine(center, Offset(0, size.height), paint);
    canvas.drawLine(center, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant WheelSpokesPainter oldDelegate) => oldDelegate.color != color;
}

// --- SERVICE STEPS SCREEN ---
class ServiceStepsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  /// Paso con el que se abre la pantalla (1 = ruta … 5 = cierre). Los pasos
  /// anteriores se marcan completados: es lo que permite retomar un servicio
  /// que ya tiene llegada, inspección o equipo guardados en Odoo.
  final int pasoInicial;

  const ServiceStepsScreen({super.key, required this.ticket, this.pasoInicial = 1});

  @override
  State<ServiceStepsScreen> createState() => _ServiceStepsScreenState();
}

class _ServiceStepsScreenState extends State<ServiceStepsScreen> {
  bool _showToast = true;
  bool _step1Completed = false;
  bool _step2Completed = false;
  bool _step3Completed = false;

  /// «Agregar dispositivos» (build 39): cableado con prueba en vivo; opcional, antes del cierre.
  /// Desde la build 54 (energizador opcional, Carlos 2026-10-20) también vincular el energizador y
  /// su prueba viven ahí dentro: una casa puede no llevar energizador.
  bool _dispositivosHechos = false;

  /// «Agregar dispositivos» se abre sólo al tocar el paso y al terminar regresa aquí. Queda
  /// abierto hasta el cierre: si el cliente compra algo más en sitio se vuelve a entrar (Carlos, 2026-10-14).
  Future<void> _abrirDispositivos(BuildContext context) async {
    final ticket = {
      ...widget.ticket,
      'wifiCasa': {'estado': _wifiEstado, 'red': _wifiRed},
    };
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarDispositivosScreen(ticket: ticket)));
    if (!mounted) return;
    // Desde «Agregar dispositivos» también se puede capturar o cambiar la Wi‑Fi de la casa.
    final w = await WifiCasaLocal.instancia.leer((widget.ticket['id'] ?? '').toString());
    if (!mounted) return;
    if (w != null) {
      setState(() {
        _wifiEstado = 'lista';
        _wifiRed = w.red;
      });
    }
    if (result == 'dispositivos_listos') setState(() => _dispositivosHechos = true);
  }

  bool _step5Completed = false;

  /// Paso «Wi‑Fi de la casa» (Carlos, 2026-10-22): pendiente | lista | omitida. Va antes de
  /// «Agregar dispositivos»; se puede omitir y volver a él hasta el cierre.
  late String _wifiEstado = ((widget.ticket['wifiCasa'] as Map?)?['estado'] ?? 'pendiente').toString();
  late String _wifiRed = ((widget.ticket['wifiCasa'] as Map?)?['red'] ?? '').toString();
  bool get _wifiResuelto => _wifiEstado == 'lista' || _wifiEstado == 'omitida';

  Future<void> _abrirWifiCasa(BuildContext context) async {
    final ticket = {
      ...widget.ticket,
      'wifiCasa': {'estado': _wifiEstado, 'red': _wifiRed},
    };
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => WifiCasaScreen(ticket: ticket)));
    if (!mounted || result == null) return;
    final w = await WifiCasaLocal.instancia.leer((widget.ticket['id'] ?? '').toString());
    if (!mounted) return;
    setState(() {
      _wifiEstado = result == 'wifi_lista' ? 'lista' : 'omitida';
      _wifiRed = result == 'wifi_lista' ? (w?.red ?? _wifiRed) : '';
    });
  }

  /// Abre el cierre (paso 5 en instalaciones, 4 en reparaciones) y marca el paso al terminar.
  Future<void> _abrirCierre(BuildContext context) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CierreInstalacionScreen(ticket: widget.ticket)));
    if (result == 'cierre_completed' && mounted) {
      setState(() => _step5Completed = true);
      // El cierre ya se envió en su pantalla: aquí sólo se celebra (auditoría 2026-10-23; antes había
      // que tocar un segundo «Terminar» que fingía 2.5 s de envío sin mandar nada).
      await _submitFinalInstallation();
    }
  }

  /// El paso 3 es una variante: instalación de cerca por defecto, o
  /// reparación cuando el ticket es de tipo reparación. Se detecta por
  /// el campo `type` del ticket o, en su defecto, por el título.
  bool get _isReparacion {
    final type = (widget.ticket["type"] as String?)?.toLowerCase() ?? '';
    if (type.contains('reparacion') || type.contains('reparación')) return true;
    final title = (widget.ticket["title"] as String?)?.toLowerCase() ?? '';
    return title.contains('reparacion') || title.contains('reparación');
  }

  Timer? _toastTimer;

  /// Paso bloqueado que se acaba de tocar: debajo dice qué falta (v2, 2026-10-23).
  String? _pasoAviso;

  @override
  void initState() {
    super.initState();
    // Retomar: lo que ya quedó guardado en Odoo no se vuelve a pedir.
    _step1Completed = widget.pasoInicial > 1;
    _step2Completed = widget.pasoInicial > 2;
    _step3Completed = widget.pasoInicial > 3;
    // Build 54: 4 = «Agregar dispositivos» (energizador opcional, prueba y demás), 5 = cierre.
    // El aviso «Vas en camino» sólo aplica al arrancar la ruta, no al retomar.
    _showToast = widget.pasoInicial <= 1;
    // El aviso se va solo a los 4 segundos.
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Número público («i76») si la orden viene de una intervención; vacío en tareas viejas.
  String get _numero {
    final details = widget.ticket['details'];
    final origen = details is Map ? (details['origen'] ?? '').toString() : '';
    return origen == 'intervencion' ? (widget.ticket['id'] ?? '').toString() : '';
  }

  /// Lo primero que falta para abrir un paso bloqueado, dicho como instrucción.
  String _primeroFalta() {
    if (!_step1Completed) return 'Primero marca tu llegada en «Ruta».';
    if (!_step2Completed) return 'Primero termina la inspección del perímetro.';
    if (!_step3Completed) return _isReparacion ? 'Primero termina la reparación de la cerca.' : 'Primero termina la cerca eléctrica.';
    if (!_isReparacion && !_wifiResuelto) return 'Primero guarda u omite la Wi‑Fi de la casa.';
    if (_step5Completed) return _isReparacion ? 'La reparación ya se cerró.' : 'La instalación ya se cerró.';
    return 'Este paso todavía no se puede abrir.';
  }

  /// Qué falta para «Terminar», en minúsculas para [FaltaParaSeguir].
  List<String> get _faltantes => [
    if (!_step1Completed) 'la llegada',
    if (!_step2Completed) 'la inspección',
    if (!_step3Completed) _isReparacion ? 'la reparación' : 'la cerca',
    if (!_isReparacion && !_wifiResuelto) 'la Wi‑Fi de la casa',
    if (!_step5Completed) 'el cierre',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final details = widget.ticket["details"] as Map<String, String>;
    final isUrgent = widget.ticket["isUrgent"] as bool? ?? false;
    final cliente = (widget.ticket["user"] ?? '').toString();
    final direccion = details["direccion"] ?? '';
    final ciudadCp = [details["ciudad"] ?? '', details["cp"] ?? ''].where((x) => x.trim().isNotEmpty).join(' · ');
    final destino = DestinoServicio.deDetalles(details);
    final titulo = '${_isReparacion ? 'Reparación' : 'Instalación'}${_numero.isEmpty ? '' : ' $_numero'}';

    final pasos = <_Paso>[
      _Paso(
        numero: "1",
        titulo: "Ruta",
        subtitulo: _step1Completed ? "Llegada marcada" : "Vas en camino al domicilio",
        activo: !_step1Completed,
        listo: _step1Completed,
        onTap: !_step1Completed
            ? () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailsScreen(ticket: widget.ticket)));
                if (result == 'arrived') {
                  setState(() {
                    _step1Completed = true;
                  });
                }
              }
            : null,
      ),
      _Paso(
        numero: "2",
        titulo: "Inspección del perímetro",
        subtitulo: _step2Completed ? "Inspección guardada" : "Obstáculos y metraje real",
        activo: _step1Completed && !_step2Completed,
        listo: _step2Completed,
        onTap: (_step1Completed && !_step2Completed)
            ? () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => PerimeterInspectionScreen(ticket: widget.ticket)));
                if (result == 'perimeter_completed') {
                  setState(() {
                    _step2Completed = true;
                  });
                }
              }
            : null,
      ),
      _Paso(
        numero: "3",
        titulo: _isReparacion ? "Reparación de la cerca" : "Cerca eléctrica",
        subtitulo: _isReparacion ? "Costeo de hilos, componentes y energizador" : "Postes, líneas y letreros que instalaste",
        activo: _step2Completed && !_step3Completed,
        listo: _step3Completed,
        onTap: (_step2Completed && !_step3Completed)
            ? () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _isReparacion ? ReparacionScreen(ticket: widget.ticket) : FenceInstallationScreen(ticket: widget.ticket),
                  ),
                );
                final expected = _isReparacion ? 'reparacion_completed' : 'installation_completed';
                if (result == expected) {
                  setState(() {
                    _step3Completed = true;
                  });
                }
              }
            : null,
      ),
      // «Wi‑Fi de la casa» (Carlos, 2026-10-22): antes de agregar dispositivos; se omite con un
      // toque y se puede volver a él hasta el cierre.
      if (!_isReparacion)
        _Paso(
          numero: "4",
          titulo: "Wi‑Fi de la casa",
          subtitulo: _wifiEstado == 'lista'
              ? "Lista: «$_wifiRed» · toca para cambiarla"
              : _wifiEstado == 'omitida'
              ? "Omitido · tócalo si la casa sí la necesita"
              : "Opcional · para sensores, cámaras y el energizador",
          activo: _step3Completed && !_wifiResuelto && !_step5Completed,
          listo: _wifiResuelto,
          onTap: (_step3Completed && !_step5Completed) ? () => _abrirWifiCasa(context) : null,
        ),
      // Energizador opcional (Carlos, 2026-10-20): vincular el energizador y su prueba viven
      // dentro de «Agregar dispositivos», que se abre en cuanto se resuelve la Wi‑Fi de la casa.
      if (!_isReparacion)
        _Paso(
          numero: "5",
          titulo: "Agregar dispositivos",
          subtitulo: _dispositivosHechos
              ? "Listo. Puedes volver a entrar si el cliente compra algo más"
              : "Energizador (si lleva), sensores, cámaras y sus pruebas",
          activo: _step3Completed && _wifiResuelto && !_dispositivosHechos && !_step5Completed,
          listo: _dispositivosHechos,
          onTap: (_step3Completed && _wifiResuelto && !_step5Completed) ? () => _abrirDispositivos(context) : null,
        ),
      // Cierre: paso 4 en reparaciones o 6 en instalaciones; en instalaciones se habilita cuando
      // la Wi‑Fi de la casa quedó lista u omitida («Agregar dispositivos» es opcional).
      _Paso(
        numero: _isReparacion ? "4" : "6",
        titulo: "Cierre",
        subtitulo: _isReparacion ? "Fotos, entrega y firma del cliente" : "Fotos, entrega del equipo y firma del cliente",
        activo: _step3Completed && (_isReparacion || _wifiResuelto) && !_step5Completed,
        listo: _step5Completed,
        onTap: (_step3Completed && (_isReparacion || _wifiResuelto) && !_step5Completed) ? () => _abrirCierre(context) : null,
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // v2 (2026-10-23): «Instalación i76» con cliente · dirección.
                EncabezadoFlujo(
                  titulo: titulo,
                  subtitulo: [cliente, direccion].where((x) => x.trim().isNotEmpty).join(' · '),
                  alVolver: () => Navigator.pop(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), // Sin barra inferior dentro del flujo (auditoría 2026-10-23)
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (isUrgent)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Align(alignment: Alignment.centerLeft, child: InsigniaUrgente()),
                        ),
                      _BarraAvance(pasos: pasos),
                      const SizedBox(height: 24),
                      const EtiquetaSeccion("Pasos"),
                      GrupoFilas(
                        children: [
                          for (var i = 0; i < pasos.length; i++)
                            EntradaSuave(
                              index: i,
                              child: _filaPaso(
                                pasos[i],
                                // Bloqueado: vibra suave y dice qué falta en vez de «no hacer nada».
                                alTocarBloqueado: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _pasoAviso = pasos[i].numero);
                                },
                              ),
                            ),
                        ],
                      ),
                      const EtiquetaSeccion("Cliente"),
                      GrupoFilas(
                        children: [
                          FilaFlujo(
                            leading: Icon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                            titulo: cliente.isEmpty ? 'Cliente' : cliente,
                            subtitulo: details["telefono"],
                          ),
                          FilaFlujo(
                            leading: Icon(Icons.place_outlined, color: cs.onSurfaceVariant),
                            titulo: direccion.isEmpty ? 'Sin dirección' : direccion,
                            subtitulo: ciudadCp,
                            trailing: destino.vacio ? null : BotonFila(etiqueta: 'Cómo llegar', onPressed: () => mostrarComoLlegar(context, destino)),
                          ),
                        ],
                      ),
                      OhmGradientButton(
                        label: _isReparacion ? "Terminar reparación" : "Terminar instalación",
                        onPressed: _step5Completed ? _submitFinalInstallation : null,
                      ),
                      if (!_step5Completed) ...[const SizedBox(height: 12), FaltaParaSeguir(_faltantes)],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Aviso momentáneo arriba («Vas en camino al domicilio»); se va solo a los 4 s.
          AnimatedPositioned(
            duration: AppMotion.of(context, AppDurations.slow),
            curve: AppCurves.standard,
            top: _showToast ? 64 : -100,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: AppMotion.of(context, AppDurations.base),
              curve: AppCurves.standard,
              opacity: _showToast ? 1.0 : 0.0,
              child: Semantics(
                liveRegion: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: ohm.successContainer, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_rounded, color: ohm.success, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Vas en camino al domicilio",
                          style: theme.textTheme.bodyMedium?.copyWith(color: ohm.onSuccessContainer, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fila de un paso (v2): círculo verde ✓ (listo), naranja con número (se puede hacer ahora) o
  /// contorno gris con número (pendiente). Si está bloqueado y se tocó, dice qué falta.
  Widget _filaPaso(_Paso paso, {required VoidCallback alTocarBloqueado}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final bloqueado = paso.onTap == null && !paso.listo;
    final aviso = bloqueado && _pasoAviso == paso.numero;

    final Widget circulo;
    if (paso.listo) {
      circulo = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: ohm.success, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
      );
    } else if (paso.activo) {
      circulo = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: Text(paso.numero, style: theme.textTheme.titleSmall?.copyWith(color: cs.onPrimary, height: 1)),
      );
    } else {
      circulo = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
        child: Text(
          paso.numero,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, height: 1),
        ),
      );
    }

    final onTap = paso.onTap ?? (bloqueado ? alTocarBloqueado : null);
    return Semantics(
      button: onTap != null,
      label: '${paso.titulo}. ${paso.listo ? 'Listo' : (paso.activo ? 'Se puede hacer ahora' : 'Pendiente')}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Presionable(
            activo: paso.onTap != null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  CambioSuave(
                    alineacion: Alignment.center,
                    child: KeyedSubtree(key: ValueKey('${paso.numero}-${paso.listo}-${paso.activo}'), child: circulo),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paso.titulo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: paso.activo ? FontWeight.w600 : FontWeight.w500,
                            color: bloqueado ? cs.onSurfaceVariant : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(paso.subtitulo, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        AnimatedSize(
                          duration: AppMotion.of(context, AppDurations.base),
                          curve: AppCurves.standard,
                          alignment: Alignment.topLeft,
                          child: aviso
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline_rounded, size: 16, color: ohm.warning),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(_primeroFalta(), style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface)),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                  if (paso.onTap != null) ...[const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fin de la visita: borra la Wi‑Fi de este teléfono, la anota en el historial y muestra el éxito.
  /// No envía nada: el cierre ya se mandó (y se confirmó) en su pantalla.
  Future<void> _submitFinalInstallation() async {
    // La contraseña de la Wi‑Fi de la casa sólo vive durante la visita (opción A, 2026-10-22).
    await WifiCasaLocal.instancia.borrar((widget.ticket['id'] ?? '').toString());

    if (!mounted) return;
    final bool isRep = _isReparacion;
    // Registra el ticket completado en el historial del instalador.
    AppStateProvider.of(context).addCompletedTicket(widget.ticket);

    // Aviso de éxito (v2): verde, centrado; no es una decisión, sólo un aviso con una salida.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final ohm = context.ohm;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: cs.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: ohm.successContainer, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_rounded, color: ohm.success, size: 48),
                ),
                const SizedBox(height: 20),
                Text(isRep ? "¡Reparación terminada!" : "¡Instalación terminada!", style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  isRep
                      ? "Enviamos el costeo, las fotos con su ubicación y la firma del cliente."
                      : "Enviamos las fotos con su ubicación, la entrega del equipo y la firma del cliente.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OhmGradientButton(
                  label: isRep ? "Volver a reparaciones" : "Volver a instalaciones",
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    volverAListado(context, isRep ? const ReparacionesScreen() : InstalacionesScreen(completedTicketTitle: widget.ticket["title"]));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Un paso del servicio: lo que se pinta y qué abre. [onTap] null = no se puede abrir hoy.
class _Paso {
  const _Paso({required this.numero, required this.titulo, required this.subtitulo, required this.activo, required this.listo, this.onTap});

  final String numero;
  final String titulo;
  final String subtitulo;
  final bool activo;
  final bool listo;
  final VoidCallback? onTap;
}

/// Barra de avance (v2): un segmento por paso; verde listo, naranja lo que se puede hacer ahora y
/// gris lo pendiente.
class _BarraAvance extends StatelessWidget {
  const _BarraAvance({required this.pasos});

  final List<_Paso> pasos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    final listos = pasos.where((p) => p.listo).length;
    return Semantics(
      label: '$listos de ${pasos.length} pasos listos',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (var i = 0; i < pasos.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppDurations.base),
                    curve: AppCurves.standard,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pasos[i].listo ? ohm.success : (pasos[i].activo ? cs.primary : cs.outlineVariant),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
