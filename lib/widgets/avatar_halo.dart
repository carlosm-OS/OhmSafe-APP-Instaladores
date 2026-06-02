import 'package:flutter/material.dart';

class AvatarHalo extends StatefulWidget {
  final double size;
  final String initials;

  const AvatarHalo({
    super.key,
    this.size = 110,
    required this.initials,
  });

  @override
  State<AvatarHalo> createState() => _AvatarHaloState();
}

class _AvatarHaloState extends State<AvatarHalo> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orangeAccent = const Color(0xFFFF5A00);

    return SizedBox(
      width: widget.size + 40,
      height: widget.size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing Breathing Halo
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final blurRadius = 12.0 + (_pulseController.value * 14.0);
              final spreadRadius = 1.0 + (_pulseController.value * 4.0);
              final opacity = 0.25 + (_pulseController.value * 0.25);

              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: orangeAccent.withOpacity(opacity),
                      blurRadius: blurRadius,
                      spreadRadius: spreadRadius,
                    )
                  ],
                ),
              );
            },
          ),

          // Central Profile Avatar
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to a beautiful minimalist solid orange matching the screenshot style
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF5A00),
                          Color(0xFFFF7A30),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
