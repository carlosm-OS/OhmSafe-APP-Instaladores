# Pagar un servicio al instalador desde Odoo (guía de operaciones)

> **USO INTERNO — no publicar.** Para operaciones y contabilidad de OhmSafe. Describe cómo queda el pago de cada servicio al instalador externo y qué hacer en los casos que la app no cubre.

## En una frase

Cada servicio cerrado genera una **factura de proveedor en borrador y en $0** a nombre del instalador. Operaciones (Lily, auxservicios@) le pone **el monto que negoció con el instalador**, la **confirma** y, al transferir, **registra el pago**. Nada se paga solo.

> **Operación vigente (decisión de Carlos, 8 de octubre de 2026):** durante los próximos meses se opera «en maqueta»: **no hay tabulador ni costos configurados** en los productos `PAGO-*`. El importe de cada servicio lo captura a mano operaciones en la factura, según lo acordado con cada instalador. No cambies el *Costo* de los productos `PAGO-*`.

## Cómo se genera el pago (automático, al cerrar desde la app)

Cuando el instalador cierra la intervención en la app (firma del cliente), el sistema crea en Odoo:

| Qué | Dónde queda |
|---|---|
| Factura de proveedor **en borrador** (`Factura de proveedor`, tipo compra) | Contabilidad › Proveedores › Facturas (o Compras › Facturas de proveedor) |
| Proveedor | El **contacto del instalador** (el mismo de Contactos › Instaladores externos). Si en su ficha tiene **Empresa**, Odoo registra la factura a nombre de la empresa (RFC, cuentas por pagar y CFDI de la empresa) |
| Línea | Producto «Pago a instalador — *Instalación / Reparación / Mantenimiento / Reemplazo de equipo*» (`PAGO-INSTALACION`, `PAGO-REPARACION`, `PAGO-MANTENIMIENTO`, `PAGO-REEMPLAZO`), cantidad 1 |
| Importe | **$0**: los productos `PAGO-*` no tienen costo a propósito (operación en maqueta). La factura lleva la nota interna «Sin tarifa configurada…»; **operaciones captura el monto negociado** antes de confirmar |
| Referencia | «Intervención i*N* · S00*xxx*» (número de intervención y orden de venta) |
| Enlace | En la intervención (Planificación) queda el id de la factura en la propiedad «Pago al instalador (factura proveedor id)» |

Regla: **un pago por línea de venta**, aunque la instalación tome varios días o se haya partido en dos turnos; el segundo turno no genera otra factura.

## Paso a paso para pagar

1. **Buscar la factura**: Contabilidad › Proveedores › Facturas › filtro *Borrador* › buscar por la referencia «Intervención i… · S00…» o por el nombre del instalador.
2. **Poner el monto negociado**: en la línea «Pago a instalador — Instalación» (o Reparación / Mantenimiento / Reemplazo) cambia el **Precio** de $0 al monto acordado con el instalador. Si hubo extras (viáticos, material que puso él), agrégalos como líneas adicionales con su comprobante.
3. **Adjuntar su CFDI**: cuando el instalador (o su empresa) te mande la factura, adjunta el **XML y el PDF** a esta misma factura de proveedor (clip del chatter). Revisa que el **RFC emisor** sea el del instalador o el de su empresa, que el **receptor** sea OhmSafe y que el **total** coincida con el monto capturado.
4. **Fecha de factura** = fecha del CFDI; **fecha de vencimiento** según el acuerdo con el instalador.
5. **Confirmar** (botón *Confirmar*). Ya cuenta como cuenta por pagar.
6. **Registrar pago desde la factura**: botón *Registrar pago* dentro de la factura › diario (banco con el que se transfiere) › fecha › *Crear pago*. La factura queda **Pagada** y el pago aparece solo en Proveedores › Pagos. Si pagas varias facturas del mismo instalador en una transferencia, selecciónalas en la lista y usa *Registrar pago* una sola vez.
7. El instalador ve el movimiento en la app, en **Mis pagos**: «$0 · En revisión» mientras la factura esté en borrador; después, el monto y si ya está pagada.

## Reglas para no perder el control

| Haz | No hagas | Por qué |
|---|---|---|
| Usa siempre **Factura de proveedor** | No la conviertas en **Recibo de compra** | El recibo es para gastos sin CFDI: no es deducible y el instalador **deja de ver el pago en la app** («Mis pagos» sólo lee facturas de proveedor). Pasó con la i47 (13-oct-2026) y se regresó a factura el 19-oct |
| **Registra el pago dentro de la factura** | No crees pagos sueltos en Proveedores › Pagos | Un pago suelto no queda ligado: la factura sigue «no pagada» y la deuda con el instalador aparece doble |
| Adjunta **XML y PDF** del CFDI antes de confirmar | No confirmes sin comprobante, salvo acuerdo con contabilidad | Sin CFDI el gasto no es deducible |
| Entra con **tu propio usuario** de Odoo | Evita la cuenta compartida «OhmSafe» para tocar pagos | En el historial queda **quién** cambió montos o tipos; con la cuenta compartida no se sabe |
| Pregunta a contabilidad por **retenciones** | No las inventes | Si el instalador es **persona física** y factura servicios a OhmSafe pueden aplicar retenciones de ISR e IVA; las define el contador y Odoo las calcula con el impuesto correcto en la línea |

## Control contable: dónde se ve

| Qué quieres saber | Dónde |
|---|---|
| Lo que se le debe a cada instalador | Contabilidad › Proveedores › Facturas › filtro **Por pagar** (o Informes › Antigüedad de cuentas por pagar) |
| Lo que ya se le pagó | La factura en **Pagada**; Contabilidad › Proveedores › Pagos |
| El pago de una intervención concreta | Planificación › intervención › propiedad «Pago al instalador (factura proveedor id)», o buscar «Intervención i…» en las facturas de proveedor |
| Lo cobrado al cliente por esa misma intervención | Propiedad «Factura al cliente (id)» de la intervención; Contabilidad › Clientes › Facturas |

## Cuando el servicio NO se cerró desde la app

Pasa cuando la instalación sí se hizo pero la intervención se cerró a mano en Odoo (p. ej. una prueba, o la app no pudo vincular). En ese caso **no existe la factura**; se crea igual que las automáticas:

1. Contabilidad › Proveedores › Facturas › **Nuevo**.
2. **Proveedor**: el contacto del instalador.
3. **Referencia de factura**: «Intervención i*N* · S00*xxx*» (así se encuentra igual que las automáticas y la app la muestra en Mis pagos).
4. **Línea**: producto `PAGO-INSTALACION` (o el que corresponda), cantidad 1, precio = el monto negociado con el instalador.
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

- **Tabulador**: por decisión del 8 de octubre de 2026 **no se configura** por ahora; se opera a mano unos meses y queda por explorar (opción A manual por servicio / opción B tabulador por concepto, hoja de cálculo enviada a Operaciones el 2026-09-27).
- **Comisión por venta** del instalador (código de venta `OHMS-…`): no está implementada; se pagaría también como factura de proveedor cuando se defina.
- El instalador **no sube factura CFDI** desde la app; si factura a OhmSafe, el PDF/XML se adjunta a la factura de proveedor en Odoo (paso 3).
- **Validación automática del CFDI** contra el SAT y **retenciones** configuradas: pendientes de definir con contabilidad.
