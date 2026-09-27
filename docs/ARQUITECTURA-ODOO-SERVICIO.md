# Arquitectura de servicio sobre las apps de Odoo — diagnóstico (2026-09-25)

Pedido de Carlos: el equipo de Odoo recomendó llevar la operación de instaladores de
**Proyecto** a **Planificación (Planning)**. Este documento verifica esa recomendación
contra la instancia real (`ohmsafe2.odoo.com`, saas~19.3.1.3) y la documentación de
Odoo 19, y propone la arquitectura objetivo y el camino para llegar sin parar la app.

## 1. Hallazgo clave: en 19.x Servicio de Campo YA vive dentro de Planificación

Con las versiones 19.1/19.2 Odoo retiró la app independiente *Field Service* y fundió
sus funciones en **Planning**. En tu base ya está instalado `planning_field_service`
(«Field Service — Plan intervention in planning») y sus puentes con Ventas+Inventario,
Ventas+Partes de horas, Suscripciones, SMS y Helpdesk. La recomendación del equipo de
Odoo no es una preferencia: es **la única app de servicio de campo que existe** en tu
versión.

Lo que el modelo `planning.slot` (una «intervención» = un turno) ya trae de fábrica y
hoy nosotros reinventamos con 61 campos `x_` sobre `project.task`:

| Necesidad OhmSafe | Hoy (Proyecto + campos x_) | Nativo en `planning.slot` |
|---|---|---|
| Cliente y dirección del sitio | `x_codigo_postal`, partner | `partner_id`, `partner_street/zip/city/phone` |
| Estado del servicio | 7 etapas propias (Por hacer → Completada) | `state`: Draft → Scheduled → In Progress → Completed |
| Instalador asignado | `x_instalador_id` (partner) | `employee_ids` (varios), `role_id` + habilidades (`planning_hr_skills`) |
| Agenda / reagenda | `x_fecha_agendada` + automatización + webhook | `start_datetime/end_datetime`, Gantt, calendario, mapa con ruta, plantillas de turno, recurrencia |
| Salida / llegada del técnico | `x_hora_salida_tecnico`, `x_hora_llegada` | Timer «Sign In / Complete» con **geolocalización en el chatter** |
| Evidencia fotográfica y checklist | campos `x_*` + S3 + PDF propio (pdfkit) | **Hoja de trabajo** (`slot_properties`, campos «propiedad», sin Studio) con fotos; reporte PDF nativo (`planning_field_service_worksheet`, **sin instalar**) |
| Firma del cliente | `x_firma_url` + adjunto | `worksheet_signature`, `worksheet_signed_by` |
| Materiales y equipo instalado | `x_materiales_instalados` (JSON), `x_mac_address` | líneas de material → **movimientos de inventario automáticos** (`planning_field_service_sale_stock`, instalado) y a la factura; palanca «en garantía» |
| Tiempo trabajado | `x_hora_*` | `intervention_timesheet_ids` → facturable |
| Venta que origina el servicio | espejo HubSpot → tarea | `sale_order_id`: el producto de servicio **crea la intervención al confirmar la orden** (`sale_planning`) |
| Incidencia → visita | (pendiente «Reportar incidencias») | `helpdesk_ticket_id`: «generar intervención desde el ticket» (`helpdesk_planning_field_service`, instalado) |
| Aviso al cliente | push/correo propios | SMS nativo (`planning_field_service_sms`), WhatsApp instalado |

Estado real: 0 intervenciones creadas, roles ya definidos («Instalador OhmSafe
Externo/Interno», «Technician»), proyecto «Field Service» (id 4) creado por el módulo,
29 tareas en «Instalaciones OhmSafe», 45 productos, 143 órdenes de venta, 1 almacén.

## 2. Diagnóstico de lo actual

- **Correcto y reutilizable:** el backend como puente (`/v1/instalador/*`), la app
  blanca (sin licencia Odoo por instalador), la sesión/push/notificaciones, el
  ligado equipo↔serie, el espejo HubSpot/Stripe→Odoo, el modelo cliente→casa→equipos.
- **Deuda:** 61 campos `x_` en `project.task` (Studio), etapas propias, PDF hecho a
  mano porque Odoo bloquea `_render_qweb_pdf` por RPC, automatizaciones sobre campos
  propios, JSON en texto para materiales, y la evidencia en S3 fuera de Odoo. Todo eso
  existe nativo en Planning y hoy lo mantenemos nosotros.
- **Riesgo estructural:** el instalador es **usuario externo** (`share=true`); Planning
  asigna turnos a **empleados** (`hr.employee`), que NO necesitan licencia. La app
  seguirá entrando con su usuario externo y el backend mapeará partner → empleado.

## 3. Arquitectura objetivo (una verdad por dominio)

```
CRM (HubSpot espejo) ─▶ Ventas: cotización/orden ─▶ Suscripción por casa (Stripe verdad)
                                   │ producto de servicio «Instalación»
                                   ▼
                     PLANIFICACIÓN · intervención (planning.slot)
   Appointment (disponibilidad) ─▶ agenda por rol/habilidad/mapa ─▶ SMS/WhatsApp cliente
                                   │ timer + geolocalización
                                   │ hoja de trabajo (fotos, checklist) + firma → PDF nativo
                                   │ materiales → INVENTARIO (almacén central + van por instalador,
                                   │   series/lotes = serie del energizador = Device del backend)
                                   ▼
                     Partes de horas → factura al cliente · base del pago al instalador
   Helpdesk (incidencias) ─▶ nueva intervención     Mantenimiento (preventivos) ─▶ intervenciones
   Encuestas (satisfacción tras completar)           Firma (contrato)   Documentos (evidencia)
   Punto de venta (futuro: venta en campo)           Conocimiento (manuales del instalador)
```

Reglas de buena práctica que fija esta arquitectura:

1. **Odoo es la verdad de la operación** (servicio, inventario, facturación); el backend
   es la verdad del **equipo** (serie, MAC, telemetría, accesos, casa); HubSpot es
   marketing/CRM espejo; Stripe es cobro. Nada se duplica sin dueño declarado.
2. **La serie del equipo es la llave** entre mundos: lote/serie en Inventario ⇔
   `Device.serialNumber` en el backend. Se acaba el `x_mac_address` suelto.
3. **Campos propiedad (`slot_properties`) en vez de Studio** para lo que Odoo no trae
   (metraje, condiciones del terreno, addons). Sin módulos a medida: es saas.
4. **Nada de PDF ni correos propios donde Odoo los genera**: hoja de trabajo → reporte
   → correo al cliente, todo dentro de Odoo.
5. **Eventos por automatización/webhook** sobre los campos nativos (`employee_ids`,
   `start_datetime`, `state`), no sobre campos `x_`.
6. **Usuario de API dedicado y mínimo** para el backend (hoy usa el admin, uid 2).
7. **Ids, nunca nombres**, en todas las referencias (ya es regla nuestra).

### Encaje de cada app

- **Planificación (+ Servicio de campo):** el corazón. Instalaciones, reparaciones,
  mantenimientos y reemplazos son **intervenciones** con plantillas de turno distintas
  y su hoja de trabajo. Habilidades y roles deciden a quién se asigna; el mapa ordena
  la ruta del día.
- **Ventas + Suscripciones:** la orden de venta crea la intervención; la suscripción
  por casa ya existe (paso 6 «cobro por casa»). El servicio se factura por tiempo y
  materiales o a precio cerrado, según el producto.
- **Inventario + Código de barras:** almacén central y una **ubicación/almacén por
  instalador** («van»); energizadores y sensores como productos con serie; el
  instalador consume desde su van al cerrar y el stock baja solo. Reposición con
  Compras.
- **Helpdesk:** «Reportar incidencias» del instalador y las del cliente entran como
  tickets; el puente instalado los convierte en intervención. Sustituye el módulo que
  íbamos a construir a mano.
- **Mantenimiento:** planes preventivos por equipo (fecha de la última instalación)
  que generan intervenciones. Sustituye el módulo «Mantenimientos» del home.
- **Reparaciones:** módulo `repair` (sin instalar) sólo si hace falta cotizar
  reparación de piezas en taller; una reparación en sitio es una intervención con
  materiales. Recomendación: no instalarlo aún.
- **Encuestas:** encuesta automática al completar (fase 5, ranking del instalador).
- **Citas (Appointment):** disponibilidad del cliente ligada al calendario del
  instalador (pendiente 3 de la app), ya instalado.
- **Firma:** contrato del cliente (hoy «check contrato firmado» a mano).
- **Documentos / Conocimiento:** evidencia y manuales; **Conocimiento** puede ser la
  ayuda dentro de la app.
- **Punto de venta:** ya instalado con puente a Planificación. Para «el instalador
  vende desde la app» el camino corto es **cotización + enlace de pago Stripe** desde el
  backend (sin sesión de caja ni licencia). PoS sólo si habrá venta con efectivo y
  stock físico en mano; entonces el instalador necesitaría usuario interno.
- **Empleados + Habilidades + Partes de horas:** el instalador como empleado (sin
  licencia), habilidades para asignación, horas por intervención como base del **pago
  al instalador** (fase 4).

## 4. Camino de migración sin parar la app

| Fase | Qué | Backend/app |
|---|---|---|
| 0. Configurar (Odoo, sin código) | instalar «Field Service Reports» (`planning_field_service_worksheet`); plantilla de hoja de trabajo (checklist + 4 fotos + observaciones + firma); plantillas de turno por tipo de servicio; roles/habilidades; producto de servicio «Instalación» que crea intervención; almacén por instalador; series en energizador/sensores; usuario de API dedicado | ninguno |
| 1. Doble lectura | las órdenes nuevas nacen como **intervenciones** al confirmar la venta; las 29 tareas viejas se terminan en Proyecto | `/v1/instalador/ordenes` lee `planning.slot` y, mientras haya, `project.task`; automatizaciones sobre `employee_ids`/`start_datetime` |
| 2. Flujo nativo | ruta = Sign In (geolocalización), llegada, inspección/instalación = propiedades de la hoja, vinculación = línea de material con serie, cierre = hoja completa + firma → PDF y correo de Odoo | se retiran pdfkit, S3 de evidencia y los `x_` del cierre |
| 3. Postventa | Helpdesk (incidencias), Mantenimiento (preventivos), Encuestas | módulos del home apuntan a intervenciones por tipo |
| 4. Venta en campo | cotización + Stripe desde la app; PoS si hay efectivo | endpoint de cotización |

**Verificar antes de la fase 2 (riesgo conocido):** que el PDF de la hoja de trabajo y
su envío se puedan disparar por RPC (Odoo bloqueó `_render_qweb_pdf`; con el módulo
de reportes debería existir una acción pública). Si no, se dispara con una
automatización dentro de Odoo al pasar a *Completed*.

## 5. Qué NO cambia

La app (Flutter), la sesión persistente, el push, las notificaciones, el centro de
notificaciones, la zona horaria, el modelo casa→equipos del backend y el cobro por
casa. Cambia **de qué modelo de Odoo cuelga la orden** y quién genera la evidencia.

## 6. Hojas de trabajo (worksheets) en tu versión — verificado 2026-09-25

**Nombre.** En Odoo se llaman *Worksheets* / **Hojas de trabajo**; el PDF que sale de
ellas es el *Field Service Report* / **Reporte de servicio de campo**. Son el lugar
donde viven el checklist, las observaciones y la **firma del cliente**.

**Cómo funcionan en 19.2+ (ya no con Studio).** Nota de la versión 19.2: «Worksheet
templates now use property fields instead of Studio fields». Verificado en tu base:

- La plantilla es la **definición de propiedades del ROL** (`planning.role.
  slot_properties_definition`): Planificación → Configuración → Roles → pestaña de
  propiedades. Cada intervención de ese rol muestra esos campos
  (`planning.slot.slot_properties`). Hoy los tres roles («Instalador OhmSafe
  Externo/Interno», «Technician») tienen la definición **vacía**.
- Tipos de campo disponibles: texto, texto largo, HTML, **casilla (check)**, entero,
  decimal, monetario, fecha, fecha y hora, **selección**, etiquetas, relación a otro
  modelo (uno o varios) y **separador** (agrupa checks bajo un título plegable). **No
  hay tipo foto/archivo**: las fotos van como **adjuntos de la intervención** (chatter)
  y el reporte las incluye.
- El módulo **«Field Service Reports»** (`planning_field_service_worksheet`, sin
  instalar) añade **plantillas de hoja de trabajo independientes del rol**
  (`worksheet.template`, también con propiedades) para tener, por ejemplo, una hoja de
  Instalación y otra de Reparación con el mismo rol. Con lo instalado hoy se puede
  empezar con una plantilla por rol.
- **Firma:** campos nativos `worksheet_signature` / `worksheet_signed_by` en la
  intervención; el cliente firma en el portal o en el dispositivo del técnico.
- **Reporte y envío:** ya existen el reporte `planning_field_service.worksheet_custom`
  («Field Service Report») y la acción «Send Report» sobre la intervención.
- **RPC verificado:** `action_send_report`, `action_sign_in`, `action_complete` y
  `action_preview_worksheet` son métodos públicos de `planning.slot` y se pueden
  invocar desde el backend. **El riesgo del PDF por RPC queda resuelto.**

**Nuestra hoja de trabajo de instalación (borrador de checks por rol):**
separador «Inspección» → sin obstáculos (check), obstáculos (texto), metraje real
(decimal); separador «Instalación» → postes esquina/paso (entero), abanicos (entero),
aisladores por poste (entero), inventario confirmado (check), checklist completado
(check); separador «Entrega» → control remoto funcional (check), cámaras
(selección: instaladas / no aplica), sensores (selección), observaciones (texto largo);
fotos = adjuntos (perfil izq/der, frente, energizador); firma = campo nativo.
