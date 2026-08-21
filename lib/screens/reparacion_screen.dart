import 'package:flutter/material.dart';
import '../config/repair_pricing.dart';

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
/// Sigue el patrón visual de la app: naranja FF5A00, tarjetas 1E293B.
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
  double metros;
  DificultadHilo dificultad;
  _HiloDanado({this.metros = 5, this.dificultad = DificultadHilo.normal});
}

class _ReparacionScreenState extends State<ReparacionScreen> {
  static const orangeAccent = Color(0xFFFF5A00);
  static const darkCard = Color(0xFF1E293B);
  static const warnRed = Color(0xFFD43F00);

  final List<_HiloDanado> _hilos = [_HiloDanado()];

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

  double get _metrosHiloTotales =>
      _hilos.fold(0, (s, h) => s + h.metros);

  /// Mano de obra de hilos: cada hilo con SU multiplicador de dificultad.
  double get _moHilos => _hilos.fold(
      0,
      (s, h) =>
          s + h.metros * RepairPricing.metroHilo * (1 + h.dificultad.pctExtra / 100));

  double get _moPiezas =>
      _postesEsquina * RepairPricing.posteEsquina +
      _postesPaso * RepairPricing.postePaso +
      _abanicos * RepairPricing.abanico +
      _aisladoresSueltos * RepairPricing.aisladorSuelto +
      _tensores * RepairPricing.tensor;

  double get _moEnergizador => switch (_energizador) {
        1 => RepairPricing.energizadorSimple,
        2 => RepairPricing.energizadorBateria,
        _ => 0,
      };

  double get _moTotal =>
      RepairPricing.visita + _moHilos + _moPiezas + _moEnergizador;

  int get _postesCambiados => _postesEsquina + _postesPaso;
  int get _aisladoresEnPostes => _postesCambiados * widget.aisladoresPorPoste;

  double get _matAlambre => RepairPricing.metrosPorRollo > 0
      ? _metrosHiloTotales *
          (RepairPricing.rolloAlambre3kg / RepairPricing.metrosPorRollo)
      : 0;

  double get _matEnergizador => switch (_energizador) {
        1 => RepairPricing.matEnergizadorSimple,
        2 => RepairPricing.matEnergizadorBateria,
        _ => 0,
      };

  double get _matTotal =>
      _matAlambre +
      _postesEsquina * RepairPricing.matPosteEsquina +
      _postesPaso * RepairPricing.matPostePaso +
      _abanicos * RepairPricing.matAbanico +
      (_aisladoresEnPostes + _aisladoresSueltos) * RepairPricing.matAislador +
      _tensores * RepairPricing.matTensor +
      _matEnergizador;

  // --------------------- VALIDACIONES ---------------------

  List<String> get _inconsistenciasInventario {
    final msgs = <String>[];
    if (_hilos.length > widget.lineasInstaladas) {
      msgs.add(
          'Se reportan ${_hilos.length} hilos y la instalación tiene ${widget.lineasInstaladas}');
    }
    for (var i = 0; i < _hilos.length; i++) {
      if (_hilos[i].metros > widget.perimetroMetros) {
        msgs.add(
            'El hilo ${i + 1} (${_hilos[i].metros.toStringAsFixed(0)} m) excede el perímetro (${widget.perimetroMetros} m)');
      }
    }
    if (_postesEsquina > widget.postesEsquinaInstalados) {
      msgs.add(
          'Postes esquina reportados ($_postesEsquina) exceden los instalados (${widget.postesEsquinaInstalados})');
    }
    if (_postesPaso > widget.postesPasoInstalados) {
      msgs.add(
          'Postes de paso reportados ($_postesPaso) exceden los instalados (${widget.postesPasoInstalados})');
    }
    if (_abanicos > widget.abanicosInstalados) {
      msgs.add(
          'Abanicos reportados ($_abanicos) exceden los instalados (${widget.abanicosInstalados})');
    }
    final aisInstalados =
        (widget.postesEsquinaInstalados + widget.postesPasoInstalados) *
            widget.aisladoresPorPoste;
    final aisTotales = _aisladoresEnPostes + _aisladoresSueltos;
    if (aisTotales > aisInstalados && aisInstalados > 0) {
      msgs.add(
          'Aisladores totales ($aisTotales) exceden los de la instalación ($aisInstalados)');
    }
    final largos =
        _hilos.where((h) => h.metros > RepairPricing.tramoMaxMetros).length;
    if (largos > 0) {
      msgs.add(
          '$largos hilo(s) superan el tramo máximo de ${RepairPricing.tramoMaxMetros.toStringAsFixed(0)} m — válido si abarcan varios tramos, verificar con foto');
    }
    return msgs;
  }

  String? get _alertaPlausibilidad {
    if (!_causaDesgaste) return null;
    final tocaAislador = (_aisladoresEnPostes + _aisladoresSueltos) > 0;
    final tocaCable = _metrosHiloTotales > 0;
    final partes = <String>[];
    if (tocaAislador &&
        widget.edadCercaAnios < RepairPricing.vidaMinAisladorAnios) {
      partes.add(
          'desgaste de aisladores en una cerca de ${widget.edadCercaAnios} año(s); vida mínima ${RepairPricing.vidaMinAisladorAnios} años');
    }
    if (tocaCable && widget.edadCercaAnios < RepairPricing.vidaMinCableAnios) {
      partes.add(
          'cable por desgaste antes de ${RepairPricing.vidaMinCableAnios} años');
    }
    if (partes.isEmpty) return null;
    return '${partes.join('; ')}. Pedir foto y validar con operaciones antes de autorizar.';
  }

  String _peso(double n) =>
      '\$${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  // ------------------------- UI -------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inconsistencias = _inconsistenciasInventario;
    final plausibilidad = _alertaPlausibilidad;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reparación',
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _propiedadCard(theme),
              const SizedBox(height: 18),
              _sectionTitle('HILOS DAÑADOS', theme),
              const SizedBox(height: 8),
              ..._hilos.asMap().entries.map(
                  (e) => _hiloCard(theme, e.key, e.value)),
              _addHiloButton(theme),
              const SizedBox(height: 18),
              _sectionTitle('COMPONENTES A CAMBIAR', theme),
              const SizedBox(height: 8),
              _counterRow(theme, 'Postes esquina', _postesEsquina,
                  (v) => setState(() => _postesEsquina = v)),
              _counterRow(theme, 'Postes de paso', _postesPaso,
                  (v) => setState(() => _postesPaso = v)),
              _counterRow(theme, 'Abanicos', _abanicos,
                  (v) => setState(() => _abanicos = v)),
              _counterRow(theme, 'Aisladores sueltos', _aisladoresSueltos,
                  (v) => setState(() => _aisladoresSueltos = v)),
              _counterRow(theme, 'Tensores', _tensores,
                  (v) => setState(() => _tensores = v)),
              const SizedBox(height: 14),
              _sectionTitle('ENERGIZADOR', theme),
              const SizedBox(height: 8),
              _segmented(theme, ['Ninguno', 'Simple', 'Con batería'],
                  _energizador, (i) => setState(() => _energizador = i)),
              const SizedBox(height: 14),
              _sectionTitle('CAUSA DE LA FALLA', theme),
              const SizedBox(height: 8),
              _segmented(
                  theme,
                  ['Evento externo', 'Desgaste'],
                  _causaDesgaste ? 1 : 0,
                  (i) => setState(() => _causaDesgaste = i == 1)),
              const SizedBox(height: 20),
              if (plausibilidad != null)
                _alertBox(theme, Icons.warning_amber_rounded, warnRed,
                    'Revisar antes de pagar', plausibilidad),
              if (inconsistencias.isNotEmpty)
                _alertBox(theme, Icons.fact_check_outlined, orangeAccent,
                    'Inconsistencia con el registro de instalación',
                    inconsistencias.join('. ')),
              const SizedBox(height: 6),
              _resumenCard(theme),
              const SizedBox(height: 18),
              _completarButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------- WIDGETS -------------------------

  Widget _sectionTitle(String t, ThemeData theme) => Text(
        t,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
        ),
      );

  Widget _propiedadCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REGISTRO DE INSTALACIÓN',
            style: TextStyle(
                color: orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.perimetroMetros} m · ${widget.lineasInstaladas} líneas · '
            '${widget.postesEsquinaInstalados} esquina + ${widget.postesPasoInstalados} paso · '
            '${widget.abanicosInstalados} abanicos · cerca de ${widget.edadCercaAnios} año(s)',
            style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 13.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _hiloCard(ThemeData theme, int index, _HiloDanado hilo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('H${index + 1}',
                    style: const TextStyle(
                        color: orangeAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Hilo dañado ${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color)),
              ),
              _stepper(
                theme,
                hilo.metros.toStringAsFixed(0),
                onMinus: () => setState(() =>
                    hilo.metros = (hilo.metros - 1).clamp(0, 9999)),
                onPlus: () => setState(() => hilo.metros += 1),
                suffix: 'm',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: warnRed),
                onPressed: _hilos.length > 1
                    ? () => setState(() => _hilos.removeAt(index))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Dificultad de este hilo',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        theme.textTheme.bodyMedium?.color?.withOpacity(0.5))),
          ),
          const SizedBox(height: 6),
          _difChips(theme, hilo),
        ],
      ),
    );
  }

  Widget _difChips(ThemeData theme, _HiloDanado hilo) {
    final vals = DificultadHilo.values;
    // Chips que reparten el ancho disponible (Expanded) para no desbordar
    // en pantallas angostas.
    return Row(
      children: List.generate(vals.length, (i) {
        final d = vals[i];
        final sel = hilo.dificultad == d;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => hilo.dificultad = d),
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? darkCard : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? darkCard : theme.dividerColor, width: 1.4),
              ),
              child: Text(
                d.pctExtra > 0
                    ? '${d.etiqueta} +${d.pctExtra.toStringAsFixed(0)}%'
                    : d.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? orangeAccent
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _addHiloButton(ThemeData theme) {
    final full = _hilos.length >= widget.lineasInstaladas;
    return GestureDetector(
      onTap: full ? null : () => setState(() => _hilos.add(_HiloDanado())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: full
                ? theme.dividerColor
                : orangeAccent.withOpacity(0.6),
            width: 1.6,
            style: BorderStyle.solid,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          full
              ? 'Máximo alcanzado (${widget.lineasInstaladas} líneas instaladas)'
              : '+ Agregar hilo dañado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: full
                ? theme.textTheme.bodyMedium?.color?.withOpacity(0.35)
                : orangeAccent,
          ),
        ),
      ),
    );
  }

  Widget _counterRow(
      ThemeData theme, String label, int value, ValueChanged<int> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color)),
          ),
          _stepper(theme, '$value',
              onMinus: () => onChanged((value - 1).clamp(0, 999)),
              onPlus: () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepper(ThemeData theme, String value,
      {required VoidCallback onMinus,
      required VoidCallback onPlus,
      String suffix = ''}) {
    return Row(
      children: [
        _stepBtn(theme, Icons.remove, onMinus),
        Container(
          width: 52,
          alignment: Alignment.center,
          child: Text('$value$suffix',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: theme.textTheme.bodyLarge?.color)),
        ),
        _stepBtn(theme, Icons.add, onPlus),
      ],
    );
  }

  Widget _stepBtn(ThemeData theme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Icon(icon, size: 17, color: orangeAccent),
      ),
    );
  }

  Widget _segmented(ThemeData theme, List<String> options, int selected,
      ValueChanged<int> onSelect) {
    return Row(
      children: options.asMap().entries.map((e) {
        final sel = e.key == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(e.key),
            child: Container(
              margin: EdgeInsets.only(right: e.key < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: sel ? darkCard : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: sel ? darkCard : theme.dividerColor),
              ),
              alignment: Alignment.center,
              child: Text(
                e.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? orangeAccent
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _alertBox(ThemeData theme, IconData icon, Color color, String title,
      String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color
                            ?.withOpacity(0.75),
                        fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RESUMEN DEL COSTEO',
              style: TextStyle(
                  color: orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          _resumenRow('Visita / diagnóstico', RepairPricing.visita),
          ..._hilos.asMap().entries.map((e) => _resumenRow(
                'Hilo ${e.key + 1} — ${e.value.metros.toStringAsFixed(0)} m · ${e.value.dificultad.etiqueta}',
                e.value.metros *
                    RepairPricing.metroHilo *
                    (1 + e.value.dificultad.pctExtra / 100),
              )),
          if (_moPiezas > 0) _resumenRow('Piezas (postes, abanicos, aisladores, tensores)', _moPiezas),
          if (_moEnergizador > 0)
            _resumenRow('Cambio de energizador', _moEnergizador),
          const Divider(color: Color(0xFF334155), height: 20),
          _resumenRow('MANO DE OBRA (pago al instalador)', _moTotal,
              bold: true, color: orangeAccent),
          _resumenRow('MATERIAL (costo OhmSafe)', _matTotal,
              bold: true, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: orangeAccent, width: 1.5),
            ),
            child: Column(
              children: [
                Text('COSTO TOTAL DEL EVENTO',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white.withOpacity(0.7))),
                Text(_peso(_moTotal + _matTotal),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: orangeAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenRow(String label, double value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color ?? const Color(0xFFCBD5E1),
                    fontSize: bold ? 13 : 12.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          Text(_peso(value),
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: bold ? 15 : 13.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _completarButton(ThemeData theme) {
    final tieneAlgo = _metrosHiloTotales > 0 ||
        _moPiezas > 0 ||
        _energizador > 0;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangeAccent,
          disabledBackgroundColor: theme.dividerColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: tieneAlgo
            ? () {
                // Marca en el ticket si se cambió el energizador; el cierre
                // solo pide serie/evidencia de control cuando esto es true.
                widget.ticket['energizador_cambiado'] = _energizador > 0;
                // En producción: enviar payload al backend y pasar al
                // cierre con fotos geolocalizadas + firma (mismo patrón
                // que CierreInstalacionScreen).
                Navigator.pop(context, 'reparacion_completed');
              }
            : null,
        child: const Text('Completar reparación',
            style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }
}
