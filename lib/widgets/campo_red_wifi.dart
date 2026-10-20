import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/wifi/redes_wifi.dart';

/// Campo «Nombre de la red (Wi‑Fi)» de las pantallas de emparejamiento (2026-10-20, pedido de
/// Carlos: «un buscador de redes para que la encuentre y seleccione»).
///
/// - Se prellena con la red del teléfono ([leerRedActual]) y se vuelve a leer sola cuando la app
///   regresa al frente (el instalador cambió de Wi‑Fi en Ajustes y volvió).
/// - **Android:** el icono de la derecha abre una hoja con las redes cercanas (escaneo real): las de
///   2.4 GHz primero y con su señal; las de 5/6 GHz se ven apagadas, porque el equipo no las ve.
/// - **iOS:** Apple no deja listar redes; el icono vuelve a leer la red conectada y el texto explica
///   que la Wi‑Fi se cambia en Ajustes.
/// - Si el nombre elegido o tecleado huele a 5 GHz («…5G»), avisa debajo sin impedir nada.
class CampoRedWifi extends StatefulWidget {
  const CampoRedWifi({
    super.key,
    required this.controller,
    required this.leerRedActual,
    this.listador,
    this.enabled = true,
    this.onChanged,
    this.esIos,
  });

  final TextEditingController controller;

  /// Nombre de la red a la que está conectado el teléfono (`null` si no se puede leer).
  final Future<String?> Function() leerRedActual;

  /// Las pruebas inyectan uno falso; por omisión el de la plataforma.
  final ListadorRedes? listador;
  final bool enabled;
  final VoidCallback? onChanged;

  /// Sólo para las pruebas (en la app se deduce).
  final bool? esIos;

  @override
  State<CampoRedWifi> createState() => _CampoRedWifiState();
}

class _CampoRedWifiState extends State<CampoRedWifi> with WidgetsBindingObserver {
  late final ListadorRedes _listador = widget.listador ?? ListadorRedesPlataforma();
  late final bool _ios = widget.esIos ?? (!kIsWeb && Platform.isIOS);
  bool _leyendo = true;
  String? _redActual;

  /// Banda de la red elegida en la hoja (en Android el escaneo la sabe; al teclear se pierde).
  BandaWifi? _bandaElegida;
  String? _ssidElegido;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _leerRed(prellenar: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Volvió de Ajustes (o de donde sea): la red del teléfono pudo cambiar.
    if (state == AppLifecycleState.resumed && widget.enabled) _leerRed(prellenar: true);
  }

  Future<void> _leerRed({required bool prellenar}) async {
    setState(() => _leyendo = true);
    final red = await widget.leerRedActual();
    if (!mounted) return;
    setState(() {
      _leyendo = false;
      _redActual = red;
      final vacio = widget.controller.text.trim().isEmpty;
      final eraLaAnterior = widget.controller.text.trim() == (_redActual ?? '') || _ssidElegido == null;
      if (red != null && prellenar && (vacio || eraLaAnterior) && widget.controller.text != red) {
        widget.controller.text = red;
        _ssidElegido = null;
        _bandaElegida = null;
        widget.onChanged?.call();
      }
    });
  }

  Future<void> _elegir() async {
    FocusScope.of(context).unfocus();
    final r = await showModalBottomSheet<RedWifi>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HojaRedes(listador: _listador, actual: _redActual),
    );
    if (r == null || !mounted) return;
    setState(() {
      widget.controller.text = r.ssid;
      _ssidElegido = r.ssid;
      _bandaElegida = r.banda;
    });
    widget.onChanged?.call();
  }

  BandaWifi get _banda {
    final t = widget.controller.text.trim();
    if (_ssidElegido != null && _ssidElegido == t && _bandaElegida != null) return _bandaElegida!;
    return bandaPorNombre(t);
  }

  String get _ayuda {
    if (_leyendo) return 'Leyendo la red del teléfono…';
    final t = widget.controller.text.trim();
    if (t.isNotEmpty && !_banda.sirve) {
      return 'Esa red parece de ${_banda.etiqueta}: el equipo sólo ve redes de 2.4 GHz. Elige la del mismo módem que no diga «5G».';
    }
    if (_ios) {
      return _redActual == null
          ? 'No se pudo leer la red del teléfono. Escríbela tal cual, o conéctate a la Wi‑Fi de la casa en Ajustes y vuelve aquí.'
          : 'Es la red a la que está conectado este teléfono. Para usar otra, cámbiala en Ajustes › Wi‑Fi y vuelve: se actualiza sola.';
    }
    return 'Toca la lista para elegir entre las redes cercanas, o escríbela tal cual aparece en el módem.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.controller.text.trim();
    final alerta = !_leyendo && t.isNotEmpty && !_banda.sirve;
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) {
        setState(() {});
        widget.onChanged?.call();
      },
      decoration: InputDecoration(
        labelText: 'Nombre de la red (Wi‑Fi)',
        helperText: _ayuda,
        helperMaxLines: 3,
        helperStyle: alerta ? TextStyle(color: cs.error) : null,
        suffixIcon: _leyendo
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                tooltip: _listador.puedeListar ? 'Elegir entre las redes cercanas' : 'Volver a leer la red del teléfono',
                icon: Icon(_listador.puedeListar ? Icons.wifi_find_rounded : Icons.refresh_rounded),
                onPressed: !widget.enabled ? null : (_listador.puedeListar ? _elegir : () => _leerRed(prellenar: true)),
              ),
      ),
    );
  }
}

/// Hoja con las redes cercanas (Android). Devuelve (pop) la red tocada.
class _HojaRedes extends StatefulWidget {
  const _HojaRedes({required this.listador, this.actual});
  final ListadorRedes listador;
  final String? actual;

  @override
  State<_HojaRedes> createState() => _HojaRedesState();
}

class _HojaRedesState extends State<_HojaRedes> {
  ResultadoEscaneo? _r;
  bool _buscando = true;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    final r = await widget.listador.escanear();
    if (!mounted) return;
    setState(() {
      _r = r;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = _r;
    final redes = r?.redes ?? const <RedWifi>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Redes Wi‑Fi cercanas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'Buscar de nuevo', icon: const Icon(Icons.refresh_rounded), onPressed: _buscando ? null : _buscar),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('El equipo sólo entra a redes de 2.4 GHz; las de 5 GHz se ven apagadas.', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
            if (_buscando)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (r == null || r.estado != EstadoEscaneo.ok || redes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  r != null && r.estado != EstadoEscaneo.ok ? copiaEscaneo(r.estado) : 'No se vio ninguna red. Acércate al módem y busca de nuevo.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: redes.length,
                  itemBuilder: (_, i) {
                    final red = redes[i];
                    final esActual = red.ssid == widget.actual;
                    return ListTile(
                      enabled: red.sirve,
                      leading: Icon(_iconoSenal(red.barras), color: red.sirve ? cs.primary : cs.outline),
                      title: Text(red.ssid, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        red.sirve ? (esActual ? 'Conectado ahora · ${red.banda.etiqueta}'.trim() : red.banda.etiqueta) : '${red.banda.etiqueta}: el equipo no la ve',
                      ),
                      trailing: esActual ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
                      onTap: red.sirve ? () => Navigator.pop(context, red) : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconoSenal(int barras) => switch (barras) {
    4 => Icons.network_wifi_rounded,
    3 => Icons.network_wifi_3_bar_rounded,
    2 => Icons.network_wifi_2_bar_rounded,
    1 => Icons.network_wifi_1_bar_rounded,
    _ => Icons.wifi_rounded,
  };
}
