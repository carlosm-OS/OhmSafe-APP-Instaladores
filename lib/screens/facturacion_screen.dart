import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';
import 'dart:ui';
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
  /// Nombre de la constancia que cargó OhmSafe ('' si aún no hay). Sólo lectura.
  String _constancia = '';
  bool _cargada = false;
  bool _stateLoaded = false;

  final TextEditingController _rfcController = TextEditingController();
  bool _savingRfc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_stateLoaded) {
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
        _constancia = perfil.constancia.isNotEmpty ? perfil.constancia : (perfil.tieneConstancia ? 'Constancia registrada' : '');
        _cargada = true;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    // Color system
    final labelColor = cs.onSurfaceVariant;
    final fillColor = ohm.surfaceContainer;

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
                            const NotificationBell(),
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
                            "Facturación",
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
                            // El tamaño se fija con `minimumSize`, NO envolviendo
                            // el botón en un SizedBox: dentro de un Row los hijos
                            // sin flex reciben ancho infinito para medirse, el
                            // SizedBox se lo pasaba al ElevatedButton y este no
                            // admite ancho infinito. Esa excepción tumbaba el
                            // layout de TODA la pantalla y la dejaba en blanco.
                            ElevatedButton(
                              onPressed: _savingRfc ? null : _guardarRfc,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(112, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _savingRfc
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold)),
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

                        // Constancia: la carga el equipo de OhmSafe en Odoo (2026-09-26). Sólo lectura.
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              const PdfDocumentIcon(width: 28, height: 36),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      !_cargada ? 'Consultando…' : (_constancia.isNotEmpty ? _constancia : 'Aún no cargada'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _constancia.isNotEmpty ? 'Cargada por OhmSafe' : 'La carga el equipo de OhmSafe',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _constancia.isNotEmpty ? Colors.green.shade600 : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tu constancia de situación fiscal la carga el equipo de OhmSafe. Si hay que actualizarla, escríbenos desde Ayuda.',
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.onSurfaceVariant),
                        ),
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
