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

## Origen del ticket (HubSpot → Odoo, automático)
Operaciones **ya no crea a mano** el ticket de instalación. Al recibir el pago,
HubSpot arma el ticket en el pipeline **“Instalación Ohmsafe”** y **se refleja
solo en Odoo** como tarea del proyecto:

- **Tiempo real** (webhook): al crearse/avanzar el ticket en HubSpot, aparece en
  Odoo en segundos.
- **Red de seguridad** (cada 15 min): un proceso revisa HubSpot y trae lo que
  falte (idempotente, no duplica).
- Cada tarea trae `x_hubspot_id` (id de origen) y `x_alta_hubspot` (antigüedad).
- **Histórico**: las instalaciones cerradas de los últimos 12 meses ya se
  importaron (etapa *Completada*).

> No hay que hacer nada para que un ticket nuevo llegue a Odoo: llega solo. Lo
> único manual es **asignarle instalador** (siguiente sección).

## Asignación de instaladores (Operaciones)
`Odoo → Project → Asignación de instaladores`

- La vista muestra las instalaciones **agrupadas por instalador**; la columna
  **“Ninguno”** son las que **faltan por asignar**.
- **Asignar**: arrastra la tarjeta a la columna del instalador (Kanban), o abre
  la tarea y edita el campo **Instalador** (`x_instalador_id`).
- Al asignar, la instalación **desaparece de “sin asignar”**, aparece en la app
  del instalador y **le llega un push** (ver abajo).
- Favoritos útiles (menú *Favoritos* en la lista de tareas): **“🔧 Instalaciones
  sin asignar”** y **“👷 Instalaciones por instalador”**.

## Notificación al instalador (push)
Cuando pones `x_instalador_id`, Odoo dispara automáticamente una notificación
**push** al teléfono del instalador (“Nueva instalación asignada — <cliente>”).
Al tocarla se abre su lista de Instalaciones.

- Requiere que el instalador **haya iniciado sesión en la app al menos una vez**
  (ahí se registra el token de su dispositivo).
- Aunque no vea el push, la instalación **igual aparece** en su app al abrirla
  (filtro “solo lo mío”).

## Cómo dar de alta un instalador
Un instalador es un **contacto (`res.partner`)** identificado con la etiqueta
**“Instalador Externo-OS”**, y se asigna a cada orden con el campo `x_instalador_id`.

1. **Crear el contacto** — `Odoo → Contactos → Nuevo`: nombre, correo, teléfono.
   En **Etiquetas** añade **“Instalador Externo-OS”** (opcional: cargo “Instalador externo”).
2. **Darle acceso a la app (usuario portal)** — en el contacto: botón **Acción → Conceder acceso al portal**
   (o `Ajustes → Usuarios`). Queda como usuario **portal** (gratis, no consume licencia).
   **Ponle una contraseña temporal** y marca su contacto con `x_password_cambiada = false`.
   En el **primer ingreso** la app lo obliga a **crear su propia contraseña** (onboarding);
   no tiene que volver a Odoo. Le compartes correo + contraseña temporal + el enlace de descarga.
3. **Completa su perfil desde la app** — el instalador sube **RFC, CURP y constancia**.
   Cuando estén los tres, su `x_estado_instalador` pasa a **`activo`** y el sistema le
   **asigna automáticamente**:
   - **Número de instalador** (`x_numero_instalador`) — aleatorio único de 5 dígitos.
   - **Código de venta** (`x_codigo_venta`) — tipo `OHMS-<NOMBRE><NN>`, para el bono por referidos.
4. **Asignarle órdenes** — no se asigna a mano campo por campo: usa el panel
   **Asignación de instaladores** (ver arriba). Internamente escribe `x_instalador_id`.

> **Cada instalador solo ve SUS órdenes** en la app (las que tienen su `x_instalador_id`).
> Los usuarios sin la etiqueta de instalador (admin/ops) ven **todas**.
> Ejemplo ya creado: **Juan Mora** (`cuadrilla1@ohmsafe.com`, contraseña de prueba `OhmSafe#2026`).

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
