import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../controllers/app_state.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/app_bottom_nav.dart';

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
    }
  }

  Future<void> _pickFile(AppState state) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
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

        await _simulateFileUpload(state);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error al seleccionar el archivo: ${e.toString()}";
      });
    }
  }

  Future<void> _simulateFileUpload(AppState state) async {
    // Simular el proceso de red durante 2 segundos
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isUploading = false;
      });
      // Guardar el archivo en la plataforma (estado global)
      state.updateTaxCertificate(_selectedFilePath, _selectedFileName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Constancia fiscal subida correctamente",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Color(0xFFFF5A00),
        ),
      );
    }
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
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    // Color system
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9);
    final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6F8);
    final dashedBorderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

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
                            const Text(
                              "SAFE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5A00),
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
                                color: theme.iconTheme.color?.withOpacity(0.7),
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
                              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85),
                            ),
                          ),
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
                                      const SizedBox(
                                        height: 48,
                                        width: 48,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFF5A00),
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
                                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Buscar archivo outline button
                                      SizedBox(
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: () => _pickFile(state),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFFF5A00),
                                            side: const BorderSide(color: Color(0xFFFF5A00), width: 1.5),
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
        painter: _PdfIconPainter(color: const Color(0xFF475569)),
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
      ..color = color.withOpacity(0.85)
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
