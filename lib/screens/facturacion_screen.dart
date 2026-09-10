import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../controllers/app_state.dart';
import '../controllers/app_state_provider.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';

class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({super.key});

  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  bool _isUploading = false;
  String? _selectedFileName;
  String? _selectedFilePath;
  String? _errorMessage;
  bool _stateLoaded = false;

  final TextEditingController _rfcController = TextEditingController();
  bool _savingRfc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_stateLoaded) {
      final state = AppStateProvider.of(context);
      if (state.taxCertificatePath != null) {
        _selectedFilePath = state.taxCertificatePath;
        _selectedFileName = state.taxCertificateName;
      }
      _stateLoaded = true;
      _cargarPerfil(); // espejo Odoo→app: RFC y constancia actuales de Odoo
    }
  }

  @override
  void dispose() {
    _rfcController.dispose();
    super.dispose();
  }

  /// Lee el perfil de Odoo para reflejar RFC y estado de la constancia.
  Future<void> _cargarPerfil() async {
    final result = await sl.get<PerfilRepository>().getPerfil();
    if (!mounted) return;
    result.fold((perfil) {
      setState(() {
        _rfcController.text = perfil.rfc;
        if (perfil.tieneConstancia && _selectedFileName == null) {
          _selectedFileName = "Constancia registrada";
        }
      });
    }, (_) {});
  }

  /// Guarda el RFC en Odoo (campo fiscal nativo `vat`).
  Future<void> _guardarRfc() async {
    if (_savingRfc) return;
    setState(() => _savingRfc = true);
    final result = await sl.get<PerfilRepository>().updatePerfil(rfc: _rfcController.text.trim());
    if (!mounted) return;
    setState(() => _savingRfc = false);
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("RFC guardado"), backgroundColor: Theme.of(context).colorScheme.primary),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo guardar el RFC: ${failure.message}"), backgroundColor: Colors.redAccent),
      ),
    );
  }

  Future<void> _pickFile(AppState state) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // necesitamos los bytes para subir la constancia en base64
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Verify it is indeed a PDF
        if (file.extension?.toLowerCase() != 'pdf') {
          setState(() {
            _errorMessage = "Solo se admiten archivos en formato .PDF";
          });
          return;
        }

        // Web check: check bytes if kIsWeb, or path on mobile/desktop
        final bool hasData = kIsWeb ? (file.bytes != null) : (file.path != null);
        if (!hasData) {
          setState(() {
            _errorMessage = "No se pudo leer el archivo. Intenta de nuevo.";
          });
          return;
        }

        // Start upload simulation
        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = kIsWeb ? 'web_upload/${file.name}' : file.path;
          _isUploading = true;
        });

        await _subirConstancia(state, file);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error al seleccionar el archivo: ${e.toString()}";
      });
    }
  }

  /// Sube la constancia (PDF) al backend en base64; se guarda como adjunto en el
  /// contacto de Odoo. Solo si tiene éxito se refleja en el estado local.
  Future<void> _subirConstancia(AppState state, PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _isUploading = false;
        _errorMessage = "No se pudo leer el archivo. Intenta de nuevo.";
      });
      return;
    }
    final result = await sl.get<PerfilRepository>().subirConstancia(
          nombreArchivo: file.name,
          contenidoBase64: base64Encode(bytes),
          mimetype: 'application/pdf',
        );
    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });
    result.fold(
      (_) {
        state.updateTaxCertificate(_selectedFilePath, _selectedFileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Constancia fiscal subida correctamente",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      (failure) {
        setState(() {
          _errorMessage = "No se pudo subir la constancia: ${failure.message}";
        });
      },
    );
  }

  void _deleteFile(AppState state) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            "Eliminar archivo",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "¿Estás seguro de que deseas eliminar la constancia de situación fiscal subida?",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancelar",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedFileName = null;
                  _selectedFilePath = null;
                  _isUploading = false;
                });
                state.updateTaxCertificate(null, null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Constancia fiscal eliminada"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
              child: const Text(
                "Eliminar",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    // Color system
    final labelColor = cs.onSurfaceVariant;
    final fillColor = ohm.surfaceContainer;
    final dashedBorderColor = isDark ? cs.onSurfaceVariant : cs.outline;

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
      color: labelColor,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Logo and Notification Bell
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
                            Text(
                              "OHM",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              "SAFE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.notifications,
                                color: theme.iconTheme.color?.withValues(alpha: 0.7),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
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

                // Back chevron and Centered Title Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Text(
                            "Perfil",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
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

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtitle: Facturación
                        Center(
                          child: Text(
                            "Facturación",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // RFC — campo fiscal (se guarda en Odoo como `vat`)
                        Text("RFC", style: labelStyle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
                                child: TextField(
                                  controller: _rfcController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    hintText: "Tu RFC",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _savingRfc ? null : _guardarRfc,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _savingRfc
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Section Label: CONSTANCIA DE SITUACIÓN FISCAL
                        Text(
                          "CONSTANCIA DE SITUACIÓN FISCAL",
                          style: labelStyle,
                        ),
                        const SizedBox(height: 12),

                        // Dashed Box Container
                        CustomPaint(
                          painter: DashedRectPainter(
                            color: dashedBorderColor,
                            borderRadius: 20.0,
                            strokeWidth: 1.5,
                            dashWidth: 6.0,
                            dashSpace: 5.0,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _isUploading
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 48,
                                        width: 48,
                                        child: CircularProgressIndicator(
                                          color: cs.primary,
                                          strokeWidth: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        "Subiendo archivo...",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _selectedFileName ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Styled document icon
                                      const PdfDocumentIcon(width: 54, height: 72),
                                      const SizedBox(height: 24),

                                      // Primary title text
                                      Text(
                                        "Selecciona un archivo o documento.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Allowed format subtext
                                      Text(
                                        "El archivo debe ser .PDF",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Buscar archivo outline button
                                      SizedBox(
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: () => _pickFile(state),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: cs.primary,
                                            side: BorderSide(color: cs.primary, width: 1.5),
                                            padding: const EdgeInsets.symmetric(horizontal: 40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                          ),
                                          child: const Text(
                                            "Buscar archivo",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Error message display if any
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Uploaded file section
                        if (_selectedFileName != null && !_isUploading) ...[
                          const SizedBox(height: 32),
                          Text(
                            "ARCHIVO SUBIDO",
                            style: labelStyle,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                // Small PDF icon
                                const PdfDocumentIcon(width: 28, height: 36),
                                const SizedBox(width: 16),

                                // Name & upload state
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedFileName ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Subido",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Trash action button
                                IconButton(
                                  onPressed: () => _deleteFile(state),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar overlay
          const AppBottomNav(currentTab: "Perfil"),
        ],
      ),
    );
  }
}

// Custom Painter to draw modern dashed borders
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedRectPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 4.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = _buildDashedPath(path, dashWidth, dashSpace);

    canvas.drawPath(dashedPath, paint);
  }

  Path _buildDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path path = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashWidth : dashSpace;
        if (draw) {
          path.addPath(
            metric.extractPath(distance, (distance + len).clamp(0, metric.length)),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Premium scaled document icon widget
class PdfDocumentIcon extends StatelessWidget {
  final double height;
  final double width;

  const PdfDocumentIcon({
    super.key,
    this.height = 80,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: CustomPaint(
        painter: _PdfIconPainter(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _PdfIconPainter extends CustomPainter {
  final Color color;

  _PdfIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double foldSize = size.width * 0.35;

    // Draw document block shape with top right fold cutout
    path.moveTo(0, 0);
    path.lineTo(size.width - foldSize, 0);
    path.lineTo(size.width, foldSize);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw the folded corner flap
    final foldPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final foldPath = Path();
    foldPath.moveTo(size.width - foldSize, 0);
    foldPath.lineTo(size.width - foldSize, foldSize);
    foldPath.lineTo(size.width, foldSize);
    foldPath.close();

    canvas.drawPath(foldPath, foldPaint);

    // Draw "PDF" text in white centered in the lower area
    final fontSize = size.height * 0.18;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: 'PDF',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: 0.5,
      ),
    );
    textPainter.layout();

    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      size.height - textPainter.height - (size.height * 0.15),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
