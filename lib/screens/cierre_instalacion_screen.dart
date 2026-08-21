import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../widgets/app_bottom_nav.dart';

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
  final double _refLat = 19.432608;
  final double _refLng = -99.133209;

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
  final Map<String, bool> _geoMismatches = {};

  // Simulated photo list and capture states
  final List<String> _simulatedPhotos = [];
  String? _capturingCategory;

  final _photoCommentsController = TextEditingController();
  String? _step1Error;

  // Reparación: evidencias fotográficas dinámicas (se agregan una a una).
  // Guardamos ids estables; la etiqueta visible ("Foto N") se calcula por
  // posición, y la clave de almacenamiento por id se mantiene fija.
  final List<int> _repairPhotoSlots = [1];
  int _repairPhotoCounter = 1;

  // Step 2 State: confirmación de entrega del equipo (checks, sin foto/serie).
  bool _controlEntregado = false;        // Entregué el control remoto al cliente
  bool _entregaConAnomalias = false;     // false = todo funcional; true = hubo anomalías
  bool _anomFisica = false;              // Daño físico
  bool _anomFuncionamiento = false;      // Falla de funcionamiento
  bool _anomControl = false;             // El control remoto no funcionó
  final _step2CommentsController = TextEditingController();
  String? _step2Error;

  // Step 3 State: Signature Canvas
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

  // Fetch current GPS location with high accuracy
  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Return dummy position for testing if GPS is off
        return Position(
          latitude: 19.4326,
          longitude: -99.1332,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 2240.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint("Error fetching location: $e");
      // Fallback location close to Mexico City reference coordinates
      return Position(
        latitude: 19.432608 + 0.0005, // slightly offset to test mismatch optionally
        longitude: -99.133209 - 0.0003,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 2240.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
    }
  }

  // Validate geolocalisation distance (Haversine or simple threshold check)
  // Distance mismatch threshold ~ 200 meters (~0.002 degrees difference)
  bool _validateGeoLocation(double photoLat, double photoLng) {
    final double latDiff = (photoLat - _refLat).abs();
    final double lngDiff = (photoLng - _refLng).abs();
    return latDiff < 0.002 && lngDiff < 0.002;
  }

  // Simulated photo capture for Step 1
  Future<void> _simulatePhotoCapture(String category) async {
    if (_capturingCategory != null) return; // Prevent concurrent captures

    setState(() {
      _capturingCategory = category;
      _step1Error = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final position = await _getCurrentLocation();
      final timestamp = DateTime.now();
      bool isMatched = true;
      if (position != null) {
        isMatched = _validateGeoLocation(position.latitude, position.longitude);
      }

      setState(() {
        if (!_simulatedPhotos.contains(category)) {
          _simulatedPhotos.add(category);
        }
        _photoPaths[category] = "simulated_path_$category.png";
        _photoLocations[category] = position;
        _photoTimestamps[category] = timestamp;
        _geoMismatches[category] = !isMatched;
        _capturingCategory = null;
      });
    }
  }

  // Submit all details and complete installation
  Future<void> _submitCierreInstalacion() async {
    // Compile JSON Payload
    final List<String> urlsFotos = [
      ..._photoPaths.values.where((p) => p != null).map((p) => p!),
    ];

    final Map<String, dynamic> geoJson = {};
    _photoLocations.forEach((category, pos) {
      if (pos != null) {
        geoJson[category] = {
          "lat": pos.latitude,
          "lng": pos.longitude,
          "timestamp": _photoTimestamps[category]?.toIso8601String(),
          "mismatch": _geoMismatches[category] ?? false
        };
      }
    });

    final anomalias = <String>[
      if (_anomFisica) 'daño_fisico',
      if (_anomFuncionamiento) 'falla_funcionamiento',
      if (_anomControl) 'control_no_funciona',
    ];

    final payload = {
      "ticket_id": widget.ticket["id"] ?? "999",
      "urls_fotos": urlsFotos,
      "geolocalizacion": geoJson,
      "entrega_equipo": {
        "control_remoto_entregado": _controlEntregado,
        "entrega_funcional": !_entregaConAnomalias,
        "anomalias": anomalias,
      },
      "firma_base64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJY...", // Simulado
      "comentarios_generales": "Paso 1: ${_photoCommentsController.text.trim()} | Paso 2: ${_step2CommentsController.text.trim()}",
    };

    // Log the JSON Payload for submission
    debugPrint("SUBMITTING INSTALLATION CLOSURE JSON PAYLOAD FROM WIZARD:");
    debugPrint(const JsonEncoder.withIndent('  ').convert(payload));

    if (mounted) {
      Navigator.pop(context, 'cierre_completed');
    }
  }

  // ----- Reparación: manejo de fotos de evidencia dinámicas -----
  String _repairKey(int id) => 'Reparación foto $id';

  // Solo se puede agregar otra foto cuando todas las actuales ya se tomaron.
  bool get _canAddRepairPhoto =>
      _repairPhotoSlots.every((id) => _simulatedPhotos.contains(_repairKey(id)));

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
      _simulatedPhotos.remove(key);
    });
  }

  // ¿Están cubiertas las evidencias fotográficas del paso 1?
  bool _evidenciasCompletas() {
    if (_isReparacion) {
      // Al menos una foto y sin slots vacíos.
      if (_repairPhotoSlots.isEmpty) return false;
      for (final id in _repairPhotoSlots) {
        if (!_simulatedPhotos.contains(_repairKey(id))) return false;
      }
      return true;
    }
    for (String cat in _categories) {
      if (!_simulatedPhotos.contains(cat)) return false;
    }
    return true;
  }

  // Validate Step 1
  bool _validateStep1() {
    if (!_evidenciasCompletas()) return false;

    // Anti-fraud validation: if any photo has location mismatch, comments must be provided
    bool hasMismatch = _geoMismatches.values.contains(true);
    if (hasMismatch && _photoCommentsController.text.trim().isEmpty) {
      return false;
    }

    return true;
  }

  // Validate Step 2 (entrega de equipo por confirmación, sin foto/serie)
  bool _validateStep2() {
    // En reparación sin cambio de energizador no aplica el paso de equipo.
    if (!_requiereEquipo) return true;

    // Debe confirmar la entrega del control remoto al cliente.
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
        bool hasMismatch = _geoMismatches.values.contains(true);
        setState(() {
          _step1Error = hasMismatch
            ? "⚠️ Alerta de fraude. Se detectó discrepancia de ubicación. Justifica las anomalías en el campo de texto."
            : (_isReparacion
                ? "Agrega al menos una foto de la reparación (sin dejar fotos pendientes de captura)."
                : "Por favor, toma las 4 fotografías obligatorias.");
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
            ? "Confirma la entrega del control remoto al cliente."
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
    final isDark = theme.brightness == Brightness.dark;

    // OhmSafe Color System
    const brandDark = Color(0xFF2E3440);
    const brandOrange = Color(0xFFFF8D28);

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
                          children: const [
                            Text(
                              "OHM",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              "SAFE",
                              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5A00)),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Icon(
                              Icons.notifications,
                              color: theme.iconTheme.color?.withOpacity(0.7),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85),
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
            _buildLoadingOverlay(isDark),
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
              ? const Color(0xFFFF8D28)
              : (isCompleted ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  // STEP 1 CONTENT: Evidence photos & anomaly justification
  Widget _buildStep1Evidence(Color brandDark, Color brandOrange) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isReparacion
              ? "Agrega las fotografías de la reparación realizada. Toma la primera y, si necesitas otra, pulsa \"Agregar foto\". El sistema verifica las coordenadas de cada captura."
              : "Captura las fotografías requeridas en el lugar de la instalación. El sistema verificará de forma segura las coordenadas de localización.",
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
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
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6F8),
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
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: _validateStep1() ? const Color(0xFFFF5A00) : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text("Siguiente Paso", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
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
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMismatched 
            ? Colors.redAccent 
            : (hasPhoto ? Colors.green.shade200 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
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
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              child: hasPhoto
                  ? const Icon(Icons.check_circle, color: Color(0xFFFF8D28), size: 28)
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
                ],
              ],
            ),
          ),

          // Right button: Action
          _capturingCategory == category
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8D28)),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => _simulatePhotoCapture(category),
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
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMismatched
              ? Colors.redAccent
              : (hasPhoto ? Colors.green.shade200 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              child: hasPhoto
                  ? const Icon(Icons.check_circle, color: Color(0xFFFF8D28), size: 28)
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
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
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
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8D28)),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => _simulatePhotoCapture(key),
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Confirma la entrega del control remoto al cliente y el estado del equipo. No se requiere foto ni número de serie.",
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Check: entrega del control remoto
        _entregaCheckTile(
          theme,
          isDark,
          value: _controlEntregado,
          label: "Entregué el control remoto al cliente",
          onChanged: (v) => setState(() {
            _controlEntregado = v;
            _step2Error = null;
          }),
          brandOrange: brandOrange,
        ),
        const SizedBox(height: 20),

        // Estado de la entrega
        Text(
          "ESTADO DE LA ENTREGA",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
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
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
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
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
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
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFF8D28), width: 1.5),
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
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _validateStep2() ? const Color(0xFFFF5A00) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Siguiente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Fila-check reutilizable (tap para alternar).
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
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? brandOrange : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
            child: Container(
              margin: EdgeInsets.only(right: e.key == 0 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? brandDark : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? brandDark : theme.dividerColor),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFFF8D28), size: 22),
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
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
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
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF8D28), width: 1.5),
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
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Siguiente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Pide al cliente que firme de conformidad en el espacio a continuación. Al confirmar la firma, se bloqueará la pantalla y se habilitará la conclusión del servicio.",
          
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _signatureConfirmed 
                    ? Colors.green 
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: _signatureConfirmed ? 2.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Builder(
                  builder: (canvasContext) {
                    return GestureDetector(
                      onPanUpdate: _signatureConfirmed 
                        ? null 
                        : (details) {
                            final renderBox = canvasContext.findRenderObject() as RenderBox;
                            final localPosition = renderBox.globalToLocal(details.globalPosition);
                            setState(() {
                              _signaturePoints = List.from(_signaturePoints)..add(localPosition);
                            });
                          },
                      onPanEnd: _signatureConfirmed 
                        ? null 
                        : (details) {
                            setState(() {
                              _signaturePoints = List.from(_signaturePoints)..add(const Offset(-1, -1));
                            });
                          },
                      child: CustomPaint(
                        painter: SignaturePainter(
                          _signaturePoints, 
                          _signatureConfirmed 
                            ? Colors.green 
                            : (isDark ? Colors.white : Colors.black)
                        ),
                        size: Size.infinite,
                      ),
                    );
                  }
                ),
              ),
            ),
            
            // Signature Locked Overlay Banner
            if (_signatureConfirmed)
              Positioned.fill(
                child: Container(
                  color: Colors.green.withOpacity(0.06),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmitCierre() ? _submitCierreInstalacion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmitCierre() ? const Color(0xFFFF5A00) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isReparacion ? "TERMINAR REPARACIÓN" : "TERMINAR INSTALACIÓN",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Sending data overlay
  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(
                color: Color(0xFFFF5A00),
                strokeWidth: 3.5,
              ),
              SizedBox(height: 20),
              Text(
                "Enviando Cierre...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
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
