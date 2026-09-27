# Diseño de procesos en Odoo — Operación de Instaladores (borrador v0.1)

> Modelado **desde la app de instaladores** (la versión "con vitaminas"), NO
> desde el MVP de HubSpot. HubSpot se usa solo como referencia de campos.
> Para validar (Carlos + Dan) **antes** de configurar. La configuración se hace
> primero en una **copia** de la BD `ohmsafe2`, nunca en producción.

## 0. Principios
- **Odoo = sistema de registro** de la operación de campo (trazabilidad, inventario, facturación, pago a instalador).
- **La app = fuente del proceso** (el flujo con vitaminas). Odoo se adapta a la app, no al revés.
- **El API `ohmsafe` = middleware**: la app habla con el API; el API lee/escribe Odoo por RPC y refleja HubSpot con el motor `Sync*`.
- **HubSpot = origen** (donde nace el lead/ticket por ventas). No opera el trabajo.

## 1. Restricciones de plataforma (Odoo Online / SaaS)
- **Sin módulos custom con código** → solo **Studio** (campos personalizados, etapas, automatizaciones simples). La lógica compleja va en el API.
- **Instaladores = usuarios portal** (`share=true`): Odoo no les asigna trabajo nativamente.
- Cambios sensibles (`ir.config_parameter`, etc.) los hace Carlos a mano.

## 2. DECISIÓN CLAVE: ¿cómo modelamos la orden y la asignación?
| Opción | Cómo | Pros | Contras |
|---|---|---|---|
| **A) Project + Tasks (portal)** ⭐ recomendado | La orden = `project.task`; el instalador va como **contacto/seguidor** o campo custom; la asignación real la gobierna el API; comisiones = facturas de proveedor | **Sin costo de licencias** (portal gratis); simple; la app ya da la UX | La asignación no es "nativa" de Odoo (la maneja el API) |
| **B) Field Service (internal users)** | La orden = tarea FSM; instalador = **usuario interno** | Agenda/worksheet/firma nativas | **Licencia de pago por instalador**; UI redundante con la app |

**Recomendación: A.** La app ya aporta agenda, checklist, evidencias, firma y costeo ("con vitaminas"), así que Odoo no necesita la UI de FSM — solo ser el **registro** + inventario + facturación. Empezar con Project+Tasks (portal, gratis) y migrar a FSM solo si algún día se justifica.

## 3. Modelo de datos en Odoo (opción A)
- **Orden de servicio** → `project.task` en un proyecto por tipo (o un proyecto "Servicios" + campo `tipo`: instalación/reparación/mantenimiento).
- **Cliente** → `res.partner` (con datos fiscales SAT para CFDI: RFC, régimen, razón social, CP fiscal, constancia).
- **Instalador** → `res.partner`/usuario portal, referenciado en la tarea (campo custom `x_instalador`).
- **Equipo / energizador** → `product.product` + `stock.lot` (número de serie) + campo custom `x_mac_address`; estado de vinculación en la tarea.
- **Inventario instalado** (para costeo de reparación) → líneas de producto / campos custom en la tarea: metros, líneas, postes esquina/paso, abanicos, aisladores, edad de la cerca.
- **Costeo de reparación** → `sale.order` (o líneas en la tarea) con **listas de precio** de Odoo = las **tarifas** (hoy en $0 en la app). Separa mano de obra (pago instalador) de material (costo OhmSafe).
- **Evidencias (fotos/firma)** → en **S3** (`integrations/s3`); en Odoo se guardan las **URLs** (campo custom o `ir.attachment` con url).
- **Facturación** → módulo de facturación Odoo + `l10n_mx` (CFDI). Concerns fiscales viven aquí, NO en la tarea.

## 4. Pipeline de etapas (derivado de la APP, no del MVP)
Etapas de `project.task` (Kanban), comunes con matiz por tipo:

**Instalación:** `Por hacer → En ruta → En sitio (llegada) → Instalación → Vinculación energizador → Cierre (evidencias+equipo+firma) → Completada` · (+ `Cancelada`)

**Reparación:** `Por hacer → En ruta → En sitio → Diagnóstico/Costeo → Cierre → Completada` · (+ `Cancelada` / `No fue posible reparar`)

**Post-operación (común):** `Facturada` (cuando se emite CFDI) — puede ser un campo/estado, no etapa Kanban.

> Nota: el MVP de HubSpot mezcla en un mismo ticket **instalación + seguros(GNP) + pánico + facturación**. En Odoo se **separan**: instaladores = este pipeline; seguros y pánico = procesos aparte; facturación = módulo fiscal.

## 5. Mapeo HubSpot → Odoo (subset operativo de la app)
| Propiedad HubSpot | Campo/objeto Odoo | Nativo/Studio |
|---|---|---|
| nombre_de_cliente, apellidos_cliente | `res.partner.name` | nativo |
| correo_electronico, numero_de_telefono | `res.partner.email/phone` | nativo |
| direccion_de_instalacion, codigo_postal, referencias_del_domicilio | dirección del partner / tarea | nativo + Studio |
| contacto_de_sitio, horario_preferido_del_contacto | tarea (custom) | Studio |
| direccion_verificada | tarea `x_direccion_verificada` (bool) | Studio |
| instalacion_tecnico_asignado | `x_instalador` (partner portal) | Studio |
| estado_de_agendamiento, instalacion_fecha_agendada | `planned_date` / etapa | nativo |
| instalacion_estado_de_ruta, instalacion_hora_salida_tecnico | etapa + `x_hora_salida` | nativo + Studio |
| instalacion_obstaculos_del_perimetro, ...estado_de_internet | tarea (custom) | Studio |
| instalacion_metros_aproximados / metros_lineales_instalados | `x_metros_*` | Studio |
| postes_de_esquina, postes_de_paso, letreros_* | `x_postes_*`, `x_letreros_*` | Studio |
| instalacion_inventario_confirmado, instalacion_checklist_completado | `x_*` (bool) | Studio |
| energizador_numero_de_serie | `stock.lot` (serial) | nativo |
| mac_address_energizador | `x_mac_address` | Studio |
| estado_de_vinculacion_energizador | `x_estado_vinculacion` | Studio |
| instalacion_firma_conformidad, firma_orden_de_servicio | URL S3 en `x_firma_url` | Studio |
| cancelacion_de_instalacion, instalacion_motivo/notas_cancelacion | etapa Cancelada + `x_motivo_cancelacion` | Studio |
| notas_solicitud_reparacion, notas_cerrado_no_fue_posible | tarea (reparación) | Studio |
| plan_ohmsafe_ticket | producto/plan | nativo |
| **Facturación** (rfc, régimen, razón social, CP fiscal, constancia, correo fact.) | `res.partner` fiscal / `l10n_mx` | nativo |
| **Seguros GNP** (aseguradora, póliza, PDFs, llamadas) | *fuera de alcance* (proceso aparte) | — |
| **Pánico** (clasificaciones) | *fuera de alcance* (pipeline Pánico) | — |

## 6. Cómo lo consume el API + sync
- Endpoints del instalador (ver `CONTRATO-API-instalador.md`) leen/escriben `project.task` de Odoo por RPC.
- El **motor `Sync*`** refleja HubSpot(lead/ticket)→Odoo(tarea) al crear, y estados de vuelta a HubSpot para visibilidad de ventas.
- Evidencias suben a S3 desde el API; Odoo guarda URLs.

## 7. Plan de ejecución (en orden, sin tocar prod)
1. **Carlos duplica la BD** `ohmsafe2` (Odoo Online → database manager → Duplicate). Resultado: `ohmsafe2-test` (o similar). *(Paso manual de Carlos; requiere master password.)*
2. En la copia: instalar **Project** (+ Inventory si falta), crear el proyecto/etapas, y los **campos custom `x_*` con Studio** (lista de §5).
3. Cargar **tarifas** en listas de precio (reemplaza los $0 de `repair_pricing`).
4. Apuntar el **API (instancia de instaladores)** a la copia de Odoo por RPC; validar lecturas/escrituras con la app (useMock=false).
5. Cuando esté validado, **replicar la config en producción** `ohmsafe2` y conectar el API productivo.

## 8. Decisiones abiertas
1. ¿Opción **A (Project+portal, recomendado)** o **B (FSM+internos, licencias)**?
2. ¿Un proyecto por tipo, o uno "Servicios" con campo `tipo`?
3. ¿Comisiones al instalador como **facturas de proveedor**? (define el flujo de pago)
4. Confirmar módulos instalados hoy en `ohmsafe2` (Project / Inventory / l10n_mx / Field Service) — a verificar en tu Chrome autenticado.
