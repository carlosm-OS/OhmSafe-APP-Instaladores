# Pagar un servicio al instalador desde Odoo (guía de operaciones)

> **USO INTERNO — no publicar.** Para operaciones y contabilidad de OhmSafe. Describe cómo queda el pago de cada servicio al instalador externo y qué hacer en los casos que la app no cubre.
>
> Para contabilidad, la referencia completa (factura vs CFDI, cada campo, apuntes contables y pendientes) está en **Manual de Contabilidad OhmSafe › Pago a instaladores: factura de proveedor y CFDI**.

## En una frase

Cada servicio cerrado genera una **factura de proveedor en borrador y en $0** a nombre del instalador. Operaciones (Lily, auxservicios@) le pone **el monto que negoció con el instalador**, la **confirma** y, al transferir, **registra el pago**. Nada se paga solo.

> **Operación vigente (decisión de Carlos, 8 de octubre de 2026):** durante los próximos meses se opera «en maqueta»: **no hay tabulador ni costos configurados** en los productos `PAGO-*`. El importe de cada servicio lo captura a mano operaciones en la factura, según lo acordado con cada instalador. No cambies el *Costo* de los productos `PAGO-*`.

## Factura de Odoo y CFDI no son lo mismo

| | **Factura de proveedor (Odoo)** | **CFDI (SAT)** |
|---|---|---|
| Qué es | Un **registro contable** en nuestra base de datos: lo que le debemos al instalador y, después, lo que ya le pagamos | El **comprobante fiscal** electrónico (XML timbrado, con **folio fiscal / UUID**) que vale ante el SAT |
| Quién la hace | **OhmSafe** (el sistema la crea en borrador al cerrar el servicio) | **El instalador o su empresa**: la emite desde su sistema o el portal del SAT, a nombre de OhmSafe |
| Para qué sirve | Controlar cuentas por pagar, pagos y costo de cada intervención | Que el gasto sea **deducible** y el IVA **acreditable** |
| Cómo se unen | Se **adjunta el XML y el PDF** del CFDI a la factura de Odoo, y su serie-folio va en «Referencia de factura» | — |

Puede existir la factura de Odoo sin CFDI (por ejemplo, mientras el instalador no factura), pero **sin CFDI el gasto no es deducible**. Odoo no «emite» el CFDI del instalador: sólo lo registra. (En las facturas **a clientes** es al revés: el CFDI lo emite OhmSafe.)

**Qué revisar en el CFDI del instalador antes de confirmar:** RFC del **emisor** = el del instalador (o su empresa); RFC del **receptor** = OhmSafe; **total** igual al de la factura de Odoo; **método de pago**: *PUE* (pago en una sola exhibición) o *PPD* (pago diferido; en ese caso, después de pagarle, el instalador debe mandar su **complemento de pago**); que el **folio fiscal (UUID)** esté vigente (verificador del SAT).

## La factura de proveedor, campo por campo

**Barra superior**

| Campo / botón | Qué significa | Qué hacer |
|---|---|---|
| **Confirmar** | Pasa la factura de *Borrador* a *Registrado*: entra a contabilidad como deuda | Sólo cuando el monto y el CFDI estén revisados |
| **Cancelar** | Anula la factura en borrador | Sólo si ese servicio no se le va a pagar (avisa en el chatter de la intervención) |
| **Borrador → Registrado** | Estado contable | Después de *Registrado* aparece **Registrar pago** |
| **Factura / Recibo** | Tipo de documento | Siempre **Factura** (el recibo es para gastos sin CFDI y el instalador no lo ve en la app) |
| **BILL/2026/10/0001** | **Folio interno de Odoo**, consecutivo de nuestra base de datos | No es el folio del CFDI |

**Encabezado**

| Campo | Qué significa | Qué hacer |
|---|---|---|
| **Proveedor** | El instalador (o su empresa si la tiene en su ficha), con la dirección y el **RFC** de su ficha | El RFC debe ser el mismo que el del emisor del CFDI; si no, corrígelo en la ficha del contacto |
| **Referencia de factura** | El sistema pone «Intervención i47 · S00255» para ligarla al servicio | Cuando llegue el CFDI puedes cambiarla por su **serie-folio**; la liga con la intervención no se pierde (va en *Otra información › Documento origen* = «i47») |
| **Autocompletar** | Llenar las líneas desde una orden de compra o una factura anterior | No se usa en pagos a instaladores |
| **Fecha de la factura** | Fecha del comprobante | Pon la **fecha del CFDI** |
| **Fecha contable** | Mes en que el gasto entra a contabilidad | Normalmente igual a la fecha de la factura; si ese mes ya está cerrado, el mes en curso (lo decide contabilidad) |
| **Referencia de pago** | El concepto que irá en la transferencia | Si queda vacío usa la referencia de factura |
| **Banco receptor** | La cuenta (**CLABE**) del instalador a la que se transfiere | Se da de alta en su ficha de contacto › pestaña Contabilidad › Cuentas bancarias; sin ella no hay a dónde pagar |
| **Fecha de vencimiento / Términos de pago** | Cuándo hay que pagarle | Sin términos vence el mismo día de la factura y sale **en rojo** (vencida). Pon el plazo acordado con el instalador |
| **Moneda** | MXN | — |

**Líneas de factura**

| Columna | Qué significa | Qué hacer |
|---|---|---|
| **Etiqueta** | Descripción del servicio pagado | El sistema la llena con el tipo de servicio y la intervención |
| **Cuenta** | Cuenta contable del gasto. Hoy sale **601.84.01 Otros gastos generales** porque el producto `PAGO-INSTALACION` no tiene cuenta propia | Que el **contador defina la cuenta** correcta (p. ej. costo de instalación) y se configure **una vez** en los productos `PAGO-*`; desde ahí todas las facturas salen bien |
| **Cantidad / Unidad** | 1 servicio | — |
| **Precio** | Monto negociado **sin IVA** | Lo captura operaciones (en maqueta no hay tabulador) |
| **Impuestos** | **IVA 16% acreditable** | Si aplican **retenciones** de ISR/IVA (persona física), se agregan aquí con el impuesto que indique el contador |
| **Importe** | Precio × cantidad | — |
| **Agregar una línea** | Conceptos extra | Viáticos o material que puso el instalador, con su comprobante |
| Nota «Sin tarifa configurada…» | Aviso interno del sistema: la factura nació en $0 | Puedes borrarla después de capturar el monto; no la ve el instalador |

**Totales**: *Subtotal* (sin IVA), *IVA 16%*, *Total*, y **Cantidad por pagar**, que baja a $0 cuando se registra el pago.

**Pestaña «Apuntes contables»** — lo que Odoo registra al confirmar (ejemplo de la i47, $2,000 + IVA):

| Cuenta | Debe | Haber | Significado |
|---|---|---|---|
| 601.84.01 Otros gastos generales | 2,000 | | El gasto del servicio |
| 119.01.01 IVA pendiente de pago | 320 | | IVA que **se podrá acreditar cuando se pague** (en México el IVA se acredita al pago) |
| 201.01.01 Proveedores nacionales | | 2,320 | La deuda con el instalador |

Al **registrar el pago**: se carga *Proveedores* y se abona el *Banco* por $2,320 (la deuda queda en cero), y el IVA pasa de «pendiente» a «acreditable pagado».

**Chatter (derecha)**: historial de quién cambió qué y cuándo; ahí se adjuntan el **XML y PDF** del CFDI con el clip.

## Cómo resolver un pago, de principio a fin

1. Servicio cerrado en la app → factura de proveedor en **borrador** con la referencia «Intervención i…».
2. Operaciones captura el **monto negociado** y los extras.
3. El instalador manda su **CFDI** → se revisa (emisor, receptor, total, PUE/PPD, UUID vigente).
4. Se adjuntan **XML y PDF**, *Referencia de factura* = serie-folio del CFDI, *Fecha de la factura* = fecha del CFDI.
5. **Confirmar**.
6. Se transfiere a su **Banco receptor** y se pulsa **Registrar pago** dentro de la factura.
7. Si el CFDI era **PPD**, pedirle el **complemento de pago**.

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
