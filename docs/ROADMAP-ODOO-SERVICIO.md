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

## Fase 1 — HECHA y verificada en Odoo (2026-09-25)

Todo aditivo e idempotente, ejecutado por RPC (guiones en la sesión). Lo que quedó:

| Pieza | Registro en Odoo |
|---|---|
| Tipo de habilidad «Servicio OhmSafe» | `hr.skill.type` 6; habilidades 43-47; niveles Básico/Competente/Experto 26-28 |
| Empleado del instalador de prueba | `hr.employee` 15 «Juan Mora Test» (contacto 106), rol Instalador OhmSafe Externo, 4 habilidades |
| Productos que crean intervención | `product.template` 48 SRV-INSTALACION, 49 SRV-REPARACION, 50 SRV-REEMPLAZO; 32 Mantenimiento preventivo anual y 23 Visita/diagnóstico habilitados |
| Ubicación van | `stock.location` 27 «WH/Stock/Van Juan Mora Test» |
| Módulo instalado | **Field Service Reports** (`planning_field_service_worksheet` + `worksheet` + `planning_field_service_sale_worksheet`) |
| Hoja de trabajo | `worksheet.template` 2 «Instalación de cerca eléctrica» (16 campos, 3 separadores); por defecto en los 5 productos de servicio y en las 4 plantillas de turno |
| Plantillas de turno | `planning.slot.template` 1 «9 - 17» (instalación, jornada de 8 h); su chip dice «9 - 17 Instalador OhmSafe Externo [Instalación de cerca eléctrica]» porque Odoo lo arma con horario + rol + hoja de trabajo (el nombre de la plantilla no se muestra), por eso la hoja 2 se renombró el 2026-09-26 de «Instalación OhmSafe» a «Instalación de cerca eléctrica». Las de reparación, mantenimiento y reemplazo (2-4) se borraron el 2026-09-26: el chip de Odoo sólo muestra horario + rol + hoja y se veían iguales. Se crean de nuevo, cada una con su propia hoja de trabajo, al construir el proceso de cada módulo |
| Automatizaciones (APAGADAS) | `base.automation` 10/11/12 → acciones webhook 1306/1307/1308 (`/v1/instalador/webhooks/intervencion/asignacion|agenda|estado`) |
| Prueba E2E | venta S00152 → intervención 2: asignada, programada, sign in, hoja llena, 4 fotos, firma, completada, **reporte PDF enviado al cliente** (adjunto 3045, notificación `sent`) |

**Pendiente de decisión (Carlos):** el usuario de API dedicado es un usuario interno y
**cuesta una licencia**; hasta decidirlo el backend sigue entrando como admin.

### Lo que aprendimos del RPC (vale para la fase 2)

- Al confirmar la venta nace un turno «por planificar» (sin fechas). **Escribirle fechas o
  técnico por RPC no funciona**: la intervención real se crea con
  `planning.slot.create({sale_line_id, partner_id, role_id, start/end_datetime,
  employee_ids})` pasando el contexto `default_start_datetime/default_end_datetime`,
  como hace el Gantt.
- El técnico se asigna por **`resource_ids`** (recurso del empleado); `employee_ids` es
  calculado y se ignora al escribir.
- `action_planning_publish_and_send` (Programada + correo al cliente), `action_sign_in`
  (En curso), `action_complete` (Completada) y `action_send_report` (abre el compositor
  con la plantilla 74) son públicos. Para enviar sin interfaz: `mail.compose.message`
  con `composition_mode=comment`, `template_id=74`, `partner_ids` y `action_send_mail`
  ⇒ mensaje en el chatter con el PDF y notificación `sent`.
  `mail.template.send_mail` también envía pero **no deja rastro en el chatter**.
- El reporte exige horas, productos **u hoja de trabajo**: las propiedades del rol NO
  cuentan; hace falta el módulo Field Service Reports y `worksheet_template_id` +
  `worksheet_properties` en la intervención. Los separadores necesitan
  `fold_by_default` o el reporte falla.
- Fotos: adjuntos `ir.attachment` (`res_model=planning.slot`) escritos con **`raw`
  en base64** (`datas` se ignora y deja el archivo vacío) y con
  **`generate_access_token`**: el reporte los incrusta por `/web/image/<id>?access_token=`
  y sin token salen iconos vacíos. La intervención los expone en `photo_ids`.
- Firma: `worksheet_signature` (PNG base64) + `worksheet_signed_by`. El portal ofrece
  «Sign Report» al cliente como alternativa.
- Los adjuntos se leen con `raw` (llega base64 en texto), no con `datas`.

## Fase 2 — HECHA en el backend (2026-09-25)

`Back-` `src/domains/field-service/intervencion.service.ts` + despacho en `routes.ts`
(doc `docs/field-service.md` §«Fase 2»). Ids `i<n>`; unión de fuentes en lista,
historial y notificaciones; webhooks `/webhooks/intervencion/*`; marcadores operativos
`op_*` como propiedades de los roles 1 y 2 (fase 1 extendida). Reparación en sitio deja
el desglose en el chatter hasta la fase 5. Pendiente: encender las automatizaciones 10/11/12
tras desplegar y probar E2E por HTTP.

### Fase 2 — VERIFICADA de punta a punta por HTTP (2026-09-25, Back- `652c792`, api-dev)

Venta S00154 → intervención 6 (asignada a Juan Mora Test) → app por HTTP con sesión de
instalador: lista (`i6`, paso `iniciar_ruta`) → iniciar ruta → llegada (`sign in`) →
inspección → instalación → vinculación (Device creado por la serie + línea de material
«Energizador» con lote y `picked`) → 4 fotos → cierre con firma → `action_complete` →
**reporte PDF enviado** (`/web/content/3057`) → historial. Avisos: «Nueva instalación
asignada» (push 2/2) y «Servicio agendado» en la campana; webhooks 10/11/12 **encendidos**
(con `?token=` en la URL, como los de las tareas).

Lo que se corrigió sobre la marcha (queda en el código y en `docs/field-service.md`):
- `planning.slot` **no tiene `active`** (no se archiva): la cancelación desde la app es el
  marcador `op_cancelada` + motivo en el chatter.
- Un turno creado a mano nace con la «Default Worksheet» vacía: el backend cambia a la
  hoja «Instalación de cerca eléctrica» si la actual no tiene campos.
- `sign in`/`complete` reescriben `start_datetime` con la hora real ⇒ la automatización de
  agenda dispararía un falso «reagendado»; se ignora en `in_progress`/`completed`.
- Completar exige la serie en la entrega **y `picked=true`** en la línea de movimiento.
- Una serie sólo se entrega una vez: repetir una prueba con la misma serie da «ya había
  sido asignado». Es Odoo haciendo su trabajo.
- Los datos de prueba: SO S00152/S00153/S00154, intervenciones 2/4/6, Device
  `TEST-INST-0006` creado en el backend de dev.

**Pendiente de decisión (fase 3):** cuando operaciones asigna al técnico después de
programar, el aviso es «asignada» con la fecha; «agendado» aparte sólo si la fecha llega
después. La app de hoy ya lee intervenciones sin cambios; la fase 3 la adapta a la hoja de
trabajo y retira pdfkit/S3/`x_`.

## Fase 3 — HECHA y verificada (2026-09-25, app `626f850`+, backend `Back-` fase 3a, build 11)

La app ya opera intervenciones con sus particularidades:
- **Orden**: `origen`, `ordenVenta` y `hojaTrabajo` (aditivos). El detalle muestra la orden de
  venta y, en cuanto se registra algo en sitio, la hoja de trabajo tal como está en Odoo.
- **Geolocalización real (pendiente 2, cerrado):** la llegada manda la posición del teléfono
  (referencia); el cierre manda la suya y el backend compara: a más de **300 m** responde
  `409 FUERA_DE_SITIO {distanciaM}` y la app muestra «Estás lejos del sitio» con la
  distancia; confirmar reenvía con `confirmarUbicacion` y deja nota en el chatter. Se
  retiró la geolocalización falsa del cierre (posiciones inventadas de CDMX y referencia
  fija): la app **nunca inventa una posición**; sin GPS manda la petición sin ubicación.
- `ServerFailure` trae `code` y `details`, así la app puede reaccionar a códigos del backend.
- E2E por HTTP sobre S00155 / intervención 8: rechazo a 1,112 m, cierre confirmado →
  completada + reporte 3063 enviado.

**Lo que NO se retiró todavía (a propósito):** pdfkit, la evidencia en S3 y los campos
`x_` siguen sirviendo a las 29 tareas viejas hasta que se cierren; se retiran en la fase
6 al archivar el proyecto. Los módulos ocultos del home y «Reportar incidencias» siguen
como estaban: los cubre la fase 4 (Helpdesk, Mantenimiento, Encuestas, Citas).

## Fase 4 — HECHA y verificada (2026-09-25, backend `96eb27c`, app fase 4, build 12)

| Pendiente original | Cómo quedó |
|---|---|
| Reportar incidencias | **Helpdesk**: equipo «Incidencias de campo» (id 5), etiquetas por tipo, prioridad (riesgo = urgente), propiedades `intervencion/instalador/ubicacion`, foto, instalador suscrito, nota en la orden. App: módulo Incidencias (lista + reporte). Operaciones convierte en intervención desde el ticket (puente instalado) |
| Mantenimientos | **Mantenimiento**: al vincular, equipo por serie (categoría «Energizador OhmSafe», cliente) + solicitud preventiva anual recurrente (equipo «Servicio OhmSafe»). App: tile Mantenimientos = intervenciones de mantenimiento |
| Encuesta y ranking (fase 5 original) | **Encuestas**: «Satisfacción del servicio OhmSafe» (escala 1-5, recomendaría, comentario) enviada al cerrar; `perfil.calificacion` real (null sin respuestas). Adiós al 4.7 fijo |
| Disponibilidad del cliente (pendiente 3) | **Citas**: tipo «Visita de instalación OhmSafe» por recursos (Juan Mora Test, lun-sáb 9-13/14-18). La reserva la convierte operaciones en intervención; la automatización cita→intervención queda para después |

E2E por HTTP (S00156 / intervención 10): incidencia #1 en Helpdesk con orden ligada; equipo
`TEST-INST-0010` y preventivo al 2027-09-25 en Mantenimiento; encuesta enviada al cliente y,
contestada con 5, `perfil.calificacion = 5.0 (1)`.

Trampas: la definición de propiedades del ticket vive en `helpdesk.team.ticket_properties`;
`survey.invite` + `action_invite` deja el `survey.user_input` que se guarda en
`op_encuesta_id`; la encuesta se contesta desde el correo del cliente.

## Fase 5 — HECHA y verificada (2026-09-25, backend `2ba2797`, app fase 5, build 13)

| Pendiente original | Cómo quedó |
|---|---|
| Facturación por intervención | **Contabilidad**: al cerrar, factura al cliente en borrador desde la orden de venta (`sale.advance.payment.inv` método `delivered`), sólo si la orden está confirmada y tiene algo por facturar; `op_factura_id`. Operaciones valida y cobra; el portal ya tiene Stripe (proveedor 18) |
| Pago al instalador | **Compras**: factura de proveedor en borrador al contacto del instalador con el producto «Pago a instalador — Instalación/Reparación/Mantenimiento/Reemplazo» (`PAGO-*`, categoría «Pagos a instaladores», ids 51-54); importe = costo del producto (hoy 0: **Carlos lo fija en Odoo**; mientras, la factura lleva la nota «Sin tarifa configurada»); `op_pago_instalador_id`. App: Perfil › **Mis pagos** (totales pagado / por pagar / en revisión + lista) |
| Venta en campo | **Ventas**: `GET /catalogo` (productos etiquetados «App instalador», tag id 1; hoy MO-ENERG-BAT, MO-ENERG-SIMPLE, MO-MTTO-ANUAL, OS-SUB-HOGAR-MEN; los SRV-* etiquetados pero sin precio) y `POST /cotizaciones`: contacto por correo, orden en borrador con atribución `source_id` «App instalador» (15) / `medium_id` «Venta en campo» (6) / `origin` «App instalador · <código de venta>», enviada con la plantilla nativa (48) → estado `sent`; el cliente paga desde `urlPortal`. App: tile **Cotizar venta** (lista + formulario con catálogo y cantidades; copiar/abrir enlace) |
| Reparaciones | Siguen siendo intervenciones con producto SRV-REPARACION; el tile del home sigue oculto hasta cerrar su flujo E2E |
| PoS | No: no habrá efectivo por ahora |

E2E por HTTP (S00157 / intervención 12): al cerrar quedaron la factura al cliente 223 (borrador,
$1.16 de prueba) y la factura de proveedor 224 (borrador, Juan Mora Test, $0 con nota de tarifa);
`GET /pagos` la lista como «En revisión». Cotización S00158 para «Ana Prueba F5» con UTM y código
OHMS-JUAN19, correo enviado (estado `enviada`) y enlace de portal.

Decisiones que quedan para Carlos: (1) costo de los productos `PAGO-*`; (2) precio de los SRV-*
si se quieren cotizar desde la app; (3) qué más etiquetar como «App instalador»; (4) comisión del
instalador por cotización vendida (hoy sólo atribución). Nada de esto va a HubSpot.

## Fase 6 — HECHA (2026-09-26, backend `ad37681`; sin build de app)

| Pendiente original | Cómo quedó |
|---|---|
| Origen de la instalación | **La venta pagada en Stripe** (aviso del cobro → `/v1/ventas/webhooks/venta-confirmada`): cliente + casa + contrato con la línea SRV-INSTALACION a $0 → Odoo crea sola la intervención «por planificar» (sin instalador) → actividad «Agendar intervención» (tipo 16) al usuario de operaciones (`VENTAS_OPERACIONES_LOGIN`). Operaciones la arrastra al calendario del instalador en Planificación y publica → push «Servicio agendado» → app. Al asignar, la actividad se cierra sola |
| Odoo de producción | `setup-odoo-sitios.mjs --apply --yes-production` aplicado en **ohmsafe2** (campos Stripe/HubSpot, catálogo de planes con precio de Stripe, planes a 36 meses, diario Stripe, RFC). La copia `ohmsafe2-test` ya no se usa |
| Flujo viejo | Timer del espejo HubSpot→tareas apagado; automatizaciones 4/5/9 inactivas; tareas reales 38/39/40 migradas a contratos S00162–S00164 (intervenciones 16–18 por planificar con actividad); proyecto «Instalaciones OhmSafe» **archivado**. Los 60 campos `x_` se borran ~2026-10-26 |
| Seguridad | Token de webhooks rotado (estaba en claro en logs del 7-11 sep); `ohmsafe-test-device` apagado; HubSpot en dev bloqueado a lectura por código |
| Foto del instalador | Va también a la ficha de empleado (Planificación la muestra) |

E2E: venta simulada → S00161 → i14 por planificar + actividad a Carlos (vence 29 sep) → agendada
a Juan Mora 27 sep 10:00 → i15 publicada → push «Servicio agendado» + app con fecha y paso
*Iniciar ruta*. Manual para operaciones: `MANUAL-OPERACION-ODOO.md` › «Flujo vigente».

Quedan: sesión nivel B y «Dispositivos con sesión», push en Android real, retirar del backend el
código de `project.task` (sin emisor), poner a Santiago en `VENTAS_OPERACIONES_LOGIN` al salir de
pruebas, y que Carlos pruebe el arrastre real en el Gantt (mi emulación por RPC borró el slot «por
planificar» sobrante y eso mandó un push «Servicio cancelado»; la interfaz lo consume sola).
