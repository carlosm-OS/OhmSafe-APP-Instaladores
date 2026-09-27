import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/serie_qr.dart';

/// Cámara para leer el QR del energizador. Devuelve (pop) el número de serie
/// leído, o null si el instalador regresa sin escanear. El permiso de cámara lo
/// pide el sistema la primera vez (NSCameraUsageDescription en iOS).
class EscanearSerieScreen extends StatefulWidget {
  const EscanearSerieScreen({super.key});

  @override
  State<EscanearSerieScreen> createState() => _EscanearSerieScreenState();
}

class _EscanearSerieScreenState extends State<EscanearSerieScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _leido = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    for (final b in captura.barcodes) {
      final serie = serieDesdeQr(b.rawValue ?? '');
      if (serie.isNotEmpty) {
        _leido = true;
        Navigator.of(context).pop(serie);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => _SinCamara(error: error),
          ),
          // Marco guía
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Regresar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Linterna',
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Text(
                    'Apunta al código QR del energizador OhmSafe',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sin permiso o sin cámara: explica cómo darlo y deja volver a escribir la serie.
class _SinCamara extends StatelessWidget {
  final MobileScannerException error;
  const _SinCamara({required this.error});

  @override
  Widget build(BuildContext context) {
    final sinPermiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                sinPermiso
                    ? 'La app no tiene permiso para usar la cámara. Actívalo en Ajustes para escanear el QR, o escribe el número de serie.'
                    : 'No se pudo abrir la cámara. Escribe el número de serie del equipo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (sinPermiso && defaultTargetPlatform == TargetPlatform.iOS)
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse('app-settings:')),
                  child: const Text('Abrir Ajustes'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Escribir el número de serie', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
