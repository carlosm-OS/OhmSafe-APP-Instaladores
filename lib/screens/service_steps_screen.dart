import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'route_details_screen.dart';
import 'perimeter_inspection_screen.dart';
import 'fence_installation_screen.dart';
import 'link_energizer_screen.dart';
import 'instalaciones_screen.dart';

// --- TRUCK ANIMATION PAGE ---
class TruckAnimationPage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TruckAnimationPage({super.key, required this.ticket});

  @override
  State<TruckAnimationPage> createState() => _TruckAnimationPageState();
}

class _TruckAnimationPageState extends State<TruckAnimationPage> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _bounceController;
  late AnimationController _scaleController;
  late AnimationController _roadController;

  @override
  void initState() {
    super.initState();
    // Rotate wheels
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // Bounce truck cabin/box slightly to simulate movement
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    // Animate road dashed line
    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    // Scale down wipe effect (from 1.0 to 0.0)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Run animation for 2.5 seconds, then perform wipe effect and navigate
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _scaleController.forward().then((_) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => ServiceStepsScreen(ticket: widget.ticket),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bounceController.dispose();
    _scaleController.dispose();
    _roadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) {
          // Scale down from 1.0 to 0.0 (wipe-out effect)
          final scaleValue = 1.0 - _scaleController.value;
          return Transform.scale(
            scale: scaleValue,
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stylized Animated Truck
              SizedBox(
                width: 240,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Moving dashed road lines
                    Positioned(
                      bottom: 14,
                      left: 20,
                      right: 20,
                      child: AnimatedBuilder(
                        animation: _roadController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: RoadPainter(
                              progress: _roadController.value,
                              color: theme.dividerColor,
                            ),
                            size: const Size(200, 2),
                          );
                        },
                      ),
                    ),
                    // Truck Body with Bounce Animation
                    AnimatedBuilder(
                      animation: _bounceController,
                      builder: (context, child) {
                        final bounceY = _bounceController.value * -3.0; // 3px bounce
                        return Transform.translate(
                          offset: Offset(0, bounceY),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Orange Cargo Body with Logo text inside
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5A00), // OhmSafe Orange
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                width: 85,
                                height: 50,
                                child: Center(
                                  child: Text(
                                    "OHMSAFE",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              // Cab (cabin)
                              Container(
                                width: 30,
                                height: 35,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E293B), // Dark slate cabin
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        width: 14,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100, // Window glass
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Rotating Wheels
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                RotationTransition(
                                  turns: _rotationController,
                                  child: const WheelWidget(),
                                ),
                                RotationTransition(
                                  turns: _rotationController,
                                  child: const WheelWidget(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Iniciando Ruta de servicio",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ROAD PAINTER ---
class RoadPainter extends CustomPainter {
  final double progress;
  final Color color;
  RoadPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    const dashWidth = 14.0;
    const dashSpace = 8.0;
    final totalSpacing = dashWidth + dashSpace;
    
    final offsetX = -progress * totalSpacing;

    double currentX = offsetX;
    while (currentX < size.width + totalSpacing) {
      if (currentX + dashWidth > 0) {
        canvas.drawLine(
          Offset(currentX, y),
          Offset(currentX + dashWidth, y),
          paint,
        );
      }
      currentX += totalSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) => oldDelegate.progress != progress;
}

// --- WHEEL WIDGET ---
class WheelWidget extends StatelessWidget {
  const WheelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white54,
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: WheelSpokesPainter(),
          ),
        ),
      ),
    );
  }
}

class WheelSpokesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(center, Offset(size.width / 2, 0), paint);
    canvas.drawLine(center, Offset(0, size.height), paint);
    canvas.drawLine(center, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- SERVICE STEPS SCREEN ---
class ServiceStepsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const ServiceStepsScreen({super.key, required this.ticket});

  @override
  State<ServiceStepsScreen> createState() => _ServiceStepsScreenState();
}

class _ServiceStepsScreenState extends State<ServiceStepsScreen> {
  bool _showToast = true;
  bool _step1Completed = false;
  bool _step2Completed = false;
  bool _step3Completed = false;
  bool _step4Completed = false;
  bool _step5Completed = false;

  @override
  void initState() {
    super.initState();
    // Hide the toast automatically after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final details = widget.ticket["details"] as Map<String, String>;
    final isUrgent = widget.ticket["isUrgent"] as bool? ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Logo centrado, icono notificaciones derecha)
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
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: theme.iconTheme.color?.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Back chevron and centered screen title "Detalle de Orden"
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
                            "Instalaciones",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
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

                // Expanded Ticket details (identical layout to expanded ticket, without start route button)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 100), // Extra bottom padding for floating bar space
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        elevation: 0,
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.dividerColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.ticket["title"]!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Abierto por ${details["openDays"]} días",
                                style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                                  children: [
                                    const TextSpan(text: "Fecha de Creación: ", style: TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: details["createdDate"]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                                  children: [
                                    const TextSpan(text: "Dirección: ", style: TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: details["direccion"]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                                      children: [
                                        const TextSpan(text: "Ciudad: ", style: TextStyle(fontWeight: FontWeight.w700)),
                                        TextSpan(text: details["ciudad"]),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                                      children: [
                                        const TextSpan(text: "CP: ", style: TextStyle(fontWeight: FontWeight.w700)),
                                        TextSpan(text: details["cp"]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85)),
                                  children: [
                                    const TextSpan(text: "Teléfono: ", style: TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: details["telefono"]),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              Divider(height: 1, color: theme.dividerColor),
                              const SizedBox(height: 12),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.ticket["user"]!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isUrgent)
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          "Urgente",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Order Steps Header
                      Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 8),
                        child: Text(
                          "PASOS DE LA ORDEN",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Step Items
                      _buildStepItem(
                        context,
                        number: "1",
                        title: "Técnico en ruta",
                        subtitle: "El servicio está en camino",
                        isActive: !_step1Completed,
                        isCompleted: _step1Completed,
                        onTap: !_step1Completed
                            ? () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RouteDetailsScreen(ticket: widget.ticket),
                                  ),
                                );
                                if (result == 'arrived') {
                                  setState(() {
                                    _step1Completed = true;
                                  });
                                }
                              }
                            : null,
                      ),
                      _buildStepItem(
                        context,
                        number: "2",
                        title: "Inspección del perímetro",
                        subtitle: "Identificar obstáculos",
                        isActive: _step1Completed && !_step2Completed,
                        isCompleted: _step2Completed,
                        onTap: (_step1Completed && !_step2Completed)
                            ? () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PerimeterInspectionScreen(ticket: widget.ticket),
                                  ),
                                );
                                if (result == 'perimeter_completed') {
                                  setState(() {
                                    _step2Completed = true;
                                  });
                                }
                              }
                            : null,
                      ),
                      _buildStepItem(
                        context,
                        number: "3",
                        title: "Instalación de cerca eléctrica",
                        subtitle: "Proceso de instalación de cerca en el perímetro",
                        isActive: _step2Completed && !_step3Completed,
                        isCompleted: _step3Completed,
                        onTap: (_step2Completed && !_step3Completed)
                            ? () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FenceInstallationScreen(ticket: widget.ticket),
                                  ),
                                );
                                if (result == 'installation_completed') {
                                  setState(() {
                                    _step3Completed = true;
                                  });
                                }
                              }
                            : null,
                      ),
                      _buildStepItem(
                        context,
                        number: "4",
                        title: "Vinculación del energizador",
                        subtitle: "Requiere escanear QR",
                        isActive: _step3Completed && !_step4Completed,
                        isCompleted: _step4Completed,
                        onTap: (_step3Completed && !_step4Completed)
                            ? () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LinkEnergizerScreen(ticket: widget.ticket),
                                  ),
                                );
                                if (result == 'device_linked') {
                                  setState(() {
                                    _step4Completed = true;
                                  });
                                }
                              }
                            : null,
                      ),
                      _buildStepItem(
                        context,
                        number: "5",
                        title: "Cierre de la instalación",
                        subtitle: "Configuración final",
                        isActive: _step4Completed && !_step5Completed,
                        isCompleted: _step5Completed,
                        onTap: (_step4Completed && !_step5Completed)
                            ? () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    backgroundColor: theme.cardColor,
                                    title: Text(
                                      "Cierre de instalación",
                                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                    ),
                                    content: Text(
                                      "Realizando configuraciones finales en la central del equipo... ¡Configurado con éxito!",
                                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            _step5Completed = true;
                                          });
                                        },
                                        child: const Text("Aceptar", style: TextStyle(color: Color(0xFFFF5A00))),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            : null,
                      ),

                      // Bottom Terminar button (active if step 5 is completed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _step5Completed
                                ? () => _showSignatureDialog(context)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _step5Completed
                                  ? const Color(0xFFFF5A00)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Terminar instalación",
                              style: TextStyle(
                                color: _step5Completed
                                    ? Colors.white
                                    : (isDark ? Colors.white30 : Colors.white70),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Barra de navegación compartida
          const AppBottomNav(),

          // Momentary Toast Notification (slides down from top, goes away in 4s)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            top: _showToast ? 64 : -100, // Position top
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _showToast ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFC2E7C0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF15803D) : const Color(0xFF86EFAC),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF15803D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Técnico en camino al domicilio",
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF14532D),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignatureDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    List<Offset> points = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Firma de Conformidad",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Por medio de la presente, el cliente firma de conformidad y acepta la entrega de la instalación OhmSafe completada con éxito.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Signature Drawing Pad
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.5),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Builder(
                          builder: (canvasContext) {
                            return GestureDetector(
                              onPanUpdate: (details) {
                                final renderBox = canvasContext.findRenderObject() as RenderBox;
                                final localPosition = renderBox.globalToLocal(details.globalPosition);
                                setState(() {
                                  points = List.from(points)..add(localPosition);
                                });
                              },
                              onPanEnd: (details) {
                                setState(() {
                                  points = List.from(points)..add(const Offset(-1, -1));
                                });
                              },
                              child: CustomPaint(
                                painter: SignaturePainter(points, isDark ? Colors.white : Colors.black),
                                size: Size.infinite,
                              ),
                            );
                          }
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              points.clear();
                            });
                          },
                          child: const Text("Limpiar firma", style: TextStyle(color: Color(0xFFFF5A00))),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancelar",
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: points.isNotEmpty
                          ? () {
                              Navigator.pop(context); // Cerrar dialog
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InstalacionesScreen(
                                    completedTicketTitle: widget.ticket["title"],
                                  ),
                                ),
                                (route) => false,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A00),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        disabledForegroundColor: isDark ? Colors.white30 : Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Firmar y finalizar",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepItem(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required bool isActive,
    bool isCompleted = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color cardBg;
    BorderSide borderSide;
    Color badgeBg;
    Color badgeTextColor;
    Color titleColor;
    Color subtitleColor;
    Color chevronColor;

    if (isCompleted) {
      cardBg = isDark ? const Color(0x33166534) : const Color(0xFFDCFCE7);
      borderSide = BorderSide(
        color: isDark ? const Color(0xFF166534) : const Color(0xFF15803D),
        width: 1.5,
      );
      badgeBg = isDark ? const Color(0xFF166534) : const Color(0xFF15803D);
      badgeTextColor = Colors.white;
      titleColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534);
      subtitleColor = isDark ? const Color(0xFF4ADE80).withOpacity(0.8) : const Color(0xFF166534).withOpacity(0.8);
      chevronColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534);
    } else if (isActive) {
      cardBg = theme.cardColor;
      borderSide = const BorderSide(
        color: Color(0xFFFF5A00),
        width: 1.5,
      );
      badgeBg = const Color(0xFFFF5A00);
      badgeTextColor = Colors.white;
      titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
      subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;
      chevronColor = const Color(0xFFFF5A00);
    } else {
      cardBg = isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF1F5F9);
      borderSide = BorderSide(
        color: theme.dividerColor.withOpacity(0.5),
        width: 1.0,
      );
      badgeBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      badgeTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
      titleColor = theme.textTheme.bodyLarge?.color?.withOpacity(0.4) ?? Colors.black45;
      subtitleColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.4) ?? Colors.black38;
      chevronColor = theme.iconTheme.color?.withOpacity(0.3) ?? Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderSide,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Number Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron Right
              Icon(
                Icons.chevron_right,
                color: chevronColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  SignaturePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != const Offset(-1, -1) && points[i + 1] != const Offset(-1, -1)) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
