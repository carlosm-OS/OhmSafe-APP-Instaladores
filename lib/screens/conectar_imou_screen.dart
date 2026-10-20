import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/utils/etiqueta_ezviz.dart';
import '../core/utils/etiqueta_imou.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import 'escanear_serie_screen.dart';

/// «Conectar cámara Imou» y «Cámara ya conectada» (2026-10-19, Carlos: «todo desde Installer; si
/// puedo escanear el QR, mejor; los modales se comen los campos con el teclado»).
///
/// Pantalla completa en vez de diálogo: el QR de la etiqueta llena serie y código, los campos se
/// desplazan con el teclado y el botón queda abajo. Hoy registra la cámara en la casa (serie +
/// código SC); el paso de pasarle la Wi‑Fi desde la app llega con el SDK de Imou (build 51).
/// Con [proveedor] `imou` la marca va fija; sin proveedor, el backend prueba cada nube.
/// Devuelve (pop) `true` si la cámara quedó registrada.
class ConectarImouScreen extends StatefulWidget {
  const ConectarImouScreen({super.key, required this.ordenId, this.proveedor, this.repo});
  final String ordenId;

  /// `imou` para la fila «Conectar cámara Imou»; null para «Cámara ya conectada» (cualquier marca).
  final String? proveedor;
  final OrdenesRepository? repo;

  @override
  State<ConectarImouScreen> createState() => _ConectarImouScreenState();
}

class _ConectarImouScreenState extends State<ConectarImouScreen> {
  late final OrdenesRepository _repo = widget.repo ?? sl.get<OrdenesRepository>();
  final _serie = TextEditingController();
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  bool _ocupado = false;
  String? _error;

  bool get _imou => widget.proveedor == 'imou';

  @override
  void dispose() {
    for (final c in [_serie, _codigo, _nombre]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _completo => _serie.text.trim().isNotEmpty && _codigo.text.trim().isNotEmpty && _nombre.text.trim().isNotEmpty;

  /// El QR de la guía rápida de Imou (o la etiqueta EZVIZ si la fila es la genérica).
  Future<void> _escanear() async {
    final crudo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EscanearSerieScreen(
          leer: (t) => (EtiquetaImou.leer(t) ?? (_imou ? null : EtiquetaEzviz.leer(t))) == null ? '' : t,
          indicacion: 'Apunta al código QR de la guía o de la etiqueta de la cámara',
        ),
      ),
    );
    if (crudo == null || !mounted) return;
    final i = EtiquetaImou.leer(crudo);
    if (i != null) {
      setState(() {
        _serie.text = i.serie;
        if (i.codigo.isNotEmpty) _codigo.text = i.codigo;
        if (_nombre.text.isEmpty && i.modelo != null) _nombre.text = 'Cámara ${i.modelo}';
      });
      return;
    }
    final e = _imou ? null : EtiquetaEzviz.leer(crudo);
    if (e == null) return;
    setState(() {
      _serie.text = e.serie;
      if (e.codigo.isNotEmpty) _codigo.text = e.codigo;
    });
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final nombre = _nombre.text.trim();
    final r = await _repo.camaraAgregar(widget.ordenId, proveedor: widget.proveedor, serie: _serie.text.trim(), codigo: _codigo.text.trim(), nombre: nombre);
    if (!mounted) return;
    r.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cámara «$nombre» guardada')));
        Navigator.pop(context, true);
      },
      (f) => setState(() {
        _ocupado = false;
        _error = _explicar(f.message);
      }),
    );
  }

  /// Los códigos de Imou dicen poco al instalador; aquí se traducen a qué hacer.
  static String _explicar(String msg) {
    if (msg.contains('DV1002')) {
      return 'Imou todavía no ve esta cámara en internet: no se ha conectado a la Wi‑Fi (la luz sigue parpadeando) o la serie está mal escrita.';
    }
    if (msg.contains('DV1001')) {
      return 'Esta cámara está ligada a otra cuenta de Imou. Hay que quitarla de esa app (o restablecerla de fábrica) y volver a intentar.';
    }
    if (msg.contains('DV1005') || msg.contains('DV1016') || msg.contains('DV1025') || msg.contains('VENDOR_CODE_INVALID')) {
      return 'El código de seguridad no coincide. Revisa mayúsculas y minúsculas: es el «SAFETY CODE» de la etiqueta, tal cual.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titulo = _imou ? 'Conectar cámara Imou' : 'Cámara ya conectada';
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoFlujo(titulo: titulo, alVolver: () => Navigator.pop(context, false)),
            Expanded(
              // Formulario corto: se construye entero (no perezoso) para que el teclado sólo lo desplace.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo registrar la cámara', texto: _error!),
                    if (_imou) ...[
                      const EtiquetaSeccion(
                        'ANTES DE EMPEZAR',
                        tituloAyuda: 'Cómo preparar la cámara Imou',
                        ayuda: [
                          'Sólo para una cámara Imou que YA está en internet (luz verde fija), por ejemplo porque quedó conectada en un intento anterior.',
                          'Si la cámara es nueva o la luz parpadea, vuelve y usa «Conectar cámara Imou»: el teléfono le pasa la Wi‑Fi de la casa.',
                        ],
                      ),
                      TarjetaFlujo(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _Punto('1', 'Cámara enchufada y en internet (luz verde fija).'),
                            _Punto('2', 'Escanea el QR de la guía rápida: llena la serie y el código.'),
                            _Punto('3', 'Ponle nombre y toca «Registrar la cámara».'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const EtiquetaSeccion(
                        'ANTES DE EMPEZAR',
                        tituloAyuda: 'Cámara que ya está en internet',
                        ayuda: ['Para una cámara conectada con la app del fabricante. Escanea su etiqueta o escribe la serie y el código.'],
                      ),
                    EtiquetaSeccion(
                      'LA CÁMARA',
                      tituloAyuda: 'Etiqueta de la cámara',
                      ayuda: [
                        _imou
                            ? 'Serie (S/N) de 15 caracteres y «SAFETY CODE» (SC) de 8: están en la guía rápida y en la caja.'
                            : 'Serie (S/N) y código de verificación: están en la etiqueta de la cámara o de la caja.',
                        'Escanea el QR y se llenan solos.',
                      ],
                    ),
                    TextField(
                      controller: _serie,
                      enabled: !_ocupado,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Número de serie',
                        helperText: 'En la etiqueta, como S/N.',
                        suffixIcon: IconButton(
                          tooltip: 'Escanear etiqueta',
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: _ocupado ? null : _escanear,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codigo,
                      enabled: !_ocupado,
                      // El SC de Imou distingue mayúsculas y minúsculas («L2VqC2QF»); el de EZVIZ va en mayúsculas.
                      textCapitalization: _imou ? TextCapitalization.none : TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: _imou ? 'Código de seguridad (SC)' : 'Código de verificación',
                        helperText: _imou ? 'Tal cual, con mayúsculas y minúsculas.' : 'En la misma etiqueta.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nombre,
                      enabled: !_ocupado,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _completo && !_ocupado ? _registrar() : null,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Cochera', counterText: ''),
                    ),
                    const SizedBox(height: 24),
                    OhmGradientButton(
                      label: _error == null ? 'Registrar la cámara' : 'Volver a intentar',
                      icon: Icons.videocam_outlined,
                      loading: _ocupado,
                      onPressed: _ocupado || !_completo ? null : _registrar,
                    ),
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

class _Punto extends StatelessWidget {
  const _Punto(this.n, this.texto);
  final String n;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Text(
              n,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35))),
        ],
      ),
    );
  }
}
