# Pagar un servicio al instalador desde Odoo (guía de operaciones)

> **USO INTERNO — no publicar.** Para operaciones y contabilidad de OhmSafe. Describe cómo queda el pago de cada servicio al instalador externo y qué hacer en los casos que la app no cubre.

## En una frase

Cada servicio cerrado genera una **factura de proveedor en borrador** a nombre del instalador (Compras). Operaciones revisa el importe, la **valida** y contabilidad **registra el pago**. Nada se paga solo.

## Cómo se genera el pago (automático, al cerrar desde la app)

Cuando el instalador cierra la intervención en la app (firma del cliente), el sistema crea en Odoo:

| Qué | Dónde queda |
|---|---|
| Factura de proveedor **en borrador** (`Factura de proveedor`, tipo compra) | Contabilidad › Proveedores › Facturas (o Compras › Facturas de proveedor) |
| Proveedor | El **contacto del instalador** (el mismo de Contactos › Instaladores externos) |
| Línea | Producto «Pago a instalador — *Instalación / Reparación / Mantenimiento / Reemplazo de equipo*» (`PAGO-INSTALACION`, `PAGO-REPARACION`, `PAGO-MANTENIMIENTO`, `PAGO-REEMPLAZO`), cantidad 1 |
| Importe | El **costo** del producto (campo *Costo* en la ficha del producto). **Hoy los cuatro están en $0**: hasta que OhmSafe fije el tabulador, la factura nace en $0 y lleva la nota interna «Sin tarifa configurada: fija el costo del producto … y corrige el importe antes de validar» |
| Referencia | «Intervención i*N* · S00*xxx*» (número de intervención y orden de venta) |
| Enlace | En la intervención (Planificación) queda el id de la factura en la propiedad «Pago al instalador (factura proveedor id)» |

Regla: **un pago por línea de venta**, aunque la instalación tome varios días o se haya partido en dos turnos; el segundo turno no genera otra factura.

## Paso a paso para pagar

1. **Fijar el tabulador una sola vez** (si aún está en $0): Inventario o Compras › Productos › buscar `PAGO-` › abrir cada producto › campo **Costo** › guardar. Desde ese momento las facturas nacen con ese importe.
2. **Revisar la factura**: Contabilidad › Proveedores › Facturas › filtro *Borrador* › buscar por la referencia «Intervención i…» o por el nombre del instalador. Comprueba proveedor, producto, importe y, si aplica, agrega líneas extra (viáticos, material que puso él) con su comprobante.
3. **Fecha de factura** = fecha de cierre del servicio; **fecha de vencimiento** según el acuerdo con el instalador.
4. **Confirmar** (botón *Confirmar*). Ya cuenta como cuenta por pagar.
5. **Registrar pago**: botón *Registrar pago* › diario (banco con el que se transfiere) › fecha › *Crear pago*. Si pagas varias facturas del mismo instalador en una transferencia, selecciónalas en la lista y usa *Registrar pago* una sola vez.
6. El instalador ve el movimiento en la app, en **Mis pagos** (lee las facturas de proveedor a su nombre y su estado: borrador / confirmada / pagada).

## Cuando el servicio NO se cerró desde la app

Pasa cuando la instalación sí se hizo pero la intervención se cerró a mano en Odoo (p. ej. una prueba, o la app no pudo vincular). En ese caso **no existe la factura**; se crea igual que las automáticas:

1. Contabilidad › Proveedores › Facturas › **Nuevo**.
2. **Proveedor**: el contacto del instalador.
3. **Referencia de factura**: «Intervención i*N* · S00*xxx*» (así se encuentra igual que las automáticas y la app la muestra en Mis pagos).
4. **Línea**: producto `PAGO-INSTALACION` (o el que corresponda), cantidad 1, precio = tabulador.
5. Confirmar y registrar pago como arriba.
6. Opcional, para dejar rastro: en la intervención (Planificación) escribe una nota en el chatter con el número de la factura.

> Si el servicio fue **prueba interna** (p. ej. la intervención i39 de Diana del 1 de octubre, cerrada a mano el 5), **no se crea factura**: no hay pago que hacer. Déjalo anotado en el chatter de la intervención.

## Comprobación rápida

| Pregunta | Dónde se ve |
|---|---|
| ¿Ya se generó el pago de este servicio? | Planificación › intervención › propiedad «Pago al instalador (factura proveedor id)»; o Contabilidad › Facturas de proveedor buscando «Intervención i…» |
| ¿Cuánto se le debe a un instalador? | Contactos › ficha del instalador › botón **Facturas de proveedor** (o Contabilidad › Informes › Antigüedad de cuentas por pagar) |
| ¿Qué ve él en la app? | Mis pagos: una tarjeta por factura con intervención, orden de venta, importe y estado |

## Lo que todavía no existe

- **Tabulador**: los costos `PAGO-*` siguen en $0; lo fija Carlos (opción A manual por servicio / opción B tabulador por concepto, hoja de cálculo enviada a Operaciones el 2026-09-27).
- **Comisión por venta** del instalador (código de venta `OHMS-…`): no está implementada; se pagaría también como factura de proveedor cuando se defina.
- El instalador **no sube factura CFDI** desde la app; si factura a OhmSafe, el PDF/XML se adjunta a la factura de proveedor en Odoo.
