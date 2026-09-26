# Roadmap E2E — Plataforma de Instaladores en Odoo

Objetivo: darle a **Operaciones de OhmSafe** una plataforma en **Odoo** (`ohmsafe2`)
para operar, administrar y dar seguimiento a todo el ciclo del instalador externo —
desde que entra como prospecto hasta que se le paga — con la **app de instaladores**
como su herramienta de campo. Odoo es la fuente de verdad de la operación.

> Base técnica: `project.task` (el módulo Field Service `industry_fsm` NO está
> disponible en ohmsafe2, por eso project.task es la decisión correcta). Se apoya
> en módulos nativos ya instalados: **Sign, Survey, Accounting/Purchase, CRM, HR**.
> El backend `/v1/instalador/*` (dominio field-service) es el puente app↔Odoo.

## Decisiones tomadas (2026-09-06)
- **Instalador = PROVEEDOR** en Odoo (cuentas por pagar), separado de clientes
  residenciales (cliente = *customer*; instalador = *vendor* + etiqueta
  "Instalador Externo-OS" + usuario portal). Excepción acordada a la regla de
  "no tocar Facturación": el **pago a instaladores** (cuentas por pagar) sí se
  maneja en Odoo; la facturación a clientes/CFDI no se toca.
- **Lead** del instalador en el **CRM de Odoo** (pipeline de reclutamiento).
- **Onboarding desde la app**: crear contraseña + completar perfil + subir
  constancia fiscal/RFC/CURP.
- **Invitación MANUAL por Operaciones** tras validar capacidad técnica y
  conocimiento del candidato (NO automática al ganar el lead). Canal: **email**
  para arrancar; WhatsApp después (proyecto comms).
- **Firma** de recibido: se **captura en la app** y se genera un **Acta de
  recibido (PDF)** adjunta al ticket. NO se usa el módulo Sign para esto (Sign es
  para firma remota por email/portal; la firma del cliente es presencial en campo).
- **Encuesta + ranking**: Odoo **Survey** al cerrar; el instalador **solo ve su
  ranking (1-5) en la app**, nunca la encuesta; las respuestas de encuesta solo
  las ve el **director de Operaciones en Odoo**. Se migran las preguntas de la
  encuesta de HubSpot, incluida su regla de **reenvío una vez si no se contesta**.
- **Pago**: monto **propuesto = tarifario**, con **ajuste manual + motivo** en la
  validación de campo (ej. tarifa $1000 → pagar $1500 por algo no previsto).
  Corte **viernes**, acumulado semanal por instalador.
- **Panel de Operaciones**: **nativo dedicado** en Odoo.

## Transición HubSpot → Odoo (patrón "strangler")
Hoy el ticket de instalación se crea en **HubSpot** al recibir el pago de Stripe.
Meta: Odoo como padre, sin romper a Operaciones.
1. **Doble creación**: el evento de pago crea también el ticket en Odoo (ligado
   por `external_id` al de HubSpot, para no duplicar esfuerzo).
2. **Doble corrida**: Operaciones opera las nuevas instalaciones en Odoo + app;
   HubSpot queda de respaldo/lectura.
3. **Banderazo (feature flag)**: validado, el pago crea el ticket **solo en Odoo**
   y se apaga el de HubSpot. Odoo = padre.
4. **Espejo temporal** Odoo↔HubSpot con el motor de sync mientras se necesite;
   luego se desconecta.

### Import de histórico (recomendación)
Import **dirigido**, NO todo el CRM:
- Solo **clientes con instalación** + sus **instalaciones cerradas** → `project.task`
  histórico. Preservar antigüedad en `x_alta_hubspot` (la fecha de creación de
  Odoo es automática).
- Ventana: **últimos 12 meses** (ampliable).
- **Idempotente por `external_id`**, con **dry-run** previo.

## Fases (resolver una a una)

### Fase 1 — Onboarding del instalador  🔴 (empezar por aquí)
Pasos 0-4. Sin instaladores bien dados de alta, nada de lo demás es real.
- **Lead** (CRM Odoo, pipeline "Reclutamiento Instaladores OS-Ext") con correo/nombre/apellidos/teléfono.
- Operaciones **valida capacidad técnica y conocimiento** del candidato a lo largo del pipeline.
- **Cuando Operaciones decide** (NO automático al ganar el lead): da de alta al
  **Instalador externo** = `res.partner` (vendor + etiqueta) + **usuario portal**, y
  **envía la invitación a mano** (descargar la app + activar cuenta). Email ahora, WhatsApp después.
- En la **app**: el instalador **crea su contraseña**, **completa perfil** y **sube
  constancia fiscal (PDF) + RFC + CURP**. → estado **"activo"** (disponible para asignación).
- Nuevo: pantallas de perfil/onboarding en la app, endpoints de perfil + subida a
  **S3**, campos Odoo (`x_rfc`, `x_curp`, `x_constancia_url`, `x_estado_instalador`),
  flujo set-password contra Odoo.

### Fase 2 — Origen y asignación del ticket  🟡
Pasos 5-6 + transición + import.
- Stripe (plan pagado) → **ticket de instalación en Odoo** (doble creación / banderazo).
- Operaciones **asigna** al instalador (`x_instalador_id`) → se refleja en su app
  (ya funciona: cada instalador solo ve lo suyo).
- **Import de histórico** de HubSpot (ver arriba).

### Fase 3 — Ejecución con control de pasos + firma  🟡
Paso 7.
- **No saltarse pasos**: el backend valida la secuencia (llegada → inspección →
  instalación/reparación → energizador → cierre); no permite cerrar sin los previos.
- Gate **"sistema activo"** antes del cierre.
- **Firma**: captura en la app → **Acta de recibido (PDF)** adjunta al `project.task`
  + bandera `x_firmado`, nombre y fecha del firmante.
- (Base ya hecha: los writes por paso existen en el dominio field-service.)

### Fase 4 — Cierre, historial y PANEL DE OPERACIONES  🟡 (objetivo central)
Paso 8 + el objetivo de Operaciones.
- Historial en Odoo (etapa Completada) y en la app (sección Historial) — ya existe.
- **Panel nativo dedicado** en Odoo para Operaciones: seguimiento por instalador,
  **cancelaciones a tiempo** y **motivo/problemas** de cada instalación, tiempos por etapa.
- Mayormente configuración de vistas/kanban/pivot/tableros nativos + los campos de
  cancelación/anomalías que ya existen.

### Fase 5 — Encuesta de satisfacción + ranking  🔴
Paso 10.
- **Odoo Survey** disparada al **cerrar** el ticket, con **reenvío una vez si no se
  contesta** (regla migrada del workflow de HubSpot).
- Respuesta → **calificación 1-5** → **ranking por instalador** (promedio en
  `x_calificacion`).
- Visibilidad: instalador **solo su ranking en la app**; encuestas solo Operaciones en Odoo.
- Pendiente al construir: **extraer las preguntas exactas** de la encuesta de HubSpot
  (portal 50554173) y replicarlas en la Survey de Odoo.

### Fase 6 — Pago al instalador  🔴
Pasos 9, 11.
- Al **cerrar** el ticket → se genera la **cuenta por pagar** al instalador (como
  **proveedor**): monto **propuesto del tarifario**, **ajustable + motivo** en validación.
- **Corte viernes**: acumulado semanal por instalador → **lote de pago** (vendor
  bills / pago de proveedor en Odoo Accounting).
- **Reflejo del estado de pago** en la app del instalador (`x_pago_estado`) y en los
  controles de Operaciones.

## Dependencias / orden recomendado
`Fase 1 → Fase 2 → Fase 3 → Fase 4 → Fase 5 → Fase 6`.
Las fases 3-4 ya tienen base (dominio field-service + app). El pago (6) y la encuesta
(5) son aditivos que cierran el círculo E2E: **ingreso de la persona → pago de la persona**.

## Notas de implementación (buenas prácticas)
- **Prod solo desde git** (ver [[ohmsafe-git-prod-discipline]]); nada a mano en la caja.
- Cada fase: **documentar** su doc en `docs/`, **comentar** funciones, y **actualizar
  el Manual de operación** (artifact "Ruta del Ticket en Odoo") con los nuevos rastros
  en Odoo, a medida que se construye y prueba.
- Odoo: additive (no borrar), sync del poller apagado donde aplique.
