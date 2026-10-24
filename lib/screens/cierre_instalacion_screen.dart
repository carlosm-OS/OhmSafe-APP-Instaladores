import 'package:flutter/material.dart';
import '../core/utils/observaciones_cierre.dart';
import 'package:geolocator/geolocator.dart';

import '../core/error/failures.dart';
import '../core/utils/ubicacion.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/hoja_decision.dart';

class CierreInstalacionScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const CierreInstalacionScreen({super.key, required this.ticket});

  @override
  State<CierreInstalacionScreen> createState() => _CierreInstalacionScreenState();
}

class _CierreInstalacionScreenState extends State<CierreInstalacionScreen> {
  int _currentStep = 1;
  bool _isLoading = false;

  /// Envío en curso desde el PRIMER toque (auditoría 2026-10-23: firma y GPS tardan hasta 4 s antes
  /// del overlay y en ese hueco «Terminar» se podía tocar otra vez y mandar el cierre doble).
  bool _enviando = false;

  /// Qué está pasando, para el botón y el overlay (regla de oro).
  String _fase = 'Enviando el cierre…';

  // Reference coordinates for anti-fraud location verification
  // (Centred in Mexico City - Juarez/Roma area, where our mock installer is operating)
  // La validación de ubicación vive en el backend: compara la posición del
  // cierre con la de la llegada (radio de 300 m) y pide confirmación si está lejos.

  // Step 1 State: Photos, Metadatas and Anomaly Justifications
  final List<String> _categories = [
    // Carlos (2026-10-20): «Foto cerca 1 y 2» en vez de «Perfil izquierdo/derecho».
    'Foto cerca 1',
    'Foto cerca 2',
    'Energizador',
    'Letrero OhmSafe',
  ];
  final Map<String, String?> _photoPaths = {};
  final Map<String, Position?> _photoLocations = {};
  final Map<String, DateTime?> _photoTimestamps = {};
  // Ya no se calcula discrepancia por foto en la app (la valida el backend al cerrar); queda vacío.
  final Map<String, bool> _geoMismatches = {};
  final ImagePicker _picker = ImagePicker();

  // Simulated photo list and capture states
  final List<String> _fotosCapturadas = [];
  String? _capturingCategory;

  final _photoCommentsController = TextEditingController();

  /// fileKey que devolvió el backend por cada foto ya subida. Es lo que viaja
  /// en el cierre; la ruta local del teléfono no le sirve al servidor.
  final Map<String, String> _photoFileKeys = {};

  /// Estado de la subida por foto. Se muestra en la tarjeta: sin esto una
  /// foto que falló al subir se veía igual que una subida y el instalador
  /// solo se enteraba al intentar firmar.
  final Map<String, _EstadoSubida> _subidaFotos = {};
  String? _step1Error;

  // Reparación: evidencias fotográficas dinámicas (se agregan una a una).
  // Guardamos ids estables; la etiqueta visible ("Foto N") se calcula por
  // posición, y la clave de almacenamiento por id se mantiene fija.
  final List<int> _repairPhotoSlots = [1];
  int _repairPhotoCounter = 1;

  // Step 2 State: confirmación de entrega del equipo (checks, sin foto/serie).
  bool _controlEntregado = false; // Entregué el control remoto funcional
  // Addons del servicio. null = sin responder; el técnico debe decir si los
  // instaló o si el servicio no los incluye. No se infiere del plan porque
  // hoy el ticket no trae los addons contratados.
  bool _entregaConAnomalias = false; // false = todo funcional; true = hubo anomalías
  bool _anomFisica = false; // Daño físico
  bool _anomFuncionamiento = false; // Falla de funcionamiento
  bool _anomControl = false; // El control remoto no funcionó
  final _step2CommentsController = TextEditingController();
  String? _step2Error;

  // Step 3 State: Signature Canvas
  /// Llave del lienzo: se usa para convertir coordenadas globales a locales
  /// y para conocer su tamaño al rasterizar la firma a PNG.
  final GlobalKey _signatureCanvasKey = GlobalKey();
  List<Offset> _signaturePoints = [];
  bool _signatureConfirmed = false;
  String? _step3Error;

  // ¿Es un cierre de reparación? (por tipo de ticket)
  bool get _isReparacion {
    final type = (widget.ticket["type"] as String?)?.toLowerCase() ?? '';
    return type.contains('reparacion') || type.contains('reparación');
  }

  // En reparación, ReparacionScreen marca si se cambió el energizador.
  bool get _energizadorCambiado => widget.ticket["energizador_cambiado"] == true;

  // El paso "Equipo" (serie del control + evidencia) aplica en instalaciones
  // siempre, y en reparaciones solo si se cambió el energizador.
  bool get _requiereEquipo => !_isReparacion || _energizadorCambiado;

  @override
  void dispose() {
    _photoCommentsController.dispose();
    _step2CommentsController.dispose();
    super.dispose();
  }

  /// Posición real del teléfono o null; nunca una posición inventada.
  Future<Position?> _getCurrentLocation() => ubicacionActual(limite: const Duration(seconds: 4));

  /// Toma o elige una foto de evidencia. Antes esto era una simulación: esperaba
  /// 2 segundos y guardaba la ruta falsa "simulated_path_<categoria>.png", así
  /// que el cierre viajaba sin ninguna evidencia real.
  Future<void> _capturarFoto(String category) async {
    if (_capturingCategory != null) return; // evita capturas concurrentes

    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    setState(() {
      _capturingCategory = category;
      _step1Error = null;
      // Al retomar una foto, su subida anterior deja de ser válida: si no se
      // olvida, el cierre enviaría la referencia de la foto vieja.
      _photoFileKeys.remove(category);
    });

    try {
      final XFile? foto = await _picker.pickImage(source: origen, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
      if (!mounted) return;
      if (foto == null) {
        setState(() => _capturingCategory = null);
        return;
      }

      // La ubicación se sigue registrando aunque no bloquee (ver
      // _validarGeolocalizacion): sirve como dato del cierre.
      final position = await _getCurrentLocation();
      if (!mounted) return;

      setState(() {
        if (!_fotosCapturadas.contains(category)) _fotosCapturadas.add(category);
        _photoPaths[category] = foto.path;
        _photoLocations[category] = position;
        _photoTimestamps[category] = DateTime.now();
      });

      setState(() => _capturingCategory = null);
      // La foto se sube AQUÍ, no al cerrar: en campo la señal es mala y un
      // solo envío con las cuatro fotos hace que un corte tire el cierre
      // completo. Así cada foto es reintentable por separado y el cierre
      // solo manda referencias.
      await _subirFoto(category);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturingCategory = null;
        debugPrint("Cámara del cierre: $e");
        _step1Error = "No se pudo abrir la cámara. Vuelve a intentar; si sigue, reinicia la app.";
      });
    }
  }

  // ----- Evidencias: subida por foto con estado visible y reintento -----

  /// Sube la foto de [category] y deja su estado en `_subidaFotos`.
  /// Reutilizable para reintentar sin volver a tomar la foto.
  Future<void> _subirFoto(String category) async {
    final path = _photoPaths[category];
    if (path == null) return;
    setState(() => _subidaFotos[category] = _EstadoSubida.subiendo);

    final ticketId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    try {
      final bytes = await File(path).readAsBytes();
      final subida = await sl.get<OrdenesRepository>().subirEvidencia(ticketId, category, base64Encode(bytes));
      if (!mounted) return;
      subida.fold(
        (fileKey) => setState(() {
          _photoFileKeys[category] = fileKey;
          _subidaFotos[category] = _EstadoSubida.ok;
        }),
        (_) => setState(() => _subidaFotos[category] = _EstadoSubida.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _subidaFotos[category] = _EstadoSubida.error);
    }
  }

  /// Fotos tomadas que aún no tienen fileKey (fallaron o siguen subiendo).
  List<String> get _fotosSinSubir => _photoPaths.entries.where((e) => e.value != null && !_photoFileKeys.containsKey(e.key)).map((e) => e.key).toList();

  /// Antes de cerrar se reintentan solas las subidas pendientes: el
  /// instalador no debe volver al paso 1 por un corte de red momentáneo.
  Future<void> _reintentarSubidasPendientes() async {
    final pendientes = _fotosSinSubir.where((c) => _subidaFotos[c] != _EstadoSubida.subiendo).toList();
    await Future.wait(pendientes.map(_subirFoto));
  }

  // ----- Firma: captura de trazos y rasterizado -----

  RenderBox? get _signatureBox => _signatureCanvasKey.currentContext?.findRenderObject() as RenderBox?;

  /// Agrega un punto del trazo, en coordenadas locales del lienzo y recortado
  /// a su área (un arrastre puede salirse del recuadro).
  void _agregarTrazo(Offset globalPosition) {
    final box = _signatureBox;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    final clamped = Offset(local.dx.clamp(0.0, size.width), local.dy.clamp(0.0, size.height));
    setState(() {
      _signaturePoints = List.from(_signaturePoints)..add(clamped);
    });
  }

  /// Marca el fin de un trazo (el pincel levanta): el painter no une puntos
  /// separados por este centinela.
  void _terminarTrazo() {
    setState(() {
      _signaturePoints = List.from(_signaturePoints)..add(const Offset(-1, -1));
    });
  }

  /// Rasteriza la firma a PNG (base64, sin prefijo data:).
  ///
  /// No captura la pantalla: redibuja los trazos sobre fondo blanco con tinta
  /// oscura, para que el documento sea legible sin importar el tema de la app
  /// ni el estado visual del lienzo.
  Future<String?> _firmaPngBase64() async {
    final box = _signatureBox;
    if (box == null || _signaturePoints.isEmpty) return null;
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFFFFFFF));
    SignaturePainter(_signaturePoints, const Color(0xFF111111)).paint(canvas, size);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size.width.ceil(), size.height.ceil());
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return null;
        return base64Encode(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  // Submit all details and complete installation
  Future<void> _submitCierreInstalacion({bool confirmarUbicacion = false}) async {
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _fase = 'Revisando las fotos…';
    });
    try {
      await _enviarCierre(confirmarUbicacion: confirmarUbicacion);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarCierre({required bool confirmarUbicacion}) async {
    // Compile JSON Payload
    final Map<String, dynamic> geoJson = {};
    _photoLocations.forEach((category, pos) {
      if (pos != null) {
        geoJson[category] = {"lat": pos.latitude, "lng": pos.longitude, "timestamp": _photoTimestamps[category]?.toIso8601String()};
      }
    });

    final anomalias = <String>[if (_anomFisica) 'daño_fisico', if (_anomFuncionamiento) 'falla_funcionamiento', if (_anomControl) 'control_no_funciona'];

    // Una foto capturada pero no subida no llega a la orden de servicio. Antes
    // de avisar se reintenta la subida: casi siempre fue un corte momentáneo.
    if (_fotosSinSubir.isNotEmpty) {
      setState(() {
        _step3Error = null;
        _fase = 'Subiendo las fotos…';
        _isLoading = true;
      });
      await _reintentarSubidasPendientes();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    final sinSubir = _fotosSinSubir;
    if (sinSubir.isNotEmpty) {
      setState(
        () => _step3Error =
            "No se pudo subir ${sinSubir.length == 1 ? 'la foto' : 'las fotos'} de ${sinSubir.join(', ')}. Revisa la señal y toca «Volver a intentar» en las fotos.",
      );
      return;
    }

    // La firma se rasteriza ANTES de mostrar el overlay de carga: el lienzo
    // debe seguir montado para poder medirlo.
    setState(() => _fase = 'Preparando la firma…');
    final firmaBase64 = await _firmaPngBase64();
    if (!mounted) return;
    setState(() => _fase = 'Tomando tu ubicación…');
    final ubicacionCierre = ubicacionJson(await _getCurrentLocation());
    if (!mounted) return;
    if (firmaBase64 == null) {
      setState(() => _step3Error = "No se pudo capturar la firma. Pide al cliente que firme de nuevo.");
      return;
    }

    // Las claves deben coincidir con el esquema del backend (camelCase). Con
    // snake_case, Zod las descartaba en silencio y el cierre se guardaba vacío.
    final payload = {
      "evidencias": [
        for (final entry in _photoFileKeys.entries) {"fileKey": entry.value, "categoria": entry.key},
      ],
      "geolocalizacion": geoJson,
      "entregaEquipo": {
        "controlRemotoEntregado": _controlEntregado,
        "entregaFuncional": !_entregaConAnomalias,
        "anomalias": anomalias,
        "comentarios": _step2CommentsController.text.trim(),
      },
      "firmaBase64": firmaBase64,
      // Posición al cerrar: el backend la compara con la de la llegada.
      if (ubicacionCierre != null) "ubicacion": ubicacionCierre,
      if (confirmarUbicacion) "confirmarUbicacion": true,
      "comentariosGenerales": observacionesCierre(paso1: _photoCommentsController.text, paso2: _step2CommentsController.text),
    };

    // Enviar al backend vía repositorio (Mock o Api según EnvConfig.useMock).
    setState(() {
      _step3Error = null;
      _fase = 'Enviando el cierre…';
      _isLoading = true;
    });
    final repo = sl.get<OrdenesRepository>();
    final ticketId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final result = await repo.guardarCierre(ticketId, payload);
    if (!mounted) return;
    result.fold((_) => Navigator.pop(context, 'cierre_completed'), (failure) {
      setState(() => _isLoading = false);
      if (failure is ServerFailure && failure.code == 'FUERA_DE_SITIO') {
        _confirmarCierreLejos(failure);
        return;
      }
      // Un solo aviso, junto al botón (antes también salía repetido abajo).
      setState(() => _step3Error = "No se envió el cierre. Tus fotos y la firma siguen guardadas: revisa la señal y vuelve a intentar.");
    });
  }

  /// El backend detectó que el cierre está a más de 300 m de la llegada. El
  /// instalador puede confirmar; la confirmación queda en el chatter de Odoo.
  /// v2 (2026-10-23): es una decisión, así que va en hoja desde abajo y no en un diálogo al centro.
  Future<void> _confirmarCierreLejos(ServerFailure failure) async {
    final distancia = failure.details['distanciaM'];
    final confirmar = await mostrarHojaDecision(
      context,
      titulo: '¿Cerrar lejos del domicilio?',
      texto: distancia != null
          ? 'Estás a $distancia m de donde marcaste la llegada. Si de verdad estás en el domicilio del cliente, cierra aquí; queda anotado que lo confirmaste.'
          : failure.message,
      seguir: 'Cerrar aquí',
      salir: 'Revisar antes de cerrar',
    );
    if (confirmar == true && mounted) await _submitCierreInstalacion(confirmarUbicacion: true);
  }

  // ----- Reparación: manejo de fotos de evidencia dinámicas -----
  String _repairKey(int id) => 'Reparación foto $id';

  // Solo se puede agregar otra foto cuando todas las actuales ya se tomaron.
  bool get _canAddRepairPhoto => _repairPhotoSlots.every((id) => _fotosCapturadas.contains(_repairKey(id)));

  void _addRepairPhotoSlot() {
    setState(() {
      _repairPhotoCounter++;
      _repairPhotoSlots.add(_repairPhotoCounter);
    });
  }

  /// Quita una foto de reparación y ofrece «Deshacer» (v2, 2026-10-23: el SnackBar sólo confirma).
  /// También olvida su subida: si no, la foto quitada seguía viajando en el cierre.
  void _removeRepairPhotoSlot(int id) {
    final key = _repairKey(id);
    final posicion = _repairPhotoSlots.indexOf(id);
    final path = _photoPaths[key];
    final location = _photoLocations[key];
    final timestamp = _photoTimestamps[key];
    final mismatch = _geoMismatches[key];
    final capturada = _fotosCapturadas.contains(key);
    final fileKey = _photoFileKeys[key];
    final subida = _subidaFotos[key];
    setState(() {
      _repairPhotoSlots.remove(id);
      _photoPaths.remove(key);
      _photoLocations.remove(key);
      _photoTimestamps.remove(key);
      _geoMismatches.remove(key);
      _fotosCapturadas.remove(key);
      _photoFileKeys.remove(key);
      _subidaFotos.remove(key);
    });

    void deshacer() {
      if (!mounted || _repairPhotoSlots.contains(id)) return;
      setState(() {
        _repairPhotoSlots.insert(posicion.clamp(0, _repairPhotoSlots.length), id);
        if (path != null) _photoPaths[key] = path;
        if (location != null) _photoLocations[key] = location;
        if (timestamp != null) _photoTimestamps[key] = timestamp;
        if (mismatch != null) _geoMismatches[key] = mismatch;
        if (capturada) _fotosCapturadas.add(key);
        if (fileKey != null) _photoFileKeys[key] = fileKey;
        if (subida != null) _subidaFotos[key] = subida;
      });
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Foto quitada.'),
        action: SnackBarAction(label: 'Deshacer', onPressed: deshacer),
      ),
    );
  }

  // ¿Están cubiertas las evidencias fotográficas del paso 1?
  bool _evidenciasCompletas() {
    if (_isReparacion) {
      // Al menos una foto y sin slots vacíos.
      if (_repairPhotoSlots.isEmpty) return false;
      for (final id in _repairPhotoSlots) {
        if (!_fotosCapturadas.contains(_repairKey(id))) return false;
      }
      return true;
    }
    for (String cat in _categories) {
      if (!_fotosCapturadas.contains(cat)) return false;
    }
    return true;
  }

  // Validate Step 1
  bool _validateStep1() {
    if (!_evidenciasCompletas()) return false;
    return true;
  }

  // Validate Step 2 (entrega de equipo por confirmación, sin foto/serie)
  bool _validateStep2() {
    // En reparación sin cambio de energizador no aplica el paso de equipo.
    if (!_requiereEquipo) return true;

    // Debe confirmar la entrega del control remoto funcional.
    if (!_controlEntregado) return false;

    // Si reporta anomalías, debe marcar al menos un tipo o describirlas.
    if (_entregaConAnomalias) {
      final algunaAnom = _anomFisica || _anomFuncionamiento || _anomControl;
      if (!algunaAnom && _step2CommentsController.text.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// Lo que falta para poder terminar, en palabras del instalador.
  List<String> _faltantesCierre() => [
    if (!_evidenciasCompletas()) 'las fotos',
    if (!_validateStep2()) 'la entrega',
    if (_signaturePoints.isEmpty) 'la firma del cliente' else if (!_signatureConfirmed) 'tocar «Confirmar firma»',
  ];

  // Helper to validate all conditions for the final submit button
  bool _canSubmitCierre() {
    // a) Las evidencias fotográficas estén completas (4 categorías en
    //    instalación, o al menos una foto de reparación sin slots vacíos).
    if (!_evidenciasCompletas()) {
      return false;
    }
    // b) La firma haya sido capturada (valida que no esté vacía).
    if (!_signatureConfirmed || _signaturePoints.isEmpty) {
      return false;
    }
    // c) La confirmación de entrega de equipo esté completa (cuando aplica).
    if (!_validateStep2()) {
      return false;
    }
    return true;
  }

  void _nextStep() {
    setState(() {
      _step1Error = null;
      _step2Error = null;
    });

    if (_currentStep == 1) {
      if (!_validateStep1()) {
        setState(() {
          _step1Error = _isReparacion ? "Falta al menos una foto de la reparación (o hay un espacio sin foto)." : "Faltan fotos: toma las 4 para seguir.";
        });
        return;
      }
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      if (!_validateStep2()) {
        setState(() {
          _step2Error = !_controlEntregado ? "Falta confirmar la entrega del control remoto." : "Marca qué pasó o descríbelo abajo.";
        });
        return;
      }
      setState(() {
        _currentStep = 3;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  /// La flecha y el atrás del teléfono hacen lo mismo (auditoría 2026-10-23: el del teléfono cerraba
  /// todo el cierre y se perdían fotos, entrega y firma): regresan un subpaso y, en el primero,
  /// preguntan antes de soltar las fotos.
  Future<void> _regresar() async {
    if (_enviando) return;
    if (_currentStep > 1) {
      _prevStep();
      return;
    }
    if (_photoFileKeys.isEmpty && _signaturePoints.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final seguir = await mostrarHojaDecision(
      context,
      titulo: '¿Salir del cierre?',
      texto: 'Las fotos que tomaste no se guardan en este teléfono: al volver tendrás que tomarlas otra vez.',
      seguir: 'Seguir con el cierre',
      salir: 'Salir del cierre',
      pierde: true,
    );
    if (seguir == false && mounted) Navigator.pop(context);
  }

  /// Título grande del subpaso actual (v2: el encabezado dice dónde estás, no el nombre de la sección).
  String get _tituloSubpaso {
    switch (_currentStep) {
      case 1:
        return _isReparacion ? 'Fotos de la reparación' : 'Fotos de la instalación';
      case 2:
        return _requiereEquipo ? 'Entrega al cliente' : 'Entrega del equipo';
      default:
        return 'Firma del cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _regresar();
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
                  // v2 (2026-10-23): encabezado único, sin logo ni título hecho a mano.
                  EncabezadoFlujo(titulo: _tituloSubpaso, subtitulo: 'Cierre · paso $_currentStep de 3', alVolver: _regresar),
                  _buildAvance(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 1)
                            _buildStep1Evidence()
                          else if (_currentStep == 2)
                            _buildStep2Equipment()
                          else if (_currentStep == 3)
                            _buildStep3Signature(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sending loading overlay
            if (_isLoading) _buildLoadingOverlay(context),
          ],
        ),
      ),
    );
  }

  /// Avance de los 3 subpasos (v2, como la barra de «Pasos»): hecho en verde, el actual en el
  /// naranja de la marca y lo que falta en gris.
  Widget _buildAvance() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const nombres = ['Fotos', 'Entrega', 'Firma'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          for (var i = 0; i < nombres.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.of(context, AppDurations.base),
                    curve: AppCurves.standard,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentStep == i + 1 ? cs.primary : (_currentStep > i + 1 ? context.ohm.success : cs.outlineVariant),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nombres[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _currentStep == i + 1 ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: _currentStep == i + 1 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Error del subpaso, junto al botón (v2): qué pasó y cómo arreglarlo.
  Widget _errorJuntoAlBoton(String mensaje) {
    return Semantics(
      liveRegion: true,
      child: MensajeFlujo(icono: Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, titulo: mensaje),
    );
  }

  /// Botón principal arriba y «Atrás» gris abajo (v2: arriba seguir, abajo salir).
  Widget _navegacion(Widget principal, {Widget? debajo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        principal,
        if (debajo != null) ...[const SizedBox(height: 12), debajo],
        const SizedBox(height: 12),
        // Mientras envía no se regresa: la firma se mide en su lienzo y debe seguir montado.
        BotonSecundario(etiqueta: 'Atrás', onPressed: _enviando ? null : _prevStep),
      ],
    );
  }

  // STEP 1 CONTENT: Evidence photos & anomaly justification
  Widget _buildStep1Evidence() {
    bool anyGeoMismatch = _geoMismatches.values.contains(true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EtiquetaSeccion(
          _isReparacion ? 'Fotos de la reparación' : 'Fotos obligatorias',
          tituloAyuda: _isReparacion ? 'Fotos de la reparación' : 'Qué debe verse en cada foto',
          ayuda: _isReparacion
              ? const [
                  'Toma al menos una foto del trabajo terminado.',
                  'Si necesitas más, toca «Agregar foto».',
                  'Cada foto guarda la ubicación donde la tomaste.',
                ]
              : const [
                  'Foto cerca 1 y 2: la cerca vista desde cada extremo, completa.',
                  'Energizador: el equipo ya instalado, con sus cables.',
                  'Letrero OhmSafe: el letrero de advertencia colocado.',
                  'Tómalas en el domicilio: cada foto guarda su ubicación.',
                ],
        ),

        // Fotos: en reparación, lista dinámica que se agrega una a una;
        // en instalación, las 4 categorías fijas. Todas en un solo grupo (v2).
        GrupoFilas(
          pie: _isReparacion
              ? (_canAddRepairPhoto
                    ? 'Toma al menos una foto del trabajo. Cada foto guarda su ubicación.'
                    : 'Toma la foto que falta para poder agregar otra. Cada foto guarda su ubicación.')
              : 'Toma las 4 fotos en el domicilio. Cada foto guarda su ubicación.',
          children: _isReparacion
              ? [..._repairPhotoSlots.asMap().entries.map((e) => _buildRepairPhotoCard(e.value, e.key)), _buildAddRepairPhotoButton()]
              : _categories.map(_buildPhotoCategoryCard).toList(),
        ),

        // Aviso de ubicación: hoy la valida el backend al cerrar, así que casi nunca aparece.
        if (anyGeoMismatch)
          MensajeFlujo(
            icono: Icons.gps_off_rounded,
            color: context.ohm.warning,
            titulo: 'Una foto no se tomó en el domicilio',
            texto: 'Explica abajo por qué (por ejemplo, no había señal de GPS).',
          ),

        // Anomaly Justification TextField
        EtiquetaSeccion(anyGeoMismatch ? '¿Por qué no coincide la ubicación?' : 'Comentarios (opcional)'),
        TextField(
          controller: _photoCommentsController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: anyGeoMismatch ? 'Ej. no había señal de GPS, la barda da a otra calle…' : 'Algo que operaciones deba saber de esta instalación',
          ),
        ),

        const SizedBox(height: 32),
        if (_step1Error != null) _errorJuntoAlBoton(_step1Error!),
        OhmGradientButton(label: 'Siguiente: entrega', icon: Icons.arrow_forward_rounded, onPressed: _nextStep),
      ],
    );
  }

  /// Estado de la subida de la foto, como punto y palabra (v2). En error, la acción de la fila es
  /// «Volver a intentar» (sube otra vez sin volver a tomar la foto).
  Widget _estadoFoto(String category) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mismatch = _geoMismatches[category] ?? false;
    final Widget estado;
    switch (_subidaFotos[category]) {
      case _EstadoSubida.subiendo:
        estado = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: cs.onSurfaceVariant)),
            const SizedBox(width: 6),
            Text('Subiendo…', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );
      case _EstadoSubida.ok:
        estado = EstadoPunto('Subida', color: context.ohm.success);
      case _EstadoSubida.error:
        estado = EstadoPunto('No se subió', color: cs.error);
      case null:
        estado = EstadoPunto(_photoPaths[category] == null ? 'Falta tomarla' : 'Tomada', color: cs.outline);
    }
    if (!mismatch) return estado;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        estado,
        EstadoPunto('Lejos del domicilio', color: context.ohm.warning),
      ],
    );
  }

  /// Miniatura de la foto (o la cámara si falta), 44 × 44 con radio 9 como los íconos de fila v2.
  Widget _miniatura(String? path) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 44,
        height: 44,
        color: cs.surfaceContainerHighest,
        // Ahora que la foto es real, se muestra: es la evidencia que
        // el instalador acaba de tomar, no un palomeo.
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                errorBuilder: (_, _, _) => Icon(Icons.image_rounded, color: cs.onSurfaceVariant, size: 22),
              )
            : Icon(Icons.photo_camera_rounded, color: cs.onSurfaceVariant, size: 22),
      ),
    );
  }

  /// Acción de la fila de una foto: tomarla, volver a subirla o tomar otra.
  Widget _accionFoto(String category) {
    final cs = Theme.of(context).colorScheme;
    if (_capturingCategory == category) {
      return SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant)),
        ),
      );
    }
    if (_subidaFotos[category] == _EstadoSubida.error) {
      return BotonFila(etiqueta: 'Volver a intentar', onPressed: () => _subirFoto(category));
    }
    final ocupado = _capturingCategory != null || _subidaFotos[category] == _EstadoSubida.subiendo;
    final hasPhoto = _photoPaths[category] != null;
    return BotonFila(
      etiqueta: hasPhoto ? 'Tomar otra' : 'Tomar foto',
      icono: hasPhoto ? null : Icons.add_a_photo_rounded,
      onPressed: ocupado ? null : () => _capturarFoto(category),
    );
  }

  /// Fila de foto dentro del grupo: miniatura, nombre, estado y acción.
  Widget _filaFoto({required String titulo, required String category, List<Widget> extra = const []}) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          _miniatura(_photoPaths[category]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                _estadoFoto(category),
              ],
            ),
          ),
          ...extra,
          _accionFoto(category),
        ],
      ),
    );
  }

  Widget _buildPhotoCategoryCard(String category) => _filaFoto(titulo: category, category: category);

  // Fila de una foto de evidencia de reparación (etiqueta "Foto N" por
  // posición; datos guardados con clave estable por id). Permite reemplazar
  // la foto y quitar la fila si hay más de una (con «Deshacer»).
  Widget _buildRepairPhotoCard(int id, int index) {
    final cs = Theme.of(context).colorScheme;
    final key = _repairKey(id);
    final ocupada = _capturingCategory == key || _subidaFotos[key] == _EstadoSubida.subiendo;
    return _filaFoto(
      titulo: 'Foto ${index + 1}',
      category: key,
      extra: [
        if (_repairPhotoSlots.length > 1)
          IconButton(
            tooltip: 'Quitar foto ${index + 1}',
            onPressed: ocupada ? null : () => _removeRepairPhotoSlot(id),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  // Fila "Agregar foto": habilitada solo cuando todas las fotos actuales
  // ya se tomaron (flujo de una en una).
  Widget _buildAddRepairPhotoButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = _canAddRepairPhoto;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? _addRepairPhotoSlot : null,
        child: AnimatedOpacity(
          duration: AppMotion.of(context, AppDurations.base),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Text('Agregar foto', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // STEP 2 CONTENT: confirmación de entrega de equipo (checks, sin foto/serie)
  Widget _buildStep2Equipment() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Reparación sin cambio de energizador: no hay equipo que entregar.
    if (!_requiereEquipo) {
      return _buildStep2SinEquipo();
    }

    Widget opcion(String titulo, bool elegida, VoidCallback alElegir) => FilaFlujo(
      titulo: titulo,
      onTap: alElegir,
      trailing: elegida ? Icon(Icons.check_rounded, color: cs.primary, size: 22) : const SizedBox(width: 22),
    );

    Widget anomalia(String titulo, bool valor, ValueChanged<bool> cambiar) => FilaFlujo(
      titulo: titulo,
      leading: CirculoCheck(marcado: valor),
      onTap: () => cambiar(!valor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Confirma lo que le dejaste funcionando al cliente.', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),

        // Cámaras, sensores y sirena ya no se contestan a mano (Carlos, 2026-10-20, caso i76): el reporte
        // lista lo que se registró en «Agregar dispositivos», con los datos del servidor.
        GrupoFilas(
          pie: 'El reporte del cliente lista sólo lo que registraste en «Agregar dispositivos» (energizador, sensores, sirena, salidas y cámaras).',
          children: [
            FilaFlujo(
              titulo: 'Le entregué el control remoto y funciona',
              onTap: () => setState(() {
                _controlEntregado = !_controlEntregado;
                _step2Error = null;
              }),
              trailing: Switch.adaptive(
                value: _controlEntregado,
                onChanged: (v) => setState(() {
                  _controlEntregado = v;
                  _step2Error = null;
                }),
              ),
            ),
          ],
        ),

        // Estado de la entrega
        const EtiquetaSeccion('¿Cómo quedó todo?'),
        GrupoFilas(
          children: [
            opcion(
              'Todo funciona',
              !_entregaConAnomalias,
              () => setState(() {
                _entregaConAnomalias = false;
                _step2Error = null;
              }),
            ),
            opcion(
              'Con problemas',
              _entregaConAnomalias,
              () => setState(() {
                _entregaConAnomalias = true;
                _step2Error = null;
              }),
            ),
          ],
        ),

        // Si hubo anomalías: tipos + descripción
        if (_entregaConAnomalias) ...[
          const EtiquetaSeccion('¿Qué pasó?'),
          GrupoFilas(
            children: [
              anomalia(
                'El equipo está dañado',
                _anomFisica,
                (v) => setState(() {
                  _anomFisica = v;
                  _step2Error = null;
                }),
              ),
              anomalia(
                'Algo no funciona',
                _anomFuncionamiento,
                (v) => setState(() {
                  _anomFuncionamiento = v;
                  _step2Error = null;
                }),
              ),
              anomalia(
                'El control remoto no funcionó',
                _anomControl,
                (v) => setState(() {
                  _anomControl = v;
                  _step2Error = null;
                }),
              ),
            ],
          ),
          const EtiquetaSeccion('Cuéntanos qué pasó'),
          TextField(
            controller: _step2CommentsController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _step2Error = null),
            decoration: const InputDecoration(hintText: 'Obligatorio si no marcaste nada arriba'),
          ),
        ],

        const SizedBox(height: 32),
        if (_step2Error != null) _errorJuntoAlBoton(_step2Error!),
        _navegacion(OhmGradientButton(label: 'Siguiente: firma', icon: Icons.arrow_forward_rounded, onPressed: _nextStep)),
      ],
    );
  }

  // STEP 2 (variante): reparación sin cambio de energizador.
  Widget _buildStep2SinEquipo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MensajeFlujo(
          icono: Icons.info_outline_rounded,
          color: context.ohm.info,
          titulo: 'Sin cambio de energizador',
          texto: 'No cambiaste el energizador: no hace falta serie ni foto del equipo.',
        ),

        // Comentarios opcionales del equipo (no obligatorio)
        const SizedBox(height: 12),
        const EtiquetaSeccion('Comentarios del equipo (opcional)'),
        TextField(
          controller: _step2CommentsController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Observaciones sobre el equipo que ya estaba (opcional)…'),
        ),

        const SizedBox(height: 32),
        _navegacion(OhmGradientButton(label: 'Siguiente: firma', icon: Icons.arrow_forward_rounded, onPressed: _nextStep)),
      ],
    );
  }

  // STEP 3 CONTENT: Signature and termination
  Widget _buildStep3Signature() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;

    // Un solo botón naranja a la vez (v2): primero «Confirmar firma» y, ya confirmada, «Terminar».
    final principal = _signatureConfirmed
        ? OhmGradientButton(
            label: _isReparacion ? 'Terminar reparación' : 'Terminar instalación',
            icon: Icons.check_circle_rounded,
            loading: _enviando,
            loadingLabel: _fase,
            onPressed: _canSubmitCierre() ? _submitCierreInstalacion : null,
          )
        : OhmGradientButton(
            label: 'Confirmar firma',
            icon: Icons.check_rounded,
            onPressed: _signaturePoints.isNotEmpty ? () => setState(() => _signatureConfirmed = true) : null,
          );
    final principalApagado = _signatureConfirmed ? !_canSubmitCierre() : _signaturePoints.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            'Pide al cliente que firme con el dedo para confirmar que recibió el servicio. Luego toca «Confirmar firma».',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),

        // Interactive Signature Canvas Box
        Stack(
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  // Borde con contraste para que el recuadro se vea en exteriores (lienzo de Carlos, 2026-10-15).
                  color: _signatureConfirmed ? ohm.success : cs.outline,
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                // El lienzo compite con el SingleChildScrollView que lo contiene:
                // un GestureDetector normal pierde el arrastre vertical contra el
                // scroll y la firma sale entrecortada (solo trazos horizontales).
                // Por eso usamos un reconocedor que reclama el puntero al tocar.
                child: RawGestureDetector(
                  key: _signatureCanvasKey,
                  behavior: HitTestBehavior.opaque,
                  gestures: _signatureConfirmed
                      ? const <Type, GestureRecognizerFactory>{}
                      : <Type, GestureRecognizerFactory>{
                          _FirmaPanRecognizer: GestureRecognizerFactoryWithHandlers<_FirmaPanRecognizer>(() => _FirmaPanRecognizer(), (_FirmaPanRecognizer r) {
                            r.dragStartBehavior = DragStartBehavior.down;
                            r.onStart = (d) => _agregarTrazo(d.globalPosition);
                            r.onUpdate = (d) => _agregarTrazo(d.globalPosition);
                            r.onEnd = (_) => _terminarTrazo();
                          }),
                        },
                  // Tinta del tema: oscura en claro y clara en oscuro; verde ya confirmada.
                  child: CustomPaint(painter: SignaturePainter(_signaturePoints, _signatureConfirmed ? ohm.success : cs.onSurface), size: Size.infinite),
                ),
              ),
            ),

            // Indicación dentro del recuadro vacío (no captura toques).
            if (!_signatureConfirmed && _signaturePoints.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_rounded, size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('Firma aquí con el dedo', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Firma guardada: aviso plano, sin sombra (v2).
            if (_signatureConfirmed)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(color: ohm.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: ohm.success, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, color: ohm.onSuccess, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Firma guardada',
                                style: theme.textTheme.bodyMedium?.copyWith(color: ohm.onSuccess, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Acción del lienzo: borrar antes de confirmar o volver a firmar después.
        Align(
          alignment: Alignment.centerRight,
          child: _signatureConfirmed
              ? BotonFila(
                  etiqueta: 'Volver a firmar',
                  icono: Icons.lock_open_rounded,
                  onPressed: _enviando ? null : () => setState(() => _signatureConfirmed = false),
                )
              : BotonFila(
                  etiqueta: 'Borrar firma',
                  icono: Icons.backspace_rounded,
                  onPressed: _signaturePoints.isEmpty ? null : () => setState(() => _signaturePoints.clear()),
                ),
        ),

        const SizedBox(height: 24),
        if (_step3Error != null) _errorJuntoAlBoton(_step3Error!),
        // Debajo del botón apagado, por qué sigue apagado (sin adivinar).
        _navegacion(principal, debajo: principalApagado ? FaltaParaSeguir(_faltantesCierre()) : null),
      ],
    );
  }

  // Sending data overlay (v2: tarjeta plana de radio 14, sin sombra dura).
  Widget _buildLoadingOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: cs.scrim.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14)),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: cs.primary, strokeWidth: 3),
                const SizedBox(height: 20),
                Text(_fase, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'No cierres la app; tarda menos de un minuto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter to capture and draw the signature strokes
class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  SignaturePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != const Offset(-1, -1) && points[i + 1] != const Offset(-1, -1)) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}

/// Reconocedor de arrastre para el lienzo de firma.
///
/// Reclama el puntero en cuanto el dedo toca ([GestureDisposition.accepted]),
/// de modo que el `SingleChildScrollView` que envuelve el formulario no le
/// robe el arrastre vertical. Sin esto, firmar mueve la pantalla en lugar de
/// dibujar y el instalador no puede confirmar el cierre.
class _FirmaPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Estado de la subida de una foto de evidencia.
enum _EstadoSubida { subiendo, ok, error }
