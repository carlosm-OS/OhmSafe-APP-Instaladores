# Precios, pagos y comisiones del instalador: dónde se ajustan (guía de operaciones)

> **USO INTERNO — no publicar.** Para dirección y operaciones de OhmSafe. Todo se ajusta en Odoo, en la ficha del producto; no hace falta tocar la app ni el servidor. Los cambios aplican de inmediato (la app lee los productos cada vez que abre esas pantallas).

## Mapa: qué número vive dónde

| Lo que ves | Dónde se ajusta | Campo | Quién lo usa |
|---|---|---|---|
| Precio que la app muestra al instalador en **Cotizar venta** (y que va a la cotización del cliente) | Ventas › Productos › el producto con la etiqueta **«App instalador»** | **Precio de venta** | App › Cotizar venta; la cotización S00… que se crea |
| Precio del plan y de la instalación en las órdenes de venta de clientes | Ventas › Productos › `OS-…` (planes) y `SRV-INST-…` (instalación por plan) | **Precio de venta** | Órdenes de venta, suscripciones, Stripe espejo |
| Lo que OhmSafe **paga al instalador** por un servicio | Compras › Productos › `PAGO-INSTALACION`, `PAGO-REPARACION`, `PAGO-MANTENIMIENTO`, `PAGO-REEMPLAZO` | **Costo** | Factura de proveedor en borrador que se crea al cerrar (ver artículo *Pagar un servicio al instalador*) |
| **Comisión** por una venta hecha con el código del instalador | Compras › Productos › `PAGO-COMISION` | **Costo** (monto fijo) | Línea extra en su factura de proveedor (manual, ver abajo) |
| Tarifas de la pantalla **Reparación** de la app (postes, abanicos, mano de obra) | Hoy **dentro de la app** (`lib/config/repair_pricing.dart`), todas en $0 | — | Pendiente moverlas a Odoo; mientras, cambiarlas requiere build nueva |

## 1. Precios que ve el instalador en «Cotizar venta»

La pantalla lista **sólo** los productos que cumplen las tres condiciones: etiqueta **«App instalador»**, casilla **Se puede vender** marcada y **Precio de venta mayor a $0**. Si un producto no sale en la app, revisa esas tres cosas.

Hoy están etiquetados:

| Código | Producto | Precio de venta |
|---|---|---|
| `MO-ENERG-BAT` | Cambio energizador con batería | $1,500 |
| `MO-ENERG-SIMPLE` | Cambio energizador simple | $950 |
| `MO-MTTO-ANUAL` | Mantenimiento preventivo anual | $1,800 |
| `OS-SUB-HOGAR-MEN` | Plan Hogar Seguro - Mensual | $1,293.10 |
| `SRV-INSTALACION`, `SRV-REPARACION`, `SRV-REEMPLAZO` | Servicios genéricos | **$0 → no aparecen** |

Para cambiar un precio: Ventas › Productos › abrir el producto › **Precio de venta** › guardar. Para agregar un producto a la app: ponerle la etiqueta «App instalador» (pestaña *Ventas* o campo *Etiquetas de producto*) y un precio. Para quitarlo: quitar la etiqueta (no borrar el producto).

> Los precios son **sin IVA**; la cotización aplica el impuesto del producto.

## 2. Precios de planes e instalación (órdenes de venta)

- Planes: `OS-HOGAR-MEN`, `OS-HOGAR-ANU`, `OS-FORT-MEN`, `OS-FORT-ANU`, `OS-FUND-MEN`, arranques `OS-HOGAR-ARR` / `OS-FORT-ARR`.
- Instalación por plan: `SRV-INST-HOGAR-MEN`, `SRV-INST-HOGAR-ANU`, `SRV-INST-FORT-MEN`, `SRV-INST-FORT-ANU` (hoy en $0: la instalación va incluida en el plan). Si algún día se cobra aparte, se pone el **Precio de venta** aquí y la línea de instalación de cada venta nueva lo tomará.

Ojo: cambiar el precio de un plan **no** cambia las suscripciones ya activas (cada una conserva el precio de su orden) ni Stripe. Los cambios de precio de planes se coordinan con Stripe (la fuente de cobro) antes de tocarlos en Odoo.

## 3. Lo que se le paga al instalador (tabulador)

Cada servicio cerrado desde la app crea una **factura de proveedor en borrador** con el producto `PAGO-…` que corresponde y **cantidad 1 × Costo del producto**:

| Servicio | Producto | Costo hoy |
|---|---|---|
| Instalación | `PAGO-INSTALACION` | **$0** |
| Reparación | `PAGO-REPARACION` | **$0** |
| Mantenimiento | `PAGO-MANTENIMIENTO` | **$0** |
| Reemplazo de equipo | `PAGO-REEMPLAZO` | **$0** |

Mientras el costo sea $0, la factura nace en $0 con la nota «Sin tarifa configurada» y hay que corregir el importe a mano antes de confirmarla.

**Para fijar el tabulador (una sola vez):** Compras › Productos › buscar `PAGO-` › abrir el producto › campo **Costo** › guardar. A partir de ese momento cada cierre nuevo trae el importe correcto. Si el pago depende del caso (metraje, distancia, material que puso el instalador), se deja el costo base en el producto y operaciones ajusta o agrega líneas en la factura antes de confirmarla.

Lo que el instalador ve en **Mis pagos** es exactamente esa factura: importe y estado (borrador / confirmada / pagada).

## 4. Comisión por venta

Cómo se identifica la venta del instalador: cada instalador tiene un **código de venta** `OHMS-…` (ficha de instalador, solo lectura). Cuando cotiza desde la app, la cotización queda ligada a él (origen «Cotización desde la app · código …»). Si la cotización se confirma y se paga, esa venta es suya.

**Hoy la comisión no se calcula sola.** Para pagarla:

1. Fija el monto: Compras › Productos › `PAGO-COMISION` › **Costo** = comisión fija por venta (o déjalo en $0 y captura el importe en cada factura si es un porcentaje).
2. Cuando una venta de un instalador se cobre, abre su factura de proveedor del mes (o crea una nueva: Contabilidad › Proveedores › Facturas › Nuevo, proveedor = el instalador) y agrega una línea con `PAGO-COMISION`, cantidad 1, precio = comisión, y en la descripción el número de la orden de venta (S00…).
3. Confirmar y pagar como cualquier factura de proveedor; el instalador la ve en **Mis pagos**.

Para encontrar las ventas de un instalador: Ventas › Órdenes › buscar en *Origen* su código `OHMS-…`.

Lo que falta para que sea automático (decisión de dirección): el porcentaje o monto por plan, si se paga al cobro o al cierre de la instalación, y si aplica a renovaciones. Con eso definido, el sistema puede crear la línea de comisión al confirmar el pago de la venta.

## 5. Reparaciones (tarifas de la app)

La pantalla *Reparación* de la app calcula un estimado con tarifas que hoy viven en el código de la app (`lib/config/repair_pricing.dart`) y están todas en **$0**. Cambiarlas implica una build nueva. Está pendiente pasarlas a productos de Odoo con la etiqueta «App instalador», igual que Cotizar venta, para que se ajusten sin tocar la app.

## Comprobación rápida

| Pregunta | Dónde |
|---|---|
| ¿Qué precios ve hoy la app? | Ventas › Productos › filtro por etiqueta «App instalador» (vendible y precio > 0) |
| ¿Cuánto se paga por instalación? | Compras › Productos › `PAGO-INSTALACION` › Costo |
| ¿Cuánto le debo a un instalador? | Contactos › ficha del instalador › botón *Facturas de proveedor* |
| ¿Qué ventas trajo? | Ventas › Órdenes › buscar su código `OHMS-…` en Origen |
