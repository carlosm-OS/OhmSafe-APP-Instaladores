import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';
import 'package:geolocator/geolocator.dart';

import '../core/error/failures.dart';
import '../core/utils/ubicacion.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';

class CierreInstalacionScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const CierreInstalacionScreen({super.key, required this.ticket});

  @override
  State<CierreInstalacionScreen> createState() => _CierreInstalacionScreenState();
}

class _CierreInstalacionScreenState extends State<CierreInstalacionScreen> {
  int _currentStep = 1;
  bool _isLoading = false;

  // Reference coordinates for anti-fraud location verification
  // (Centred in Mexico City - Juarez/Roma area, where our mock installer is operating)
  // La validación de ubicación vive en el backend: compara la posición del
  // cierre con la de la llegada (radio de 300 m) y pide confirmación si está lejos.

  // Step 1 State: Photos, Metadatas and Anomaly Justifications
  final List<String> _categories = [
    'Perfil izquierdo',
    'Perfil derecho',
    'Energizador',
    'Letrero OhmSafe'
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
  bool _controlEntregado = false;        // Entregué el control remoto funcional
  // Addons del servicio. null = sin responder; el técnico debe decir si los
  // instaló o si el servicio no los incluye. No se infiere del plan porque
  // hoy el ticket no trae los addons contratados.
  String? _camaras;                      // 'instaladas' | 'no_aplica'
  String? _sensores;                     // 'instaladas' | 'no_aplica'
  bool _entregaConAnomalias = false;     // false = todo funcional; true = hubo anomalías
  bool _anomFisica = false;              // Daño físico
  bool _anomFuncionamiento = false;      // Falla de funcionamiento
  bool _anomControl = false;             // El control remoto no funcionó
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
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
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
      final XFile? foto = await _picker.pickImage(
        source: origen,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
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
        _step1Error = "No se pudo tomar la foto: $e";
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

    final ticketId =
        (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    try {
      final bytes = await File(path).readAsBytes();
      final subida = await sl
          .get<OrdenesRepository>()
          .subirEvidencia(ticketId, category, base64Encode(bytes));
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
  List<String> get _fotosSinSubir => _photoPaths.entries
      .where((e) => e.value != null && !_photoFileKeys.containsKey(e.key))
      .map((e) => e.key)
      .toList();

  /// Antes de cerrar se reintentan solas las subidas pendientes: el
  /// instalador no debe volver al paso 1 por un corte de red momentáneo.
  Future<void> _reintentarSubidasPendientes() async {
    final pendientes = _fotosSinSubir
        .where((c) => _subidaFotos[c] != _EstadoSubida.subiendo)
        .toList();
    await Future.wait(pendientes.map(_subirFoto));
  }

  // ----- Firma: captura de trazos y rasterizado -----

  RenderBox? get _signatureBox =>
      _signatureCanvasKey.currentContext?.findRenderObject() as RenderBox?;

  /// Agrega un punto del trazo, en coordenadas locales del lienzo y recortado
  /// a su área (un arrastre puede salirse del recuadro).
  void _agregarTrazo(Offset globalPosition) {
    final box = _signatureBox;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    final clamped = Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
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
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
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
    // Compile JSON Payload
    final Map<String, dynamic> geoJson = {};
    _photoLocations.forEach((category, pos) {
      if (pos != null) {
        geoJson[category] = {
          "lat": pos.latitude,
          "lng": pos.longitude,
          "timestamp": _photoTimestamps[category]?.toIso8601String(),
        };
      }
    });

    final anomalias = <String>[
      if (_anomFisica) 'daño_fisico',
      if (_anomFuncionamiento) 'falla_funcionamiento',
      if (_anomControl) 'control_no_funciona',
    ];

    // Una foto capturada pero no subida no llega a la orden de servicio. Antes
    // de avisar se reintenta la subida: casi siempre fue un corte momentáneo.
    if (_fotosSinSubir.isNotEmpty) {
      setState(() {
        _step3Error = null;
        _isLoading = true;
      });
      await _reintentarSubidasPendientes();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    final sinSubir = _fotosSinSubir;
    if (sinSubir.isNotEmpty) {
      setState(() => _step3Error =
          "No se pudo subir ${sinSubir.length == 1 ? 'la foto' : 'las fotos'} de ${sinSubir.join(', ')}. Revisa tu conexión y toca «Reintentar» en el paso 1.");
      return;
    }

    // La firma se rasteriza ANTES de mostrar el overlay de carga: el lienzo
    // debe seguir montado para poder medirlo.
    final firmaBase64 = await _firmaPngBase64();
    if (!mounted) return;
    final ubicacionCierre = ubicacionJson(await _getCurrentLocation());
    if (!mounted) return;
    if (firmaBase64 == null) {
      setState(() => _step3Error =
          "No se pudo capturar la firma. Pide al cliente que firme de nuevo.");
      return;
    }

    // Las claves deben coincidir con el esquema del backend (camelCase). Con
    // snake_case, Zod las descartaba en silencio y el cierre se guardaba vacío.
    final payload = {
      "evidencias": [
        for (final entry in _photoFileKeys.entries)
          {"fileKey": entry.value, "categoria": entry.key},
      ],
      "geolocalizacion": geoJson,
      "entregaEquipo": {
        "controlRemotoEntregado": _controlEntregado,
        "entregaFuncional": !_entregaConAnomalias,
        "anomalias": anomalias,
        "comentarios": _step2CommentsController.text.trim(),
        if (_camaras != null) "camaras": _camaras,
        if (_sensores != null) "sensores": _sensores,
      },
      "firmaBase64": firmaBase64,
      // Posición al cerrar: el backend la compara con la de la llegada.
      if (ubicacionCierre != null) "ubicacion": ubicacionCierre,
      if (confirmarUbicacion) "confirmarUbicacion": true,
      "comentariosGenerales":
          "Paso 1: ${_photoCommentsController.text.trim()} | Paso 2: ${_step2CommentsController.text.trim()}",
    };

    // Enviar al backend vía repositorio (Mock o Api según EnvConfig.useMock).
    setState(() {
      _step3Error = null;
      _isLoading = true;
    });
    final repo = sl.get<OrdenesRepository>();
    final ticketId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final result = await repo.guardarCierre(ticketId, payload);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'cierre_completed'),
      (failure) {
        setState(() => _isLoading = false);
        if (failure is ServerFailure && failure.code == 'FUERA_DE_SITIO') {
          _confirmarCierreLejos(failure);
          return;
        }
        setState(() => _step3Error = "No se pudo enviar el cierre: ${failure.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo enviar el cierre: ${failure.message}")),
        );
      },
    );
  }

  /// El backend detectó que el cierre está a más de 300 m de la llegada. El
  /// instalador puede confirmar; la confirmación queda en el chatter de Odoo.
  Future<void> _confirmarCierreLejos(ServerFailure failure) async {
    final distancia = failure.details['distanciaM'];
    final cs = Theme.of(context).colorScheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estás lejos del sitio'),
        content: Text(
          distancia != null
              ? 'Estás a $distancia m del punto donde marcaste la llegada. ¿Confirmas que estás cerrando la instalación en el sitio correcto?'
              : failure.message,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Revisar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            child: const Text('Sí, cerrar aquí'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) await _submitCierreInstalacion(confirmarUbicacion: true);
  }

  // ----- Reparación: manejo de fotos de evidencia dinámicas -----
  String _repairKey(int id) => 'Reparación foto $id';

  // Solo se puede agregar otra foto cuando todas las actuales ya se tomaron.
  bool get _canAddRepairPhoto =>
      _repairPhotoSlots.every((id) => _fotosCapturadas.contains(_repairKey(id)));

  void _addRepairPhotoSlot() {
    setState(() {
      _repairPhotoCounter++;
      _repairPhotoSlots.add(_repairPhotoCounter);
    });
  }

  void _removeRepairPhotoSlot(int id) {
    final key = _repairKey(id);
    setState(() {
      _repairPhotoSlots.remove(id);
      _photoPaths.remove(key);
      _photoLocations.remove(key);
      _photoTimestamps.remove(key);
      _geoMismatches.remove(key);
      _fotosCapturadas.remove(key);
    });
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
    // Y responder por los addons: instalados o no aplica. Sin respuesta no
    // hay forma de saber si faltó algo del servicio.
    if (_camaras == null || _sensores == null) return false;

    // Si reporta anomalías, debe marcar al menos un tipo o describirlas.
    if (_entregaConAnomalias) {
      final algunaAnom = _anomFisica || _anomFuncionamiento || _anomControl;
      if (!algunaAnom && _step2CommentsController.text.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

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
          _step1Error = _isReparacion
              ? "Agrega al menos una foto de la reparación (sin dejar fotos pendientes de captura)."
              : "Por favor, toma las 4 fotografías obligatorias.";
        });
        return;
      }
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      if (!_validateStep2()) {
        setState(() {
          _step2Error = !_controlEntregado
            ? "Confirma que entregaste el control remoto funcional."
            : (_camaras == null || _sensores == null)
                ? "Indica si instalaste cámaras y sensores, o marca «No aplica»."
                : "Indica el tipo de anomalía o descríbela en los comentarios.";
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // OhmSafe Color System
    // brandDark: neutral fuerte para foreground de botones "Atrás" (el texto se
    // sobrescribe aparte). El segmento activo usa cs.inverseSurface (pill
    // oscuro en claro / claro en oscuro), patrón M3 theme-aware.
    final brandDark = cs.onSurface;
    final brandOrange = cs.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Logo & Bell
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
                            const Text(
                              "OHM",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              "SAFE",
                              style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: const NotificationBell(),
                      ),
                    ],
                  ),
                ),

                // Back Button & Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          _isReparacion ? "Reparaciones" : "Instalaciones",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () {
                              if (_currentStep > 1) {
                                _prevStep();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(6),
                              shape: const CircleBorder(),
                            ),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: theme.iconTheme.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Screen Subtitle
                Center(
                  child: Text(
                    _isReparacion ? "Cierre de la reparación" : "Cierre de instalación",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Wizard Steps Navigation Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStepIndicatorLabel(1, "Evidencias", brandOrange),
                          _buildStepIndicatorLabel(2, "Equipo", brandOrange),
                          _buildStepIndicatorLabel(3, "Firma", brandOrange),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress Line
                      Row(
                        children: [
                          _buildStepProgressSegment(1),
                          const SizedBox(width: 4),
                          _buildStepProgressSegment(2),
                          const SizedBox(width: 4),
                          _buildStepProgressSegment(3),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Wizard Page Container
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_currentStep == 1) ...[
                          _buildStep1Evidence(brandDark, brandOrange),
                        ] else if (_currentStep == 2) ...[
                          _buildStep2Equipment(brandDark, brandOrange),
                        ] else if (_currentStep == 3) ...[
                          _buildStep3Signature(brandDark, brandOrange),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar overlay
          const AppBottomNav(),

          // Sending loading overlay
          if (_isLoading)
            _buildLoadingOverlay(context),
        ],
      ),
    );
  }

  // Step Indicators helpers
  Widget _buildStepIndicatorLabel(int step, String title, Color activeColor) {
    final bool isActive = _currentStep == step;
    final bool isCompleted = _currentStep > step;
    return Text(
      "Paso $step: $title",
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isActive 
            ? activeColor 
            : (isCompleted ? Colors.green : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildStepProgressSegment(int step) {
    final bool isActive = _currentStep == step;
    final bool isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: isActive 
              ? Theme.of(context).colorScheme.secondary
              : (isCompleted ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  // STEP 1 CONTENT: Evidence photos & anomaly justification
  Widget _buildStep1Evidence(Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    bool anyGeoMismatch = _geoMismatches.values.contains(true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isReparacion
              ? "EVIDENCIAS DE LA REPARACIÓN"
              : "EVIDENCIAS FOTOGRÁFICAS OBLIGATORIAS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isReparacion
              ? "Agrega las fotografías de la reparación realizada. Toma la primera y, si necesitas otra, pulsa \"Agregar foto\". El sistema verifica las coordenadas de cada captura."
              : "Captura las fotografías requeridas en el lugar de la instalación. El sistema verificará de forma segura las coordenadas de localización.",
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Fotos: en reparación, lista dinámica que se agrega una a una;
        // en instalación, las 4 categorías fijas.
        if (_isReparacion) ...[
          ..._repairPhotoSlots.asMap().entries.map(
                (e) => _buildRepairPhotoCard(e.value, e.key, brandDark, brandOrange),
              ),
          _buildAddRepairPhotoButton(brandOrange),
        ] else
          ..._categories.map((cat) => _buildPhotoCategoryCard(cat, brandDark, brandOrange)),

        // Anti-fraud GPS mismatch warning banner
        if (anyGeoMismatch) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "¡Alerta de geolocalización!",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Se detectó que alguna de las fotografías no fue tomada en la dirección registrada del cliente. Justifica la anomalía a continuación para continuar.",
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Anomaly Justification TextField
        const SizedBox(height: 24),
        Text(
          "COMENTARIOS Y JUSTIFICACIÓN DE ANOMALÍAS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _photoCommentsController,
          maxLines: 3,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: anyGeoMismatch 
              ? "Explica la causa del desfase de GPS (Ej: Instalación atípica, barda delgada, sin señal)..."
              : "Registra observaciones adicionales de la instalación...",
            filled: true,
            fillColor: context.ohm.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: anyGeoMismatch ? Colors.redAccent : brandOrange,
                width: 1.5,
              ),
            ),
          ),
        ),

        // Error message if any
        if (_step1Error != null) ...[
          const SizedBox(height: 16),
          Text(
            _step1Error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],

        // Siguiente Button
        const SizedBox(height: 32),
        OhmGradientButton(
          label: "Siguiente Paso",
          icon: Icons.arrow_forward_rounded,
          onPressed: _nextStep,
        ),
      ],
    );
  }

  /// Estado de la subida de la foto. En error, tocarlo reintenta sin volver a
  /// tomar la foto.
  Widget _estadoSubidaChip(String category) {
    final estado = _subidaFotos[category];
    switch (estado) {
      case _EstadoSubida.subiendo:
        return Row(
          children: const [
            SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6)),
            SizedBox(width: 6),
            Text("Subiendo…", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );
      case _EstadoSubida.ok:
        return const Row(
          children: [
            Icon(Icons.cloud_done_rounded, size: 13, color: Colors.green),
            SizedBox(width: 4),
            Text("Subida", style: TextStyle(fontSize: 11, color: Colors.green)),
          ],
        );
      case _EstadoSubida.error:
        return Semantics(
          button: true,
          label: "Reintentar subida de $category",
          child: InkWell(
            onTap: () => _subirFoto(category),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              // Área táctil cómoda sin agrandar la tarjeta.
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.cloud_off_rounded, size: 13, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text(
                    "No se subió · Reintentar",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotoCategoryCard(String category, Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final path = _photoPaths[category];
    final hasPhoto = path != null;
    final isMismatched = _geoMismatches[category] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMismatched 
            ? Colors.redAccent 
            : (hasPhoto ? Colors.green.shade200 : (isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant)),
        ),
      ),
      child: Row(
        children: [
          // Left side: Photo thumbnail or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant,
              // Ahora que la foto es real, se muestra: es la evidencia que
              // el instalador acaba de tomar, no un palomeo.
              child: hasPhoto
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 28,
                      ),
                    )
                  : Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 16),

          // Center info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isMismatched ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
                        size: 13,
                        color: isMismatched ? Colors.redAccent : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMismatched ? "Desfase GPS (>200m)" : "Verificado",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMismatched ? Colors.redAccent : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _estadoSubidaChip(category),
                ],
              ],
            ),
          ),

          // Right button: Action
          _capturingCategory == category
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => _capturarFoto(category),
                  icon: Icon(
                    hasPhoto ? Icons.cached_rounded : Icons.add_a_photo_rounded,
                    color: hasPhoto ? Colors.green : brandOrange,
                  ),
                ),
        ],
      ),
    );
  }

  // Tarjeta de una foto de evidencia de reparación (etiqueta "Foto N" por
  // posición; datos guardados con clave estable por id). Permite reemplazar
  // la foto y eliminar el slot si hay más de uno.
  Widget _buildRepairPhotoCard(int id, int index, Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final key = _repairKey(id);
    final hasPhoto = _photoPaths[key] != null;
    final isMismatched = _geoMismatches[key] ?? false;
    final isCapturing = _capturingCategory == key;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMismatched
              ? Colors.redAccent
              : (hasPhoto ? Colors.green.shade200 : (isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant)),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant,
              // Ahora que la foto es real, se muestra: es la evidencia que
              // el instalador acaba de tomar, no un palomeo.
              child: hasPhoto
                  ? Image.file(
                      File(_photoPaths[key]!),
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 28,
                      ),
                    )
                  : Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Foto ${index + 1}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isMismatched ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
                        size: 13,
                        color: isMismatched ? Colors.redAccent : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMismatched ? "Desfase GPS (>200m)" : "Verificado",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMismatched ? Colors.redAccent : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    "Pendiente de captura",
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
          // Eliminar slot (solo si hay más de una foto)
          if (_repairPhotoSlots.length > 1)
            IconButton(
              onPressed: isCapturing ? null : () => _removeRepairPhotoSlot(id),
              icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
            ),
          // Capturar / reemplazar
          isCapturing
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => _capturarFoto(key),
                  icon: Icon(
                    hasPhoto ? Icons.cached_rounded : Icons.add_a_photo_rounded,
                    color: hasPhoto ? Colors.green : brandOrange,
                  ),
                ),
        ],
      ),
    );
  }

  // Botón "Agregar foto": habilitado solo cuando todas las fotos actuales
  // ya se tomaron (flujo de una en una).
  Widget _buildAddRepairPhotoButton(Color brandOrange) {
    final theme = Theme.of(context);
    final enabled = _canAddRepairPhoto;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: enabled ? _addRepairPhotoSlot : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: brandOrange,
            side: BorderSide(
              color: enabled ? brandOrange : theme.dividerColor,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.add_a_photo_rounded, size: 18),
          label: const Text(
            "Agregar foto",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // STEP 2 CONTENT: confirmación de entrega de equipo (checks, sin foto/serie)
  Widget _buildStep2Equipment(Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Reparación sin cambio de energizador: no hay equipo que entregar.
    if (!_requiereEquipo) {
      return _buildStep2SinEquipo(brandDark, brandOrange);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "ENTREGA DE EQUIPO",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Confirma lo que entregaste e instalaste. Si el servicio no incluye un addon, márcalo como «No aplica». No se requiere foto ni número de serie.",
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Check: entrega del control remoto funcional
        _entregaCheckTile(
          theme,
          isDark,
          value: _controlEntregado,
          label: "Entregué funcional el control remoto",
          onChanged: (v) => setState(() {
            _controlEntregado = v;
            _step2Error = null;
          }),
          brandOrange: brandOrange,
        ),
        const SizedBox(height: 20),

        // Addons del servicio: cámaras y sensores
        Text(
          "ADDONS DEL SERVICIO",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _addonRow(
          theme,
          brandOrange,
          label: "Instalé y dejé funcionando cámaras",
          value: _camaras,
          onChanged: (v) => setState(() {
            _camaras = v;
            _step2Error = null;
          }),
        ),
        const SizedBox(height: 8),
        _addonRow(
          theme,
          brandOrange,
          label: "Instalé y dejé funcionando sensores",
          value: _sensores,
          onChanged: (v) => setState(() {
            _sensores = v;
            _step2Error = null;
          }),
        ),
        const SizedBox(height: 20),

        // Estado de la entrega
        Text(
          "ESTADO DE LA ENTREGA",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _entregaSegmented(theme, brandDark, brandOrange),

        // Si hubo anomalías: tipos + descripción
        if (_entregaConAnomalias) ...[
          const SizedBox(height: 20),
          Text(
            "TIPO DE ANOMALÍA",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _entregaCheckTile(
            theme,
            isDark,
            value: _anomFisica,
            label: "Daño físico en el equipo",
            onChanged: (v) => setState(() {
              _anomFisica = v;
              _step2Error = null;
            }),
            brandOrange: brandOrange,
          ),
          const SizedBox(height: 8),
          _entregaCheckTile(
            theme,
            isDark,
            value: _anomFuncionamiento,
            label: "Falla de funcionamiento",
            onChanged: (v) => setState(() {
              _anomFuncionamiento = v;
              _step2Error = null;
            }),
            brandOrange: brandOrange,
          ),
          const SizedBox(height: 8),
          _entregaCheckTile(
            theme,
            isDark,
            value: _anomControl,
            label: "El control remoto no funcionó",
            onChanged: (v) => setState(() {
              _anomControl = v;
              _step2Error = null;
            }),
            brandOrange: brandOrange,
          ),
          const SizedBox(height: 20),
          Text(
            "DESCRIPCIÓN DE LA ANOMALÍA",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _step2CommentsController,
            maxLines: 3,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            onChanged: (_) => setState(() => _step2Error = null),
            decoration: InputDecoration(
              hintText: "Describe la anomalía (obligatorio si no marcaste un tipo arriba)...",
              filled: true,
              fillColor: context.ohm.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
              ),
            ),
          ),
        ],

        if (_step2Error != null) ...[
          const SizedBox(height: 16),
          Text(
            _step2Error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],

        // Navegación
        const SizedBox(height: 32),
        Row(
          children: [
            // El boton de conclusion lleva la etiqueta larga, asi que se le da
            // el doble de espacio que a "Atras" para que no se trunque.
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandDark,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "Atrás",
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OhmGradientButton(
                label: "Siguiente",
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Fila-check reutilizable (tap para alternar).
  /// Fila de addon con dos opciones excluyentes: instalado o no aplica.
  /// Se exige respuesta explícita (no un check que se pueda dejar vacío) para
  /// distinguir "no lo instalé" de "el servicio no lo incluye".
  Widget _addonRow(
    ThemeData theme,
    Color brandOrange, {
    required String label,
    required String? value,
    required ValueChanged<String> onChanged,
  }) {
    Widget opcion(String v, String texto, IconData icono) {
      final activo = value == v;
      return Expanded(
        child: Semantics(
          button: true,
          selected: activo,
          label: "$label: $texto",
          child: InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              // 44 de alto: mínimo táctil de la guía.
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: activo ? brandOrange.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activo ? brandOrange : theme.dividerColor,
                  width: activo ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 16, color: activo ? brandOrange : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                        color: activo ? brandOrange : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              opcion('instaladas', "Instalé y funciona", Icons.check_circle_outline_rounded),
              const SizedBox(width: 8),
              opcion('no_aplica', "No aplica", Icons.block_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entregaCheckTile(
    ThemeData theme,
    bool isDark, {
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
    required Color brandOrange,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? brandOrange : (isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant),
            width: value ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: value ? brandOrange : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Segmentado: Todo funcional / Con anomalías.
  Widget _entregaSegmented(ThemeData theme, Color brandDark, Color brandOrange) {
    final cs = theme.colorScheme;
    final opciones = ['Todo funcional', 'Con anomalías'];
    final selected = _entregaConAnomalias ? 1 : 0;
    return Row(
      children: opciones.asMap().entries.map((e) {
        final sel = e.key == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _entregaConAnomalias = e.key == 1;
              _step2Error = null;
            }),
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppDurations.base),
              curve: AppCurves.standard,
              margin: EdgeInsets.only(right: e.key == 0 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? cs.inverseSurface : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? cs.inverseSurface : theme.dividerColor),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? cs.onInverseSurface : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // STEP 2 (variante): reparación sin cambio de energizador.
  Widget _buildStep2SinEquipo(Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "ENTREGA DE EQUIPO Y ACCESORIOS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: theme.colorScheme.secondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sin cambio de energizador",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "En esta reparación no se reemplazó el energizador, por lo que no se requiere registrar número de serie del control ni evidencia de equipo.",
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comentarios opcionales del equipo (no obligatorio)
        const SizedBox(height: 24),
        Text(
          "COMENTARIOS DE EQUIPO (OPCIONAL)",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _step2CommentsController,
          maxLines: 3,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: "Observaciones sobre el equipo existente (opcional)...",
            filled: true,
            fillColor: context.ohm.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
            ),
          ),
        ),

        // Navegación
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandDark,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "Atrás",
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OhmGradientButton(
                label: "Siguiente",
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3 CONTENT: Signature and termination
  Widget _buildStep3Signature(Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "CIERRE Y FIRMA DIGITAL",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Pide al cliente que firme de conformidad en el espacio a continuación. Al confirmar la firma, se bloqueará la pantalla y se habilitará la conclusión del servicio.",
          
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Interactive Signature Canvas Box
        Stack(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: context.ohm.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _signatureConfirmed 
                    ? Colors.green 
                    : (isDark ? theme.colorScheme.outline : theme.colorScheme.outlineVariant),
                  width: _signatureConfirmed ? 2.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
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
                          _FirmaPanRecognizer:
                              GestureRecognizerFactoryWithHandlers<_FirmaPanRecognizer>(
                            () => _FirmaPanRecognizer(),
                            (_FirmaPanRecognizer r) {
                              r.dragStartBehavior = DragStartBehavior.down;
                              r.onStart = (d) => _agregarTrazo(d.globalPosition);
                              r.onUpdate = (d) => _agregarTrazo(d.globalPosition);
                              r.onEnd = (_) => _terminarTrazo();
                            },
                          ),
                        },
                  child: CustomPaint(
                    painter: SignaturePainter(
                      _signaturePoints,
                      _signatureConfirmed
                          ? Colors.green
                          : (isDark ? Colors.white : Colors.black),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            
            // Signature Locked Overlay Banner
            if (_signatureConfirmed)
              Positioned.fill(
                child: Container(
                  color: Colors.green.withValues(alpha: 0.06),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "Firma Registrada",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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

        // Signature Canvas Actions
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _signatureConfirmed 
                ? null 
                : () {
                    setState(() {
                      _signaturePoints.clear();
                    });
                  },
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text("Limpiar"),
              style: TextButton.styleFrom(
                foregroundColor: _signatureConfirmed ? Colors.grey : brandOrange,
              ),
            ),
            if (!_signatureConfirmed)
              ElevatedButton.icon(
                onPressed: _signaturePoints.isNotEmpty 
                  ? () {
                      setState(() {
                        _signatureConfirmed = true;
                      });
                    }
                  : null,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text("Confirmar Firma"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  // OBLIGATORIO dentro de un Row: el tema global fija
                  // `minimumSize: Size.fromHeight(...)`, que es
                  // Size(double.infinity, h). En un Row el ancho disponible no
                  // esta acotado, asi que el boton pedia un ancho infinito, el
                  // layout de ese subarbol fallaba y el boton no se pintaba ni
                  // recibia toques: el instalador no podia confirmar la firma.
                  // (Mismo origen que la pantalla de Facturacion en blanco.)
                  minimumSize: const Size(150, 44),
                ),
              )
            else
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _signatureConfirmed = false;
                  });
                },
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text("Modificar"),
                style: TextButton.styleFrom(foregroundColor: brandOrange),
              ),
          ],
        ),

        if (_step3Error != null) ...[
          const SizedBox(height: 16),
          Text(
            _step3Error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],

        // Final Button & Previous Step navigation
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandDark,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "Atrás",
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: OhmGradientButton(
                label: _isReparacion ? "TERMINAR REPARACIÓN" : "TERMINAR INSTALACIÓN",
                icon: Icons.check_circle_rounded,
                onPressed: _canSubmitCierre() ? _submitCierreInstalacion : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Sending data overlay
  Widget _buildLoadingOverlay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 3.5,
              ),
              const SizedBox(height: 20),
              const Text(
                "Enviando Cierre...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Verificando localización y firmas",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
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
