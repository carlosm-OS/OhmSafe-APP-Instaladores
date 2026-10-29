import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/serie_qr.dart';
import '../widgets/ohm_gradient_button.dart';

/// Cámara para leer el QR del energizador. Devuelve (pop) el número de serie
/// leído, o null si el instalador regresa sin escanear. El permiso de cámara lo
/// pide el sistema la primera vez (NSCameraUsageDescription en iOS).
///
/// [leer] permite reutilizarla para otras etiquetas (2026-10-17: la de las cámaras): recibe
/// el texto crudo del QR y devuelve lo que se regresa, o '' si no lo reconoce y hay que seguir.
class EscanearSerieScreen extends StatefulWidget {
  const EscanearSerieScreen({super.key, this.leer = serieDesdeQr, this.indicacion = 'Apunta al código QR del energizador OhmSafe'});

  final String Function(String crudo) leer;
  final String indicacion;

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
      final serie = widget.leer(b.rawValue ?? '');
      if (serie.isNotEmpty) {
        _leido = true;
        Navigator.of(context).pop(serie);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Visor de cámara: fondo oscuro del tema (scrim) y texto blanco sobre la imagen.
    return Scaffold(
      backgroundColor: theme.colorScheme.scrim,
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
                        tooltip: 'Cerrar la cámara',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Encender o apagar la linterna',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Text(
                    widget.indicacion,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
    final theme = Theme.of(context);
    final sinPermiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: theme.colorScheme.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_rounded, color: Colors.white.withValues(alpha: 0.7), size: 56),
              const SizedBox(height: 16),
              Text(
                sinPermiso
                    ? 'La app no tiene permiso para usar la cámara. Actívalo en Ajustes para escanear el QR, o escribe el número de serie.'
                    : 'No se pudo abrir la cámara. Escribe el número de serie del equipo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              if (sinPermiso && defaultTargetPlatform == TargetPlatform.iOS) ...[
                OhmGradientButton(label: 'Abrir Ajustes', icon: Icons.settings_rounded, onPressed: () => launchUrl(Uri.parse('app-settings:'))),
                const SizedBox(height: 8),
              ],
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(44, 44), textStyle: theme.textTheme.labelLarge),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Escribir el número de serie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
