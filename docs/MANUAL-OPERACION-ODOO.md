# Manual de operación — Ruta del ticket (App ↔ Odoo)

Qué escribe cada paso de la app de instaladores en Odoo y **dónde verlo**.
Versión visual/compartible: artifact "Ruta del Ticket en Odoo".

## Dónde vive todo
Cada orden es una **tarea** del proyecto **“[TEST] Servicios Instalador”**
(app **Proyecto** de Odoo). El **Kanban** tiene una columna por etapa; cada paso
de la app mueve la tarjeta. Los datos capturados están en los campos `x_…` de la
ficha de la tarea.

`Odoo → Proyecto → [TEST] Servicios Instalador → Kanban / Lista`

Etapas: **Por hacer · En ruta · En sitio · En proceso · Cierre · Completada · Cancelada**.

## Mapa rápido
| Paso en la app | Etapa en Odoo | Campos que se escriben |
|---|---|---|
| El ticket nace | Por hacer | `x_tipo_servicio`, `partner_id`, `x_metros_aprox`, `x_urgente` |
| Iniciar ruta de servicio | En ruta | `x_hora_salida_tecnico` |
| Marcar llegada | En sitio | `x_hora_llegada` |
| Inspección de perímetro | En proceso | `x_sin_obstaculos`, `x_obstaculos_perimetro` |
| Instalación — registro (instalación) | En proceso | `x_postes_esquina`, `x_postes_paso`, `x_abanicos`, `x_materiales_instalados`, `x_inventario_confirmado`, `x_checklist_completado` |
| Reparación — costeo (reparación) | En proceso | `x_causa_falla`, `x_energizador_tipo`, `x_costo_mano_obra`, `x_costo_material`, `x_costo_total` |
| Vincular energizador (instalación) | En proceso | `x_estado_vinculacion`, `x_mac_address` |
| Cierre del servicio | Completada | `x_control_entregado`, `x_entrega_funcional`, `x_anomalias`, `x_evidencias_urls`, `x_firma_url`, `x_fecha_activacion` |
| Cancelar (en cualquier punto) | Cancelada | `x_motivo_cancelacion` |

## Paso a paso (nombre técnico · etiqueta · dónde verlo)

**0. El ticket nace → Por hacer.** `x_tipo_servicio` (Tipo de servicio: instalacion/reparacion/mantenimiento), `partner_id` (Cliente + dirección/teléfono), `x_metros_aprox`, `x_urgente`.
Ver: Kanban, columna *Por hacer* → clic en la tarjeta.

**1. Iniciar ruta de servicio → En ruta.** `x_hora_salida_tecnico` (Hora salida técnico, fecha/hora).
Ver: la tarjeta pasa a *En ruta*; abre la tarea y revisa Hora salida técnico.

**2. Marcar llegada → En sitio.** `x_hora_llegada` (Hora de llegada, fecha/hora).
Ver: la tarjeta pasa a *En sitio*; abre la tarea → Hora de llegada; en Lista, Agrupar por Etapa para contar llegadas.

**3. Inspección de perímetro → En proceso.** `x_sin_obstaculos` (Sin obstáculos), `x_obstaculos_perimetro` (Obstáculos perímetro, ej. `["Árbol","Reja"]`).
Ver: abre la tarea → Sin obstáculos / Obstáculos perímetro.

**4a. Instalación — registro → En proceso.** `x_postes_esquina`, `x_postes_paso`, `x_abanicos` (conteos), `x_materiales_instalados` (Materiales instalados, JSON con el desglose completo), `x_inventario_confirmado`, `x_checklist_completado`.
Ver: abre la tarea → conteos y Materiales instalados.

**4b. Reparación — costeo → En proceso.** `x_causa_falla` (evento_externo/desgaste), `x_energizador_tipo` (ninguno/simple/bateria), `x_costo_mano_obra`, `x_costo_material`, `x_costo_total`.
Ver: abre la tarea → Costo total evento y Causa de falla.

**5. Vincular energizador (solo instalación) → En proceso.** `x_estado_vinculacion` (pasa a “vinculado”), `x_mac_address` (MAC, ej. `AA:BB:CC:11:22:33`).
Ver: abre la tarea → Estado vinculación = vinculado; MAC en Energizador — MAC.

**6. Cierre del servicio → Completada.** `x_control_entregado`, `x_entrega_funcional`, `x_anomalias` (tipos+comentarios), `x_evidencias_urls`, `x_firma_url`, `x_fecha_activacion`.
Ver: la tarjeta llega a *Completada*; en la app aparece en **Historial**; abre la tarea para entrega/anomalías/fecha.

**Cancelar (en cualquier paso) → Cancelada.** `x_motivo_cancelacion`.
Ver: columna *Cancelada* → abre la tarea para leer el motivo.

## Tarifas (precios de la calculadora)
La calculadora de reparación **lee los precios de Odoo en vivo**; el nuevo valor
se aplica al reabrir la pantalla de costeo. Están como productos **tipo Servicio**,
categoría **“Tarifas Instalador”**.

`Odoo → Inventario → Productos` → quita el filtro “Bienes” o busca `Tarifas Instalador` → abre el producto → edita **Precio** → guarda.

- `MO-*` = mano de obra (pago al instalador) · `MAT-*` = material (costo OhmSafe).
- Precio en **0** → la app usa el respaldo interno. Firmes cargados: energizador simple **$950**, con batería **$1500**, mantenimiento anual **$1800**.

## Abrir una tarea / seguimiento
- Kanban: clic en la tarjeta → ficha con los campos `x_…`.
- Lista: **Agrupar por → Etapa** (cuántos tickets en cada punto); **Filtrar por Tipo de servicio** para separar instalación de reparación.

> Todo ocurre en el proyecto **[TEST] Servicios Instalador** de `ohmsafe2`. La app
> escribe vía el backend `/v1/instalador`; Odoo es la fuente de verdad. Los `x_…`
> son los nombres técnicos; la etiqueta es lo que ves en la ficha.
