# Odoo Build Sheet — Operación de Instaladores (Opción A: Project + Portal)

> Checklist ejecutable para configurar la **copia** de `ohmsafe2` (Odoo Online,
> solo Studio). Al terminar, el API apunta aquí (useMock=false) y se valida con
> la app; luego se replica en producción. Diseño: `DISENO-ODOO-instalador.md`.

## 1. Módulos a instalar (en la copia)
- **Project** (Proyecto) — la orden de servicio.
- **Inventory** (Inventario) — series de energizador (`stock.lot`).
- **Studio** — campos personalizados (requiere plan con Studio).
- **Facturación + l10n_mx** — CFDI (fase posterior, no bloquea la app).

## 2. Proyecto y etapas
- Proyecto: **"Servicios de Instalador"** (uno solo; el tipo lo da un campo).
- Etapas (`project.task.type`), en secuencia:
  1. Por hacer
  2. En ruta
  3. En sitio
  4. En proceso
  5. Cierre
  6. Completada
  7. Cancelada

  (El tipo instalación/reparación se distingue por `x_tipo_servicio`, no por etapa. "No fue posible reparar" = motivo de cancelación, no etapa. "Facturada" = campo/estado posterior.)

## 3. Campos personalizados (Studio) en `project.task`
| Etiqueta | Nombre técnico | Tipo | Notas |
|---|---|---|---|
| Tipo de servicio | `x_tipo_servicio` | Selección | instalacion / reparacion / mantenimiento |
| Instalador | `x_instalador_id` | Many2one `res.partner` | contacto portal |
| Urgente | `x_urgente` | Boolean | |
| Contacto de sitio | `x_contacto_sitio` | Char | |
| Horario preferido | `x_horario_preferido` | Char | |
| Referencias domicilio | `x_referencias_domicilio` | Text | dirección va en el partner |
| Dirección verificada | `x_direccion_verificada` | Boolean | |
| Fecha agendada | (nativo `planned_date`) | — | |
| Hora salida técnico | `x_hora_salida_tecnico` | Datetime | |
| Fecha activación | `x_fecha_activacion` | Date | |
| Metros aprox. | `x_metros_aprox` | Float | |
| Metros instalados | `x_metros_instalados` | Float | |
| Postes esquina | `x_postes_esquina` | Integer | |
| Postes de paso | `x_postes_paso` | Integer | |
| Abanicos | `x_abanicos` | Integer | |
| Aisladores por poste | `x_aisladores_por_poste` | Integer | |
| Letreros seguridad | `x_letreros_seguridad` | Boolean | |
| Edad de la cerca (años) | `x_edad_cerca_anios` | Integer | validación plausibilidad |
| Sin obstáculos | `x_sin_obstaculos` | Boolean | |
| Obstáculos perímetro | `x_obstaculos_perimetro` | Text | lista/JSON |
| Estado internet en sitio | `x_estado_internet_sitio` | Selección | |
| Inventario confirmado | `x_inventario_confirmado` | Boolean | |
| Checklist completado | `x_checklist_completado` | Boolean | |
| Energizador — tipo | `x_energizador_tipo` | Selección | ninguno / simple / bateria |
| Energizador — MAC | `x_mac_address` | Char | (también en stock.lot) |
| Estado vinculación | `x_estado_vinculacion` | Selección | pendiente / vinculado |
| Causa de falla (rep.) | `x_causa_falla` | Selección | evento_externo / desgaste |
| Costo mano de obra | `x_costo_mano_obra` | Monetary | del costeo |
| Costo material | `x_costo_material` | Monetary | del costeo |
| Costo total evento | `x_costo_total` | Monetary | |
| Control entregado | `x_control_entregado` | Boolean | cierre |
| Entrega funcional | `x_entrega_funcional` | Boolean | cierre |
| Anomalías entrega | `x_anomalias` | Text | tipos + descripción |
| URLs evidencias (S3) | `x_evidencias_urls` | Text | JSON de URLs |
| URL firma (S3) | `x_firma_url` | Char | |
| Motivo cancelación | `x_motivo_cancelacion` | Selección | |
| Notas cancelación | `x_notas_cancelacion` | Text | |
| Notas solicitud reparación | `x_notas_solicitud_reparacion` | Text | |
| Notas: no reparable | `x_notas_no_reparable` | Text | |

## 4. Cliente (`res.partner`) — fiscal (mayormente nativo/l10n_mx)
RFC, régimen fiscal, uso CFDI, razón social, CP fiscal → **nativos de l10n_mx**.
Solo custom: `x_constancia_url` (Char, URL S3 de la constancia).

## 5. Energizador (Inventario)
- `product.template` "Energizador" con **seguimiento por número de serie** (tracking=serial).
- El serial vive en `stock.lot`; agregar `x_mac_address` (Char) en `stock.lot`.

## 6. Tarifas (productos + lista de precio) — reemplaza `repair_pricing.dart`
Crear **productos de servicio** (precio = pago al instalador) y de **material** (costo OhmSafe). Operaciones los edita en Odoo; el API los lee → `GET /v1/instalador/tarifas-reparacion`.

**Mano de obra (pago instalador):**
| Producto | Precio | Estado |
|---|---|---|
| Visita / diagnóstico | $0 | por definir |
| Metro de hilo reparado | $0 | por definir |
| Cambio poste esquina | $0 | por definir |
| Cambio poste de paso | $0 | por definir |
| Cambio abanico | $0 | por definir |
| Cambio aislador suelto | $0 | por definir |
| Cambio tensor | $0 | por definir |
| Cambio energizador simple | **$950** | firme (Yonusa) |
| Cambio energizador con batería | **$1500** | firme |
| Mantenimiento preventivo anual | **$1800** | firme (OhmSafe) |

**Material (costo OhmSafe):**
| Producto | Precio | Nota |
|---|---|---|
| Rollo alambre cal.16 3kg | $0 | rinde ~195 m/rollo |
| Material poste esquina / paso | $0 | por definir |
| Material abanico / aislador / tensor | $0 | por definir |
| Material energizador simple / batería | $0 | por definir |

**Parámetros del modelo (config del API, NO productos):**
- Factor dificultad por hilo: Medio **+10%**, Alto **+25%**.
- Tramo máx entre postes: **6 m**. Vida mín aislador: **4 años**; cable: **8 años**.

## 7. Cómo lo consume el API
- Las etapas ↔ estados de la orden en la app.
- Los `x_*` ↔ payloads de detalle/inspección/cierre (ver `CONTRATO-API-instalador.md`).
- Los productos/pricelist ↔ `GET /tarifas-reparacion` (mata los $0 cuando se definan).
- Evidencias/firma → S3 (API); Odoo guarda URLs.
