/// Primer ingreso y «olvidé mi contraseña» (contrato: `/v1/instalador/auth/correo|codigo|activar`).
library;

/// Respuesta al paso del correo: qué pantalla sigue.
class AccesoSiguiente {
  /// 'password' (ya creó su contraseña) o 'codigo' (se le envió un código si procede).
  final String siguiente;

  /// Segundos antes de poder pedir otro código (0 si ya se puede).
  final int esperaSegundos;
  const AccesoSiguiente({required this.siguiente, this.esperaSegundos = 0});

  bool get pidePassword => siguiente == 'password';

  factory AccesoSiguiente.fromJson(Map<String, dynamic> j) => AccesoSiguiente(
        siguiente: j['siguiente']?.toString() ?? 'codigo',
        esperaSegundos: (j['esperaSegundos'] as num?)?.toInt() ?? 0,
      );
}

/// Código correcto: token de un solo uso para crear la contraseña y datos para la bienvenida.
class CodigoVerificado {
  final String activacion;
  final bool primeraVez;
  final String nombre;
  final String numeroInstalador;
  final String fotoBase64;
  const CodigoVerificado({
    required this.activacion,
    required this.primeraVez,
    this.nombre = '',
    this.numeroInstalador = '',
    this.fotoBase64 = '',
  });

  factory CodigoVerificado.fromJson(Map<String, dynamic> j) {
    final i = (j['instalador'] as Map<String, dynamic>?) ?? const {};
    return CodigoVerificado(
      activacion: j['activacion']?.toString() ?? '',
      primeraVez: j['primeraVez'] == true,
      nombre: i['nombre']?.toString() ?? '',
      numeroInstalador: i['numeroInstalador']?.toString() ?? '',
      fotoBase64: i['fotoBase64']?.toString() ?? '',
    );
  }
}

/// Mismas reglas que el backend: al menos 8 caracteres, con letras y números.
String? validarPasswordNueva(String p) {
  if (p.length < 8) return 'Usa al menos 8 caracteres.';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) return 'Combina letras y números.';
  return null;
}
