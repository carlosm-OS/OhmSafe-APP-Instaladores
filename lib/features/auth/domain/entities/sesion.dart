/// Sesión autenticada del instalador. Forma alineada con el contrato
/// (`POST /v1/instalador/auth/login`). Login real = usuario de Odoo.
class Sesion {
  final String accessToken;
  final String refreshToken;
  final String instaladorId;
  final String nombre;
  final String numeroInstalador;
  final String rol;

  /// Onboarding: entró con contraseña temporal y aún no crea la suya.
  /// La app lo lleva directo a "crea tu contraseña" antes del home.
  final bool debeCambiarPassword;

  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.instaladorId,
    required this.nombre,
    required this.numeroInstalador,
    required this.rol,
    this.debeCambiarPassword = false,
  });
}
