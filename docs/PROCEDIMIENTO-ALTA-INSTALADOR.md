# Procedimiento de alta de instalador (Operaciones) — Fase 1

Guía operativa para dar de alta a un instalador externo. La invitación se envía
**a mano** cuando Operaciones ya validó al candidato — **no** es automática al
ganar el lead. Versión visual en el artifact "Ruta del Ticket en Odoo".

El instalador es un **proveedor** en Odoo con la etiqueta **“Instalador Externo-OS”**
y un **usuario portal**. Solo ve **sus** órdenes en la app (campo `x_instalador_id`).

## Parte A — Operaciones da de alta
1. **Validar al candidato** — `CRM → Reclutamiento Instaladores OS-Ext`. El prospecto
   avanza por el pipeline conforme se valida su capacidad técnica/conocimiento.
   Ganar el lead **no dispara nada**; la decisión de invitar es manual.
2. **Crear el contacto (proveedor)** — `Contactos → Nuevo`: nombre, **correo** (será su
   usuario), teléfono. Etiqueta **“Instalador Externo-OS”** (obligatoria). Guardar
   como **proveedor** (para pagarle después).
3. **Acceso portal + contraseña temporal** — en el contacto: **Acción → Conceder
   acceso al portal** (portal = gratis). Luego `Ajustes → Usuarios → (instalador) →
   Cambiar contraseña`: pon una **contraseña temporal** (ej. `OhmSafe#2026`).
4. **Enviar la invitación (a mano)** — por correo/WhatsApp: enlace para **descargar la
   app**, su **correo** + **contraseña temporal**, e instrucción de entrar, cambiar
   la contraseña y completar el perfil.
   > Plantilla: *“Bienvenido a OhmSafe. Descarga la app: [enlace]. Entra con tu correo
   > y esta contraseña temporal: OhmSafe#2026. Al entrar, crea tu contraseña y completa
   > tu perfil (RFC, CURP y constancia de situación fiscal) para recibir instalaciones.”*

## Parte B — El instalador activa su cuenta (en la app)
5. **Entra y crea su contraseña** — login con correo + temporal → `Mi cuenta →
   Contraseñas` crea la suya (la temporal deja de servir).
6. **Completa su perfil** — `Mi cuenta`: Datos generales (nombre, teléfono, **CURP**),
   **RFC** (Facturación) y **constancia de situación fiscal (PDF)** → se adjunta a su
   contacto en Odoo.
7. **Queda “Activo”** — cuando hay **RFC + CURP + constancia**, `x_estado_instalador`
   pasa solo a **Activo**. Ya se le pueden asignar órdenes.

## Dónde verifica Operaciones (en el contacto de Odoo)
- **Tax ID (`vat`)** = RFC · **CURP** (`l10n_mx_edi_curp`) · **constancia** = adjunto.
- **Estado del instalador** (`x_estado_instalador`) = `pendiente_perfil` → `activo`.
- `suspendido` es manual (Operaciones) y el sistema no lo degrada solo.

## Asignar órdenes
`Proyecto → [TEST] Servicios Instalador` → tarea → campo **Instalador**
(`x_instalador_id`) = el contacto. La orden aparece en su app.

> Detalle técnico de endpoints: `ohmsafe/Back-` `docs/field-service.md`. Roadmap
> completo: `docs/ROADMAP-INSTALADORES-E2E.md`.
