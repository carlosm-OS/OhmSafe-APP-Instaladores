# Estado del proyecto — Plataforma de Instaladores OhmSafe

Nota de estado y checklist de todo lo construido. Fecha de corte: **2026-09-07**.
Fuente de verdad de la operación: **Odoo `ohmsafe2`**, proyecto `[TEST] Servicios Instalador` (id 1).
La app habla con el backend `/v1/instalador/*` (passthrough a Odoo).

Docs relacionadas: [ROADMAP-INSTALADORES-E2E](ROADMAP-INSTALADORES-E2E.md) ·
[MANUAL-OPERACION-ODOO](MANUAL-OPERACION-ODOO.md) ·
[PROCEDIMIENTO-ALTA-INSTALADOR](PROCEDIMIENTO-ALTA-INSTALADOR.md) ·
[CONTRATO-API-instalador](CONTRATO-API-instalador.md).

---

## Resumen ejecutivo
El ciclo E2E del instalador está **operativo en dev**: onboarding en la app,
identidad (número + código de venta), origen del ticket (histórico + tiempo real
desde HubSpot), panel de asignación en Odoo, y notificación push al asignar.
Falta principalmente **probar el push en un dispositivo físico** y decisiones de
producto sobre el bono (Capa B) y la publicación en tiendas.

Leyenda: ✅ hecho y probado · 🟡 hecho, falta prueba/decisión · ⬜ pendiente.

---

## Fase 1 — Onboarding y perfil  ✅
- ✅ **Primer ingreso**: entra con contraseña temporal → la app **fuerza crear
  su contraseña** (pantalla de onboarding) → home.
- ✅ **Perfil espejo Odoo↔app**: nombre, teléfono, CURP (`l10n_mx_edi_curp`),
  RFC (`vat`), foto (`image_1920`), constancia (`x_constancia_url`). Cambios en
  la app se escriben en Odoo y viceversa.
- ✅ **Foto de perfil**: la app la formatea (JPG ≤1024) antes de subir; errores
  de subida claros; se guarda en el contacto de Odoo.
- ✅ **Estado del instalador** (`x_estado_instalador`): `pendiente_perfil` →
  `activo` cuando hay RFC + CURP + constancia.
- ✅ **Identidad** (al activarse):
  - `x_numero_instalador` — número visible **aleatorio único de 5 dígitos**
    (no el id de Odoo). Se muestra en el home (`Instalador #NNNNN`).
  - `x_codigo_venta` — código de descuento/bono tipo `OHMS-<NOMBRE><NN>`.
    Se muestra en **Datos Generales** (chip copiable).
- ✅ **Documento**: [PROCEDIMIENTO-ALTA-INSTALADOR](PROCEDIMIENTO-ALTA-INSTALADOR.md).

## Fase 2 — Origen y asignación del ticket  ✅ / 🟡
### 2A · Import histórico (HubSpot → Odoo)  ✅
- ✅ **26 instalaciones cerradas** importadas como `project.task` (etapa
  *Completada*), ligadas al cliente, con antigüedad en `x_alta_hubspot`.
- ✅ Script `scripts/import-instalaciones-historico.mjs` (backend): idempotente
  por `x_hubspot_id`, dry-run por defecto, `--commit`/`--limit`.

### 2B · Origen en tiempo real (banderazo, self-contained)  ✅
El ticket nace por un **workflow de HubSpot** al entrar el pago; lo reflejamos a
Odoo sin tocar Stripe/checkout:
- ✅ **Espejo por polling**: modo `--mirror` del script + **systemd timer** en
  api-dev (`ohmsafe-instalacion-mirror.timer`, cada 15 min). Mapea cada etapa de
  HubSpot a su stage de Odoo. Create-only e idempotente.
- ✅ **Webhook en tiempo real**: `POST /v1/instalador/webhooks/instalacion`
  (token compartido). Probado E2E (creada/ya-existe).
  - 🟡 **Falta (Carlos, HubSpot UI)**: agregar la acción "Enviar webhook" al
    workflow que crea el ticket, apuntando a esa URL con el token. El timer
    queda de red de seguridad.

### Panel de asignación (Operaciones)  ✅
- ✅ **Odoo nativo**: menú **"Asignación de instaladores"** (bajo Project),
  agrupado por instalador; la columna "Ninguno" son las que faltan por asignar.
  + favoritos "🔧 Instalaciones sin asignar" y "👷 Instalaciones por instalador".
- ✅ Asignar = escribir `x_instalador_id`; sale de "sin asignar" y aparece en la
  app del instalador (filtro "solo lo mío").

### Notificación al instalador (push)  🟡
- ✅ **Backend + Odoo + GCP** probado (keyless): al asignar → automation de Odoo
  → webhook `POST /v1/instalador/webhooks/asignacion` → backend lee los tokens
  del instalador (`res.partner.x_push_tokens`) → **FCM**.
- ✅ **Auth sin secreto (Workload Identity Federation)**: proyecto Firebase
  propio `ohmsafe-instaladores`; el backend en AWS se autentica a GCP sin
  descargar claves (la org bloquea SA keys). Segundo Firebase app en el backend.
- ✅ **App cableada**: `firebase_core` + `firebase_messaging`, plugin
  google-services (Android), init en `main`, `PushService` (permiso → token →
  `POST /v1/instalador/push/registrar` tras login → abrir Instalaciones al
  tocar). Compila (0 issues) y la app corre; en macOS es no-op (sin Firebase).
- 🟡 **Falta probar en un teléfono Android** (token real) — es lo único que
  cierra el ciclo.
- ⬜ **iOS**: subir la **APNs Auth Key** a Firebase + fijar `platform :ios, '13.0'`
  al generar el Podfile. Android no lo necesita.

## Fase 3 — Ejecución con control de pasos + firma  ✅ (base)
- ✅ Flujo por pasos en la app (ruta → llegada → inspección → registro/costeo →
  vincular energizador → cierre con firma), cada paso escribe en Odoo y mueve la
  etapa. Detalle campo por campo en [MANUAL-OPERACION-ODOO](MANUAL-OPERACION-ODOO.md).

## Fases 4–5 — Pago al instalador y encuesta/ranking  ✅ (2026-09-25, sobre apps nativas de Odoo)
- ✅ **Pago (cuentas por pagar)**: al cerrar nace la factura de proveedor en borrador
  (Compras) con el producto `PAGO-<tipo>`; operaciones valida, contabilidad paga.
  Perfil › Mis pagos. Falta que Carlos fije los costos de `PAGO-*` en Odoo.
- ✅ **Encuesta + ranking**: encuesta nativa al cerrar; `perfil.calificacion` real.
- 🟡 **Bono por referidos (Capa B)**: la atribución ya existe (cotización desde la app con
  UTM «App instalador / Venta en campo» y código de venta en `origin`); falta la regla de
  comisión.

---

## Diseño y app  ✅
- ✅ **Sistema de tema "Faena"** (`lib/core/theme`): Material 3, alto contraste
  para exterior, tokens de color/espaciado/radio/motion, light + dark,
  `OhmColors` (success/warning/info/accent). Migradas ~24 pantallas a tokens.
- ✅ **Tipografía** Lexend (títulos) + Inter (cuerpo), fuentes variables OFL
  empaquetadas (offline).
- ✅ **Botón primario con gradiente** (`OhmGradientButton`) en todos los CTAs.
- ✅ **Badges del home** reflejan asignaciones reales (no un mock).

## Backend — endpoints `/v1/instalador/*`  ✅
- Auth: `POST /auth/login`, `POST /auth/cambiar-password`.
- Perfil: `GET/PUT /perfil`, `POST /perfil/avatar`, `POST /perfil/constancia`.
- Órdenes: `GET /ordenes`, `GET /ordenes/:id`, acciones (iniciar-ruta,
  marcar-llegada, inspección, instalación, reparación, vincular-energizador,
  cierre, cancelar), `GET /historial`, `GET /tarifas-reparacion`.
- Push: `POST /push/registrar` (autenticado).
- Webhooks (token): `POST /webhooks/instalacion`, `POST /webhooks/asignacion`.

## Odoo — campos y objetos clave  ✅
- `res.partner`: `vat`, `l10n_mx_edi_curp`, `image_1920`, `x_constancia_url`,
  `x_estado_instalador`, `x_password_cambiada`, **`x_numero_instalador`**,
  **`x_codigo_venta`**, **`x_push_tokens`**, etiqueta "Instalador Externo-OS".
- `project.task` (proyecto 1): `x_instalador_id`, `x_tipo_servicio`, campos de
  ejecución `x_…`, **`x_hubspot_id`**, **`x_alta_hubspot`**.
- Automation: **"Notificar instalador al asignar"** (on write `x_instalador_id`)
  → acción webhook.

## Infraestructura  ✅
- Deploy dev: `CarlosClaudDev-backend` → `dev` (ff) → rsync+build+restart en
  **api-dev** (nunca prod, solo desde git).
- FCM instaladores: proyecto `ohmsafe-instaladores`; **WIF** (pool `aws-pool` +
  provider AWS, cuenta 511485102273, rol OhmsafeSSMRole); credencial
  `external_account` sin llave en `/opt/ohmsafe/secrets/fcm-instaladores-wif.json`.
- El push de pánico sigue en el Firebase de Dan (`ohmsafe-2615c`), intacto.

---

## Backlog de campo (próximos ajustes de UI/hardware)
- ✅ **Diagnóstico del energizador REAL** (2026-09-09). Ya no es demo: el
  instalador ingresa el **número de serie** y `POST /v1/instalador/energizador/
  diagnostico` lee la **telemetría real** del `Device`: conexión a línea
  (`ac_power_on` = energía de la calle), batería (`battery_state`/voltaje) y
  cerca/alto voltaje (`armed_status`). La **tierra física** = confirmación manual
  del instalador (sin telemetría). La vinculación guarda `x_numero_serie` +
  `x_mac_address` en Odoo. Probado contra el equipo `OHM-CARLOS-DEV` (todo verde).
- 🟡 **Dashboard — registro del equipo al cliente**. El estatus del equipo YA
  aparece en el dashboard (reporta telemetría). Falta el **"registro"**: asociar
  el `Device` al cliente/propiedad de la instalación (`DeviceAccess`) al cerrar.
  A definir el flujo (hoy la asociación cliente↔equipo vive en el onboarding).
- ⬜ **Cierre de instalación — fotos de evidencia**: revisar **cantidad y estilo**
  de cada foto (categorías, orden, obligatoriedad, guías de encuadre). A definir
  con Operaciones.

## Pendientes priorizados
0. ⬜ **Módulos del home ocultos en el MVP (2026-09-18)** — el home solo muestra
   *Instalaciones* y *Reportar incidencias*. Quedan comentados en
   `lib/screens/home_screen.dart` para construirse uno a uno en la siguiente versión:
   - **Reparaciones** (la pantalla `reparaciones_screen.dart` y las tarifas ya existen;
     falta cerrar el flujo E2E y el cobro).
   - **Mantenimientos** (sin pantalla; solo "próximamente").
   - **Reemplazo de equipo** (sin pantalla; solo "próximamente").
   - *Reportar incidencias* — ✅ HECHO 2026-09-25 (fase 4, Helpdesk). *Mantenimientos* — ✅ lista de intervenciones de mantenimiento.
1. ✅ **Sesión persistente y biometría nivel A (2026-09-27)** — refresh rotado en Keychain/Keystore, refresco automático ante 401, Face ID al arrancar y tras 15 min en segundo plano, invitación tras el primer inicio, Perfil › Seguridad. Nivel B (secreto protegido por el SO) y «Dispositivos con sesión» quedan para la siguiente versión.
1. 🟡 **Probar el push en un teléfono** (Android primero) — cierra el ciclo.
2. 🟡 **HubSpot**: pegar la acción de webhook en el workflow (tiempo real).
3. ⬜ **iOS**: APNs Auth Key en Firebase.
4. ✅ **Fase 4** (postventa) y **Fase 5** (dinero) — ver `ROADMAP-ODOO-SERVICIO.md`.
5. 🟡 **Bono Capa B**: atribución hecha (cotizaciones desde la app); falta la comisión.
6. ⬜ **Publicación**: TestFlight/Play con el bundle `com.ohmsafe.instalador`.

## Estado E2E — 2026-09-14 (simulador iOS, ticket 43 "Carlos M TestFlight")

**Verificado contra Odoo (con auditoría en el chatter):** iniciar ruta → *En ruta*; marcar llegada → *En sitio*; perímetro → *En proceso* con `x_obstaculos_perimetro=["Vegetación","Árboles"]`; materiales → `x_materiales_instalados` completo. El calendario coloca la instalación en su fecha agendada (17/09 08:00).

**Paso 4 (energizador):** pantalla corregida (b26e3fe) validada con la serie real `003` (equipo sin reportar desde julio): ya no declara "Vinculación exitosa" sin equipo; muestra "Diagnóstico del equipo", pruebas con telemetría real y una tarjeta con serie/MAC/cerca/en línea/firmware/último reporte (se quitaron "Wi-Fi" y "SIM", que eran texto fijo sin dato detrás). **Pendiente:** pasada completa con un equipo en verde (`OHM-CARLOS-DEV`) y paso 5 (cierre).

**Backend:** `writeTaskAvanzando` (Back- 341df44): las etapas solo avanzan; re-tocar pasos tras reabrir la app ya no rebobina el ticket ni pisa `x_hora_*`. Verificado desde la app: `iniciar-ruta`/`marcar-llegada` sobre *En proceso* no escriben nada; `inspeccion`/`instalacion` reescriben datos sin mover la etapa.

**Bloqueos para un E2E real en campo (decisión pendiente):**
1. Token de sesión de **15 min** sin refresco (el `refreshToken` del login no se persiste ni hay endpoint); el 401 se muestra como aviso fugaz y la app no lleva al login. Una instalación dura horas.
2. La app **no retoma** desde la etapa de Odoo: siempre arranca en el paso 1 (`_stepNCompleted` en memoria). Con 1) obliga a rehacer pasos a mitad de trabajo.
3. `_allCompleted` no exige `enLinea`: telemetría de días atrás pasa las pruebas.
4. UX: "Cancelar instalación" pegado bajo el CTA primario en tres pantallas (mismo ancho) — riesgo de cancelar por error.
