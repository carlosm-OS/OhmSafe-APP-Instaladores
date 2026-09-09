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

## Fases 4–5 — Pago al instalador y encuesta/ranking  ⬜
- ⬜ **Pago (cuentas por pagar)**: al cerrar, abrir el flujo de pago al instalador
  (proveedor), corte de viernes. Pendiente de construir.
- ⬜ **Encuesta + ranking** (estilo Uber): migrar preguntas desde HubSpot; el
  instalador ve solo su ranking; Operaciones ve las encuestas. Pendiente.
- 🟡 **Bono por referidos (Capa B)**: el código de venta ya existe (Capa A). La
  atribución de ventas + cálculo del bono se acopla al puente Stripe→Odoo.

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
- ⬜ **Diagnóstico del energizador (real, no demo)**. Hoy las 4 pruebas de la
  pantalla de vinculación (tierra física, alto voltaje, batería auxiliar,
  verificación de conexión a línea) son **simuladas** (un timer cambia los
  estados). La **vinculación sí es real** (escribe MAC + `x_estado_vinculacion`
  en Odoo vía `vincularEnergizador`). Falta que el hardware reporte de verdad,
  en especial la **"Verificación de conexión a línea"**: validar si el equipo
  **recibe energía de la calle** (mains). Renombrada desde "Prueba de retorno"
  (2026-09-09).
- ⬜ **Cierre de instalación — fotos de evidencia**: revisar **cantidad y estilo**
  de cada foto (categorías, orden, obligatoriedad, guías de encuadre). A definir
  con Operaciones.

## Pendientes priorizados
1. 🟡 **Probar el push en un teléfono** (Android primero) — cierra el ciclo.
2. 🟡 **HubSpot**: pegar la acción de webhook en el workflow (tiempo real).
3. ⬜ **iOS**: APNs Auth Key en Firebase.
4. ⬜ **Fase 4** (pago al instalador) y **Fase 5** (encuesta + ranking).
5. ⬜ **Bono Capa B** (atribución de ventas), acoplado a Stripe→Odoo.
6. ⬜ **Publicación**: TestFlight/Play con el bundle `com.ohmsafe.instalador`.
