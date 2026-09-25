# Roadmap: operación de servicio sobre Planificación de Odoo

**Fecha:** 2026-09-25 · **Base:** `ARQUITECTURA-ODOO-SERVICIO.md` (diagnóstico) ·
**Alcance:** de las decisiones de arquitectura a lo particular (la firma), sin parar la
app que ya usan los instaladores. Los pendientes de la app (incidencias,
geolocalización, disponibilidad, módulos ocultos, fases 4-5, sesión nivel B, limpieza)
quedan **absorbidos** en las fases 4 a 6; no se construyen aparte.

## Principios que ordenan todo (fase 0)

1. **Una verdad por dominio.** Odoo: operación de servicio, inventario, facturación.
   Backend: equipo (serie, MAC, telemetría), accesos, casa, sesión de la app. HubSpot:
   CRM espejo. Stripe: cobro.
2. **La intervención (`planning.slot`) es la unidad de trabajo.** Instalación,
   reparación, mantenimiento y reemplazo son intervenciones con distinta plantilla de
   turno y hoja de trabajo. Se acaba `project.task` para servicio.
3. **La serie del equipo es la llave** entre Odoo (lote/serie en Inventario) y el
   backend (`Device.serialNumber`).
4. **El instalador es empleado** (`hr.employee`, sin licencia) con rol y habilidades;
   sigue entrando a la app con su usuario externo; el backend hace el mapeo.
5. **Nativo antes que propio:** propiedades en vez de Studio; hoja de trabajo, firma,
   reporte y correo de Odoo en vez de pdfkit y S3; SMS/WhatsApp de Odoo al cliente;
   automatizaciones sobre campos nativos.
6. **Usuario de API dedicado y mínimo** para el backend (hoy entra como admin).
7. **Ids, nunca nombres.** Ya es regla.

Entregable de la fase 0: este documento aprobado por Carlos y validado con el equipo de
Odoo en una sesión (30 min): rol vs. plantilla de hoja, almacén por instalador,
producto de servicio que crea intervención.

## Fases

| # | Fase | Qué se construye | Dónde | Cierra pendientes | Esfuerzo |
|---|---|---|---|---|---|
| 0 | Decisiones | los 7 principios, apps sí/no (Reparaciones: no aún; PoS: después) | doc + reunión | — | 1 día |
| 1 | Cimientos en Odoo | configuración, sin código | Odoo | — | 2-3 días |
| 2 | Backend puente | `/v1/instalador/*` sobre intervenciones, doble lectura | backend | — | 3-4 días |
| 3 | App sobre la intervención | flujo nativo de campo, firma y reporte | app + backend | geolocalización | 4-5 días |
| 4 | Postventa nativa | Helpdesk, Mantenimiento, Encuestas, Citas | Odoo + app | incidencias, disponibilidad, mantenimientos, encuesta/ranking | 4-5 días |
| 5 | Dinero | facturación por intervención, pago al instalador, venta en campo | Odoo + backend + app | pago al instalador, reparaciones (cobro), venta directa | 4-6 días |
| 6 | Limpieza y siguiente nivel | retirar lo viejo; sesión nivel B; dispositivos con sesión | todo | sesión nivel B, limpieza, Android | 2-3 días |

Dependencias: 1 → 2 → 3 en serie. 4 y 5 pueden ir en paralelo tras 3. 6 al final.

### Fase 1 — Cimientos en Odoo (sin código)

1. **Usuario de API** «OhmSafe Backend» con sólo Planificación, Ventas, Inventario,
   Contactos, Helpdesk. Rotar la clave; el backend deja de usar el admin.
2. **Personas:** cada instalador como empleado ligado a su contacto; rol «Instalador
   OhmSafe Externo/Interno»; habilidades (cerca, cámaras, sensores, altura). Juan Mora
   Test como piloto.
3. **Catálogo de servicio:** productos «Instalación», «Reparación», «Mantenimiento»,
   «Reemplazo de equipo» tipo servicio, con **plantilla de turno** y rol, configurados
   para **crear la intervención al confirmar la venta**. Los productos físicos
   (energizador, sensores, cámaras) con **seguimiento por serie**.
4. **Inventario:** almacén central + una ubicación «Van de <instalador>» por
   instalador; ruta de reposición con Compras. Serie del energizador = la de fábrica.
5. **Hoja de trabajo de instalación** como propiedades del rol (separadores
   Inspección / Instalación / Entrega; ver §6 del diagnóstico). Después, si hace falta
   una hoja distinta por tipo de servicio, instalar «Field Service Reports».
6. **Reporte y correo:** personalizar el «Field Service Report» (logo, texto de
   conformidad, ocultar precios) y la plantilla de correo al cliente.
7. **Automatizaciones** sobre la intervención → webhooks del backend: asignación
   (`employee_ids`), agenda/reagenda (`start_datetime`), cambio de estado
   (`state`), cancelación. Sustituyen a las que hoy miran `x_instalador_id` y
   `x_fecha_agendada`.
8. **Prueba manual en Odoo:** venta → intervención → asignar → sign in → hoja →
   firma → complete → reporte al correo. Sin la app.

### Fase 2 — Backend puente (doble lectura)

- `ordenes` lee `planning.slot` (nuevas) y `project.task` (las 29 viejas, hasta que
  se cierren). Mapeo de estados: Draft/Scheduled → por hacer; In Progress → en curso;
  Completed → completo; cancelación → cancelado.
- Login: partner del usuario externo → empleado → sus intervenciones.
- Endpoints nuevos: iniciar (sign in), completar, propiedades de la hoja, materiales
  con serie, adjuntos, firma, enviar reporte. Contrato en `CONTRATO-API-instalador.md`.
- Webhooks nuevos con el mismo token y `compareToken`.

### Fase 3 — La app sobre la intervención

| Paso de la app | Hoy | Con Planificación |
|---|---|---|
| Iniciar ruta | `x_hora_salida_tecnico` | `action_sign_in` (geolocalización al chatter) |
| Marcar llegada | `x_hora_llegada` | segunda marca de geolocalización + estado En curso |
| Inspección / instalación | campos `x_` | propiedades de la hoja de trabajo |
| Vincular equipo | `x_mac_address` + Device | línea de material con **serie** → baja de stock; el backend crea/liga el Device por esa serie |
| Fotos | S3 + PDF propio | adjuntos de la intervención |
| Firma | PNG → `x_firma_url` | `worksheet_signature` + `worksheet_signed_by` |
| Cierre | `guardarCierre` + pdfkit + correo propio | `action_complete` → `action_send_report` (PDF y correo de Odoo) |

Se retiran pdfkit, `orden-servicio.ts`, la evidencia en S3 y los `x_` del cierre.
Geolocalización al cerrar: radio contra la dirección de la intervención (pendiente 2).
Build a TestFlight al terminar.

### Fase 4 — Postventa nativa

- **Reportar incidencias** = ticket de Helpdesk desde la app (tipo, foto, ubicación);
  el puente instalado lo convierte en intervención cuando toca visita.
- **Mantenimientos** = planes de Mantenimiento por equipo que generan intervenciones.
- **Encuestas** al completar → calificación real del instalador (adiós al 4.7 fijo).
- **Citas**: disponibilidad del cliente ligada al calendario del instalador
  (pendiente 3); la agenda se confirma desde Planificación.
- Los módulos ocultos del home vuelven como listas de intervenciones por tipo.

### Fase 5 — Dinero

- Facturación por intervención: tiempo y materiales o precio cerrado según el producto.
- Pago al instalador: partes de horas por intervención completada → base del pago
  (fase 4 original); el mecanismo de pago se decide con contabilidad.
- Venta en campo: cotización desde la app + enlace de pago Stripe. PoS sólo si habrá
  efectivo.
- Reparaciones: como intervención con materiales; `repair` sólo si hay taller.

### Fase 6 — Limpieza y siguiente nivel

Archivar el proyecto «Instalaciones OhmSafe», borrar automatizaciones y campos `x_`
viejos, actualizar docs. Sesión nivel B, «Dispositivos con sesión», rotación del token
de webhooks, token HubSpot de sólo lectura, apagar `ohmsafe-test-device`, push en
Android real.

## Lo particular: la firma, de punta a punta

1. **Qué firma el cliente.** Dos cosas distintas: el **contrato** (una vez, con la app
   Firma de Odoo, antes de instalar) y la **conformidad del servicio** (en cada
   intervención, en la hoja de trabajo). No mezclarlas.
2. **Dónde vive.** `planning.slot.worksheet_signature` (imagen) y
   `worksheet_signed_by` (nombre). Nada en S3, nada en `x_`.
3. **Cómo se captura en la app.** El lienzo que ya tenemos genera el PNG; el backend
   lo escribe con `write` en esos dos campos, validando tipo y tamaño como hoy
   (`adjuntarFirma`). Alternativa sin app: el cliente firma en el **portal** desde el
   enlace del correo.
4. **Qué la precede.** Sólo se puede firmar con la hoja completa: propiedades
   obligatorias llenas y las 4 fotos adjuntas. El backend lo valida antes de aceptar
   la firma (misma regla que hoy `FIRMA_REQUERIDA`, al revés).
5. **Qué dispara.** Firma guardada → `action_complete` (estado Completada, horas al
   parte) → `action_send_report` (PDF con checklist, fotos y firma, adjunto a la
   intervención y enviado al correo del cliente). Automatización de Odoo al pasar a
   Completada como respaldo si el backend no llamó al envío.
6. **Qué ve cada quien.** El instalador: intervención completada en su lista. El
   cliente: correo con el reporte. Operaciones: el PDF en la intervención y en el
   contacto; la encuesta sale después (fase 4).
7. **Qué se verifica.** Firma rechazada sin hoja completa; PDF con las 4 fotos y el
   nombre del firmante; reporte en el chatter del contacto; correo entregado; la
   intervención no se puede editar tras completar.

## Orden de trabajo propuesto

Semana 1: fase 0 + fase 1 (dejo Odoo configurado y una intervención de prueba
completa para que la veas). Semana 2: fase 2. Semana 3: fase 3 y build a TestFlight.
Después, 4 y 5 en paralelo, y 6 para cerrar.
