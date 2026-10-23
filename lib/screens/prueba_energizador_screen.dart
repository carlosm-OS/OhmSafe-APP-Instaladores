import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import '../widgets/hoja_decision.dart';

/// Prueba del energizador (build 39, Carlos 2026-10-13): después de vincular, el instalador tiene
/// una ventana de tiempo para ENCENDER y APAGAR la cerca y enseñarle al cliente que el equipo
/// trabaja. El permiso lo da el backend sólo mientras la ventana está abierta y se retira al
/// terminar el paso (o al cerrar/cancelar). Sirena, pánico y sensores van en otro paso.
///
/// Devuelve 'prueba_terminada' al salir (terminada u omitida): el flujo sigue al cierre.
class PruebaEnergizadorScreen extends StatefulWidget {
  const PruebaEnergizadorScreen({super.key, required this.ticket});
  final Map<String, dynamic> ticket;

  @override
  State<PruebaEnergizadorScreen> createState() => _PruebaEnergizadorScreenState();
}

class _PruebaEnergizadorScreenState extends State<PruebaEnergizadorScreen> {
  final OrdenesRepository _repo = sl.get<OrdenesRepository>();
  String get _id => (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();

  Map<String, dynamic>? _estado;
  String? _error;
  bool _cargando = true;
  bool _enviando = false;
  Timer? _refresco;

  /// Error al encender o apagar, junto al botón (v2: antes en un SnackBar).
  String? _errorAccion;

  /// Lo que el instalador ya le enseñó al cliente en esta prueba (guía la pantalla: al tener las
  /// dos, «Terminar prueba» pasa a ser la acción principal).
  bool _vioEncendida = false;
  bool _vioApagada = false;
  bool get _demostrada => _vioEncendida && _vioApagada;

  /// La ventana de control existe pero no se muestra (Carlos, 2026-10-14): se abre al entrar, se
  /// renueva sola mientras la pantalla está abierta y se cierra al salir, para que el instalador no
  /// pueda controlar la cerca del cliente después.
  static const _renovarAntesDe = 5 * 60;

  @override
  void initState() {
    super.initState();
    _abrir();
    // El equipo reporta solo; cada 15 s se refresca cómo quedó (cerca, en línea) y se renueva la ventana.
    // Sin señal se consulta cada 5 s: recién vinculado tarda 1 o 2 minutos en aparecer (2026-10-15).
    _refresco = Timer.periodic(const Duration(seconds: 5), (_) {
      _ticks++;
      if (!_enLinea || _ticks % 3 == 0) Actividad.enSilencio(_refrescar);
    });
  }

  int _ticks = 0;
  final DateTime _abiertaDesde = DateTime.now();

  /// Los primeros minutos sin señal son espera normal (el equipo recién se conectó), no un error.
  bool get _esperandoSenal => DateTime.now().difference(_abiertaDesde) < const Duration(minutes: 3);

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _ventana => (_estado?['ventana'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get _equipo => (_estado?['equipo'] as Map?)?.cast<String, dynamic>() ?? const {};
  bool get _abierta => _ventana['abierta'] == true;
  int get _segundosRestantes => (_ventana['segundosRestantes'] as num?)?.toInt() ?? 0;
  bool get _enLinea => _equipo['enLinea'] == true;
  bool get _cercaEncendida => _equipo['cercaEncendida'] == true;

  void _aplicar(Map<String, dynamic> e) {
    setState(() {
      _estado = e;
      _error = null;
    });
  }

  String _msg(Failure f) => f is ServerFailure && f.code.isNotEmpty ? f.message : f.message;

  Future<void> _abrir() async {
    setState(() => _cargando = true);
    final r = await _repo.pruebaAbrir(_id);
    if (!mounted) return;
    r.fold(_aplicar, (f) => setState(() => _error = _msg(f)));
    setState(() => _cargando = false);
  }

  Future<void> _refrescar() async {
    if (_enviando || !mounted) return;
    final r = await _repo.pruebaEstado(_id);
    if (!mounted) return;
    r.fold(_aplicar, (_) {});
    // Renovación silenciosa: sin reloj en pantalla, la ventana no debe vencer a media prueba.
    if (_abierta && _segundosRestantes < _renovarAntesDe) {
      final x = await _repo.pruebaExtender(_id);
      if (mounted) x.fold(_aplicar, (_) {});
    } else if (!_abierta && _estado != null) {
      final x = await _repo.pruebaAbrir(_id);
      if (mounted) x.fold(_aplicar, (_) {});
    }
  }

  Future<void> _accion(String accion) async {
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _errorAccion = null;
    });
    var r = await _repo.pruebaAccion(_id, accion);
    // Si la ventana venció (p. ej. el teléfono estuvo bloqueado), se reabre en silencio y se reintenta una vez.
    final f0 = r.isFailure ? r.failureValue : null;
    if (f0 is ServerFailure && f0.code == 'PRUEBA_NO_ABIERTA') {
      final a = await _repo.pruebaAbrir(_id);
      if (a.isSuccess) r = await _repo.pruebaAccion(_id, accion);
    }
    if (!mounted) return;
    r.fold((e) {
      _aplicar(e);
      if (accion == 'cerca_on') _vioEncendida = true;
      if (accion == 'cerca_off') _vioApagada = true;
    }, (f) => _errorAccion = _msg(f));
    setState(() => _enviando = false);
  }

  Future<void> _terminar({required bool omitir}) async {
    if (_enviando) return;
    if (!omitir && _cercaEncendida) {
      // v2 (2026-10-23): la decisión es una hoja desde abajo, con verbos.
      final ok = await mostrarHojaDecision(
        context,
        titulo: '¿Dejas la cerca encendida?',
        texto: 'Al terminar ya no podrás encenderla ni apagarla desde tu app. Se queda encendida y el control lo tiene sólo el cliente.',
        seguir: 'Dejarla encendida y terminar',
        salir: 'Volver a la prueba',
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _enviando = true);
    final r = await _repo.pruebaTerminar(_id);
    if (!mounted) return;
    // Si el backend ya no tiene ventana (venció, o nunca abrió) igual se sigue: el permiso ya no existe.
    r.fold((_) {}, (f) {
      final s = f is ServerFailure ? f : null;
      if (s == null || !{'PRUEBA_NO_ABIERTA', 'EQUIPO_NO_VINCULADO'}.contains(s.code)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(f))));
      }
    });
    setState(() => _enviando = false);
    Navigator.pop(context, 'prueba_terminada');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final apoyo = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final serie = (_equipo['serie'] ?? '').toString();
    final puedeMandar = _estado != null && _enLinea && !_enviando;
    // Mientras envía, el botón sigue con color y spinner (loading ya ignora los toques).
    final accionAlternar = puedeMandar || (_enviando && _enLinea) ? () => _accion(_cercaEncendida ? 'cerca_off' : 'cerca_on') : null;

    // Cualquier salida (botón, gesto o atrás del sistema) cierra la ventana de control.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _terminar(omitir: true);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EncabezadoFlujo(titulo: 'Prueba del energizador', alVolver: () => _terminar(omitir: true)),
                  Expanded(
                    child: _cargando
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('Abriendo la prueba del energizador…', style: apoyo)),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (_error != null)
                                MensajeFlujo(
                                  icono: Icons.error_outline_rounded,
                                  color: cs.error,
                                  titulo: 'No pudimos conectar con el equipo',
                                  texto: _error!,
                                  accion: BotonFila(etiqueta: 'Volver a intentar', icono: Icons.refresh_rounded, onPressed: _abrir),
                                ),
                              if (!_enLinea && _estado != null && _esperandoSenal) const EsperandoSenal(),
                              if (!_enLinea && _estado != null && !_esperandoSenal)
                                MensajeFlujo(
                                  icono: Icons.wifi_off_rounded,
                                  color: cs.error,
                                  titulo: 'El energizador no tiene señal',
                                  texto: 'Revisa que esté conectado a la corriente y con señal. Esta pantalla se actualiza sola.',
                                ),
                              // v2 (2026-10-23): la ficha oscura pasa a un grupo blanco con estados de punto.
                              GrupoFilas(
                                children: [
                                  FilaFlujo(
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(9)),
                                      child: Icon(Icons.bolt_rounded, size: 18, color: cs.primary),
                                    ),
                                    titulo: serie.isEmpty ? '—' : serie,
                                    subtitulo: 'Energizador',
                                  ),
                                  FilaFlujo(
                                    titulo: 'Conexión',
                                    trailing: EstadoPunto(_enLinea ? 'En línea' : 'Sin señal', color: _enLinea ? ohm.success : cs.error),
                                  ),
                                  FilaFlujo(
                                    key: const Key('prueba-estado-cerca'),
                                    titulo: 'Cerca',
                                    trailing: EstadoPunto(
                                      _cercaEncendida ? 'Encendida' : 'Apagada',
                                      color: _cercaEncendida ? ohm.success : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                                child: Text('Enciende y apaga la cerca frente al cliente para que vea que funciona.', style: theme.textTheme.bodyLarge),
                              ),
                              if (_errorAccion != null)
                                MensajeFlujo(
                                  icono: Icons.error_outline_rounded,
                                  color: cs.error,
                                  titulo: _cercaEncendida ? 'No se apagó la cerca' : 'No se encendió la cerca',
                                  texto: _errorAccion!,
                                ),
                              if (!_demostrada)
                                OhmGradientButton(
                                  key: const Key('prueba-alternar'),
                                  label: _cercaEncendida ? 'Apagar la cerca' : 'Encender la cerca',
                                  icon: _cercaEncendida ? Icons.power_settings_new_rounded : Icons.bolt_rounded,
                                  loading: _enviando,
                                  loadingLabel: _cercaEncendida ? 'Apagando la cerca…' : 'Encendiendo la cerca…',
                                  onPressed: accionAlternar,
                                )
                              else
                                BotonSecundario(
                                  key: const Key('prueba-alternar'),
                                  etiqueta: _cercaEncendida ? 'Apagar la cerca' : 'Encender la cerca',
                                  icono: _cercaEncendida ? Icons.power_settings_new_rounded : Icons.bolt_rounded,
                                  onPressed: puedeMandar ? accionAlternar : null,
                                ),
                              const SizedBox(height: 24),

                              const EtiquetaSeccion(
                                'Muéstrale al cliente',
                                tituloAyuda: 'Control temporal de la cerca',
                                ayuda: [
                                  'Sólo puedes encender o apagar la cerca del cliente mientras esta pantalla está abierta.',
                                  'Al terminar o salir, ese control se retira y queda sólo en manos del cliente.',
                                  'La cerca se queda como esté en ese momento.',
                                  'La sirena y los sensores se prueban en el siguiente paso.',
                                ],
                              ),
                              GrupoFilas(
                                children: [
                                  FilaFlujo(
                                    titulo: 'Encendiste la cerca',
                                    marcada: _vioEncendida,
                                    trailing: CirculoCheck(marcado: _vioEncendida),
                                  ),
                                  FilaFlujo(
                                    titulo: 'La apagaste',
                                    marcada: _vioApagada,
                                    trailing: CirculoCheck(marcado: _vioApagada),
                                  ),
                                ],
                              ),

                              if (_demostrada)
                                OhmGradientButton(
                                  label: 'Terminar prueba',
                                  loading: _enviando,
                                  loadingLabel: 'Guardando la prueba…',
                                  onPressed: () => _terminar(omitir: false),
                                )
                              else
                                BotonSecundario(etiqueta: 'Terminar prueba', onPressed: _enviando ? null : () => _terminar(omitir: false)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            // La barra es un Positioned: va sobre el Stack, no dentro de la columna.
          ],
        ),
      ),
    );
  }
}
