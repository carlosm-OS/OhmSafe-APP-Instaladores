import 'package:flutter/material.dart';
import '../config/repair_pricing.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import 'fence_installation_screen.dart' show Contador;
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/entities/tarifas.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

/// ============================================================
/// OHMSAFE ARMY — Sección Reparaciones
/// ------------------------------------------------------------
/// Motor de costeo por hilo:
///  - Lista de hilos dañados; cada hilo lleva SUS metros y SU
///    nivel de dificultad (el hilo 4 puede estar a 10 m y el 2 a 2 m).
///  - Componentes a cambiar (postes esquina/paso, abanicos,
///    aisladores sueltos, tensores, energizador).
///  - Separa mano de obra (pago al instalador) de material (OhmSafe).
///  - Valida contra el inventario de instalación y la plausibilidad
///    por edad de la cerca (desgaste vs evento externo).
/// Sistema v2 (2026-10-23): grupos blancos, contadores en píldora y el naranja sólo en el botón.
/// ============================================================

class ReparacionScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  /// Inventario precargado del cierre de instalación.
  /// En producción viene del backend (HubSpot/Odoo); aquí con defaults.
  final int perimetroMetros;
  final int lineasInstaladas;
  final int postesEsquinaInstalados;
  final int postesPasoInstalados;
  final int abanicosInstalados;
  final int aisladoresPorPoste;
  final int edadCercaAnios;

  const ReparacionScreen({
    super.key,
    required this.ticket,
    this.perimetroMetros = 65,
    this.lineasInstaladas = 5,
    this.postesEsquinaInstalados = 4,
    this.postesPasoInstalados = 8,
    this.abanicosInstalados = 5,
    this.aisladoresPorPoste = 5,
    this.edadCercaAnios = 1,
  });

  @override
  State<ReparacionScreen> createState() => _ReparacionScreenState();
}

/// Un hilo dañado con sus metros y su propia dificultad.
class _HiloDanado {
  double metros = 5;
  DificultadHilo dificultad = DificultadHilo.normal;
}

class _ReparacionScreenState extends State<ReparacionScreen> {
  final List<_HiloDanado> _hilos = [_HiloDanado()];

  /// Tarifas vivas de Odoo (vía backend). Arranca con los valores de respaldo
  /// [Tarifas.defaults] y se refresca en [initState]; si el backend falla, la
  /// calculadora sigue con el respaldo.
  Tarifas _t = Tarifas.defaults();

  @override
  void initState() {
    super.initState();
    _cargarTarifas();
  }

  /// Baja las tarifas del backend (precios de los productos de Odoo). Cambiar
  /// un precio en Odoo se refleja aquí en la siguiente apertura de la pantalla.
  Future<void> _cargarTarifas() async {
    final result = await sl.get<OrdenesRepository>().getTarifas();
    if (!mounted) return;
    result.fold((tarifas) => setState(() => _t = tarifas), (_) {
      /* se conserva el respaldo Tarifas.defaults() */
    });
  }

  /// % extra de dificultad por hilo, tomado de las tarifas vivas.
  double _pctExtra(DificultadHilo d) => switch (d) {
    DificultadHilo.medio => _t.difMedioPct,
    DificultadHilo.alto => _t.difAltoPct,
    DificultadHilo.normal => 0,
  };

  int _postesEsquina = 0;
  int _postesPaso = 0;
  int _abanicos = 0;
  int _aisladoresSueltos = 0;
  int _tensores = 0;

  /// 0 = ninguno, 1 = simple, 2 = con batería
  int _energizador = 0;

  /// true = desgaste (oxidación/degradación), false = evento externo
  bool _causaDesgaste = false;

  // ------------------------- CÁLCULO -------------------------

  double get _metrosHiloTotales => _hilos.fold(0, (s, h) => s + h.metros);

  /// Mano de obra de hilos: cada hilo con SU multiplicador de dificultad.
  double get _moHilos => _hilos.fold(0, (s, h) => s + h.metros * _t.metroHilo * (1 + _pctExtra(h.dificultad) / 100));

  double get _moPiezas =>
      _postesEsquina * _t.posteEsquina + _postesPaso * _t.postePaso + _abanicos * _t.abanico + _aisladoresSueltos * _t.aisladorSuelto + _tensores * _t.tensor;

  double get _moEnergizador => switch (_energizador) {
    1 => _t.energizadorSimple,
    2 => _t.energizadorBateria,
    _ => 0,
  };

  double get _moTotal => _t.visita + _moHilos + _moPiezas + _moEnergizador;

  int get _postesCambiados => _postesEsquina + _postesPaso;
  int get _aisladoresEnPostes => _postesCambiados * widget.aisladoresPorPoste;

  double get _matAlambre => _t.metrosPorRollo > 0 ? _metrosHiloTotales * (_t.rolloAlambre3kg / _t.metrosPorRollo) : 0;

  double get _matEnergizador => switch (_energizador) {
    1 => _t.matEnergizadorSimple,
    2 => _t.matEnergizadorBateria,
    _ => 0,
  };

  double get _matTotal =>
      _matAlambre +
      _postesEsquina * _t.matPosteEsquina +
      _postesPaso * _t.matPostePaso +
      _abanicos * _t.matAbanico +
      (_aisladoresEnPostes + _aisladoresSueltos) * _t.matAislador +
      _tensores * _t.matTensor +
      _matEnergizador;

  // --------------------- VALIDACIONES ---------------------

  List<String> get _inconsistenciasInventario {
    final msgs = <String>[];
    if (_hilos.length > widget.lineasInstaladas) {
      msgs.add('Se reportan ${_hilos.length} hilos y la instalación tiene ${widget.lineasInstaladas}');
    }
    for (var i = 0; i < _hilos.length; i++) {
      if (_hilos[i].metros > widget.perimetroMetros) {
        msgs.add('El hilo ${i + 1} (${_hilos[i].metros.toStringAsFixed(0)} m) excede el perímetro (${widget.perimetroMetros} m)');
      }
    }
    if (_postesEsquina > widget.postesEsquinaInstalados) {
      msgs.add('Postes esquina reportados ($_postesEsquina) exceden los instalados (${widget.postesEsquinaInstalados})');
    }
    if (_postesPaso > widget.postesPasoInstalados) {
      msgs.add('Postes de paso reportados ($_postesPaso) exceden los instalados (${widget.postesPasoInstalados})');
    }
    if (_abanicos > widget.abanicosInstalados) {
      msgs.add('Abanicos reportados ($_abanicos) exceden los instalados (${widget.abanicosInstalados})');
    }
    final aisInstalados = (widget.postesEsquinaInstalados + widget.postesPasoInstalados) * widget.aisladoresPorPoste;
    final aisTotales = _aisladoresEnPostes + _aisladoresSueltos;
    if (aisTotales > aisInstalados && aisInstalados > 0) {
      msgs.add('Aisladores totales ($aisTotales) exceden los de la instalación ($aisInstalados)');
    }
    final largos = _hilos.where((h) => h.metros > _t.tramoMaxMetros).length;
    if (largos > 0) {
      final cuantos = largos == 1 ? '1 hilo supera' : '$largos hilos superan';
      msgs.add('$cuantos el tramo máximo de ${_t.tramoMaxMetros.toStringAsFixed(0)} m. Es válido si abarca varios tramos; verifícalo con foto');
    }
    return msgs;
  }

  String? get _alertaPlausibilidad {
    if (!_causaDesgaste) return null;
    final tocaAislador = (_aisladoresEnPostes + _aisladoresSueltos) > 0;
    final tocaCable = _metrosHiloTotales > 0;
    final partes = <String>[];
    if (tocaAislador && widget.edadCercaAnios < _t.vidaMinAisladorAnios) {
      partes.add('desgaste de aisladores en una cerca de ${_anios(widget.edadCercaAnios)}; vida mínima ${_t.vidaMinAisladorAnios} años');
    }
    if (tocaCable && widget.edadCercaAnios < _t.vidaMinCableAnios) {
      partes.add('cable por desgaste antes de ${_t.vidaMinCableAnios} años');
    }
    if (partes.isEmpty) return null;
    final texto = partes.join('; ');
    return '${texto[0].toUpperCase()}${texto.substring(1)}. Toma foto y valida con operaciones antes de autorizar.';
  }

  /// «1 año», «3 años».
  String _anios(int n) => n == 1 ? '1 año' : '$n años';

  String _peso(double n) => '\$${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  // ------------------------- UI -------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final inconsistencias = _inconsistenciasInventario;
    final plausibilidad = _alertaPlausibilidad;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // v2 (2026-10-23): encabezado único en vez del AppBar de Material.
            EncabezadoFlujo(titulo: 'Reparación', subtitulo: (widget.ticket['user'] ?? '').toString(), alVolver: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  const EtiquetaSeccion('Registro de la instalación'),
                  GrupoFilas(
                    children: [
                      FilaFlujo(
                        titulo: '${widget.perimetroMetros} m · ${widget.lineasInstaladas} líneas',
                        subtitulo:
                            '${widget.postesEsquinaInstalados} postes esquina + ${widget.postesPasoInstalados} de paso · '
                            '${widget.abanicosInstalados} abanicos · cerca de ${_anios(widget.edadCercaAnios)}',
                      ),
                    ],
                  ),
                  const EtiquetaSeccion('Hilos dañados'),
                  GrupoFilas(children: [..._hilos.asMap().entries.map((e) => _hiloFila(theme, e.key, e.value)), _agregarHilo(theme)]),
                  const EtiquetaSeccion('Componentes a cambiar'),
                  GrupoFilas(
                    children: [
                      _counterRow('Postes esquina', _postesEsquina, (v) => setState(() => _postesEsquina = v)),
                      _counterRow('Postes de paso', _postesPaso, (v) => setState(() => _postesPaso = v)),
                      _counterRow('Abanicos', _abanicos, (v) => setState(() => _abanicos = v)),
                      _counterRow('Aisladores sueltos', _aisladoresSueltos, (v) => setState(() => _aisladoresSueltos = v)),
                      _counterRow('Tensores', _tensores, (v) => setState(() => _tensores = v)),
                    ],
                  ),
                  const EtiquetaSeccion('Energizador'),
                  _segmentado(theme, ['Ninguno', 'Simple', 'Con batería'], _energizador, (i) => setState(() => _energizador = i)),
                  const SizedBox(height: 24),
                  const EtiquetaSeccion('Causa de la falla'),
                  _segmentado(theme, ['Evento externo', 'Desgaste'], _causaDesgaste ? 1 : 0, (i) => setState(() => _causaDesgaste = i == 1)),
                  const SizedBox(height: 24),
                  if (plausibilidad != null)
                    MensajeFlujo(icono: Icons.warning_amber_rounded, color: ohm.warning, titulo: 'Revisa antes de pagar', texto: plausibilidad),
                  if (inconsistencias.isNotEmpty)
                    MensajeFlujo(
                      icono: Icons.fact_check_outlined,
                      color: ohm.warning,
                      titulo: 'No cuadra con el registro de la instalación',
                      texto: '${inconsistencias.join('. ')}.',
                    ),
                  const EtiquetaSeccion('Resumen del costeo'),
                  _resumenCard(theme),
                  const SizedBox(height: 24),
                  // Lo que pasa, pasa junto al botón (v2).
                  if (_error != null)
                    MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: 'No pudimos guardar el costeo de la reparación', texto: _error),
                  _completarButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- WIDGETS -------------------------

  Widget _hiloFila(ThemeData theme, int index, _HiloDanado hilo) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Hilo dañado ${index + 1}', style: theme.textTheme.titleMedium)),
              Contador(
                valor: hilo.metros.toStringAsFixed(0),
                sufijo: ' m',
                alQuitar: () => setState(() => hilo.metros = (hilo.metros - 1).clamp(0, 9999)),
                alAgregar: () => setState(() => hilo.metros += 1),
              ),
              IconButton(
                tooltip: 'Quitar el hilo ${index + 1}',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
                onPressed: _hilos.length > 1 ? () => setState(() => _hilos.removeAt(index)) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Dificultad de este hilo', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _segmentado(
              theme,
              [for (final d in DificultadHilo.values) d.pctExtra > 0 ? '${d.etiqueta} +${d.pctExtra.toStringAsFixed(0)} %' : d.etiqueta],
              DificultadHilo.values.indexOf(hilo.dificultad),
              (i) => setState(() => hilo.dificultad = DificultadHilo.values[i]),
            ),
          ),
        ],
      ),
    );
  }

  /// «Agregar hilo dañado»: fila con el + naranja (ícono de acción), hasta el número de líneas instaladas.
  Widget _agregarHilo(ThemeData theme) {
    final cs = theme.colorScheme;
    final full = _hilos.length >= widget.lineasInstaladas;
    final lineas = widget.lineasInstaladas == 1 ? '1 línea instalada' : '${widget.lineasInstaladas} líneas instaladas';
    return Semantics(
      button: true,
      enabled: !full,
      child: InkWell(
        onTap: full ? null : () => setState(() => _hilos.add(_HiloDanado())),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: full ? cs.surfaceContainerHighest : cs.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: 18, color: full ? cs.onSurfaceVariant : cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  full ? 'Máximo alcanzado: $lineas' : 'Agregar hilo dañado',
                  style: theme.textTheme.titleMedium?.copyWith(color: full ? cs.onSurfaceVariant : cs.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterRow(String label, int value, ValueChanged<int> onChanged) {
    return FilaFlujo(
      titulo: label,
      trailing: Contador(valor: '$value', alQuitar: value > 0 ? () => onChanged((value - 1).clamp(0, 999)) : null, alAgregar: () => onChanged(value + 1)),
    );
  }

  /// Control segmentado v2: riel gris y la opción elegida en blanco, 44 de alto.
  Widget _segmentado(ThemeData theme, List<String> options, int selected, ValueChanged<int> onSelect) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                inMutuallyExclusiveGroup: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppDurations.base),
                    curve: AppCurves.standard,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == selected ? cs.surface : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      options[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                        color: i == selected ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resumenCard(ThemeData theme) {
    final cs = theme.colorScheme;
    return TarjetaFlujo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resumenRow(theme, 'Visita y diagnóstico', _t.visita),
          ..._hilos.asMap().entries.map(
            (e) => _resumenRow(
              theme,
              'Hilo ${e.key + 1}: ${e.value.metros.toStringAsFixed(0)} m · ${e.value.dificultad.etiqueta}',
              e.value.metros * _t.metroHilo * (1 + e.value.dificultad.pctExtra / 100),
            ),
          ),
          if (_moPiezas > 0) _resumenRow(theme, 'Piezas (postes, abanicos, aisladores, tensores)', _moPiezas),
          if (_moEnergizador > 0) _resumenRow(theme, 'Cambio de energizador', _moEnergizador),
          Divider(color: cs.outlineVariant, height: 20, thickness: 0.5),
          _resumenRow(theme, 'Mano de obra (pago al instalador)', _moTotal, bold: true),
          _resumenRow(theme, 'Material (costo OhmSafe)', _matTotal, bold: true),
          const SizedBox(height: 12),
          Text('Costo total del evento', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          Text(_peso(_moTotal + _matTotal), style: theme.textTheme.displayMedium),
        ],
      ),
    );
  }

  Widget _resumenRow(ThemeData theme, String label, double value, {bool bold = false}) {
    final cs = theme.colorScheme;
    final estilo = bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: estilo?.copyWith(color: bold ? cs.onSurface : cs.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Text(_peso(value), style: estilo?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  bool _isSending = false;

  /// Mensaje humano del repositorio si no se pudo guardar; va junto al botón (v2).
  String? _error;

  /// Envía el costeo de la reparación al backend (mano de obra, material,
  /// total y tipo de energizador → campos `x_costo_*`/`x_energizador_tipo` en
  /// Odoo) y, solo si tiene éxito, avanza al cierre con 'reparacion_completed'.
  Future<void> _completarReparacion() async {
    if (_isSending) return;
    // Marca en el ticket si se cambió el energizador; el cierre solo pide
    // serie/evidencia de control cuando esto es true.
    widget.ticket['energizador_cambiado'] = _energizador > 0;
    final costeo = <String, dynamic>{
      'energizador': switch (_energizador) {
        1 => 'simple',
        2 => 'bateria',
        _ => 'ninguno',
      },
      'resumen': {'manoObra': _moTotal, 'material': _matTotal, 'total': _moTotal + _matTotal},
    };
    setState(() {
      _isSending = true;
      _error = null;
    });
    final id = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    final result = await sl.get<OrdenesRepository>().guardarReparacion(id, costeo);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'reparacion_completed'),
      (failure) => setState(() {
        _isSending = false;
        _error = failure.message;
      }),
    );
  }

  Widget _completarButton() {
    final tieneAlgo = _metrosHiloTotales > 0 || _moPiezas > 0 || _energizador > 0;
    return OhmGradientButton(
      label: 'Guardar costeo de la reparación',
      loading: _isSending,
      loadingLabel: 'Guardando el costeo…',
      onPressed: tieneAlgo ? _completarReparacion : null,
    );
  }
}
