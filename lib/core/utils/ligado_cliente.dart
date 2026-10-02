/// Texto para el instalador cuando el energizador quedó vinculado a la
/// intervención pero NO llegó a la cuenta del cliente en la app OhmSafe.
/// `dashboard` es lo que devuelve `POST /instalador/ordenes/:id/vincular-energizador`
/// (`ligado`, `motivo`). Devuelve null si el equipo sí quedó en la cuenta del cliente.
String? avisoLigadoCliente(Map<String, dynamic> dashboard) {
  if (dashboard['ligado'] != false) return null;
  switch (dashboard['motivo']) {
    case 'CLIENTE_SIN_CUENTA':
      return 'El cliente todavía no tiene cuenta en la app OhmSafe con el correo de su contrato, '
          'así que el equipo aún no aparece en su app. Puedes seguir con la instalación; '
          'avisa a operaciones para que lo liguen cuando cree su cuenta.';
    case 'EQUIPO_DE_OTRO_TITULAR':
      return 'Este equipo ya está dado de alta con otro cliente en el dashboard, por eso no se ligó '
          'a este cliente. Revisa la etiqueta del equipo y avisa a operaciones antes de continuar.';
    default:
      return 'El equipo no se pudo ligar a la cuenta del cliente. Avisa a operaciones.';
  }
}
