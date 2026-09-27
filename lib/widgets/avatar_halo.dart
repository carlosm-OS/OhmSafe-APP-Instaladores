import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';

/// Iniciales a partir de un nombre: primeras letras de las dos primeras
/// palabras, en mayúsculas. Devuelve [fallback] (por defecto "IN") si el
/// nombre viene vacío.
String initialsFromName(String? name, {String fallback = 'IN'}) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

class AvatarHalo extends StatefulWidget {
  final double size;
  final String initials;
  final String? imagePath;

  /// Foto de perfil (ej. de Odoo) en base64. Se usa cuando no hay [imagePath]
  /// local recién elegido, así la foto persiste entre sesiones.
  final String? imageBase64;

  /// Si no hay [imagePath] y se pasa un icono, se muestra ese icono (ej. un
  /// instalador) en vez de la foto por defecto. Útil para usuarios sin foto.
  final IconData? placeholderIcon;

  const AvatarHalo({
    super.key,
    this.size = 110,
    required this.initials,
    this.imagePath,
    this.imageBase64,
    this.placeholderIcon,
  });

  @override
  State<AvatarHalo> createState() => _AvatarHaloState();
}

class _AvatarHaloState extends State<AvatarHalo> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  /// Bytes decodificados de [AvatarHalo.imageBase64], memoizados para no
  /// decodificar en cada rebuild. null si no hay base64 o falló la decodificación.
  Uint8List? _decodedBytes;

  @override
  void initState() {
    super.initState();
    _decodeBase64();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AvatarHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBase64 != widget.imageBase64) _decodeBase64();
  }

  void _decodeBase64() {
    final b64 = widget.imageBase64;
    if (b64 == null || b64.isEmpty) {
      _decodedBytes = null;
      return;
    }
    try {
      _decodedBytes = base64Decode(b64);
    } catch (_) {
      _decodedBytes = null;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orangeAccent = Theme.of(context).colorScheme.primary;

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
                      color: orangeAccent.withValues(alpha: opacity),
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
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipOval(
              child: _buildAvatarImage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      if (widget.imagePath!.startsWith('assets/')) {
        return Image.asset(
          widget.imagePath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      } else {
        return Image.file(
          File(widget.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }
    }
    // Foto persistida (ej. Odoo) en base64: gana cuando no hay preview local.
    if (_decodedBytes != null) {
      return Image.memory(
        _decodedBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    // Sin foto: icono de instalador (si se pidió) en vez de la foto por defecto.
    if (widget.placeholderIcon != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: context.ohm.brandGradient,
        ),
        alignment: Alignment.center,
        child: Icon(widget.placeholderIcon, color: Colors.white, size: widget.size * 0.5),
      );
    }
    // Fallback to default asset
    return Image.asset(
      'assets/assets/avatar.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: context.ohm.brandGradient,
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
  }
}
