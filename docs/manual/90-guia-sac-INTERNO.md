# Guía SAC — App OhmSafe Installer

> **USO INTERNO — no publicar.** Este archivo no se sube a Odoo › Conocimiento. Es para soporte/SAC y operaciones. Describe la build 1.0.0 (24).

## Antes de diagnosticar: tres preguntas

1. **¿De dónde instaló la app y qué build tiene?** La app todavía no muestra su versión. En **iPhone con TestFlight**, TestFlight muestra el número de build. En **Google Play** sólo aparece «1.0.0» (todas las builds se llaman así): ahí basta confirmar que la instaló de la tienda.
   - **Tienda (Google Play / App Store):** siempre **producción**. Hoy la de tienda es la **build 47** (17-oct-2026).
   - **TestFlight:** puede ser de producción o de **pruebas**. Las notas «Qué probar» de cada build dicen a qué servidor apunta. Hoy: **48 = producción**; **49 = servidor de pruebas** (api-dev), sólo para el equipo interno.
   - Un instalador real **nunca** debe trabajar con una build de pruebas: sus avisos, sesiones y equipos vinculados quedan en el servidor de pruebas. Si la tiene, que instale la de la tienda (o la 48) antes de cualquier otra cosa. Lo mismo con builds 23 o anteriores.
   - Detalle por build: [Novedades por versión](99-novedades.md).
2. **¿Qué intervención es?** En la app, cada tarjeta de la agenda muestra el **número de intervención** (por ejemplo **i47**) en una pastilla a la derecha del cliente (desde la build 39), además de la «Orden de venta» (S00…). También sale en la campana («Orden #i47»), en incidencias y en «Mis pagos» («Intervención i47 · S00255»).
   - En Odoo: Planificación › escribe **i47** en el buscador › «Buscar Número de intervención». La tarjeta de la agenda muestra la **píldora del paso** en que va el instalador (Agendada, En ruta, En sitio · …, Completada, Cancelada en sitio); clic en «Intervención i47» abre la ficha completa con el historial. Detalle en «Intervenciones en Planificación: procesos, tipos y correos al cliente».
3. **¿Qué mensaje exacto ve y a qué hora pasó?** Pide captura. Los textos de la app están en el manual público (01–07); la hora ayuda a encontrarlo en el historial de la intervención.

## Dónde se verifica cada cosa

| Qué | Dónde |
|---|---|
| Estado del instalador (Activo / Temporalmente no disponible / Suspendido), alta completa, número de instalador, código de venta, empresa | Odoo › Contactos › ficha del instalador (formulario «Instalador externo»); barra *Avance de alta* y chatter («Activó su cuenta en la app»). Si factura por una empresa, aparece en el campo **Empresa** |
| Que pueda recibir trabajo | Ficha del instalador: campo «Recurso en Planificación» lleno y Estado «Activo» (el recurso es *material*, no empleado). Sin recurso, la app le muestra la agenda vacía |
| Agenda / intervención | Odoo › Planificación › buscar **i47**: número de intervención, **píldora de paso** (en qué va el instalador), recurso, fecha y fin. Las completadas salen en **verde** y con listón «Completada» |
| Avance del servicio en la app | Propiedades de la intervención: `op_hora_salida` (inició ruta), `op_hora_llegada` + `op_llegada_lat/lng` (llegada), `op_vinculado`, `op_serie`, `op_mac`, `op_tierra_confirmada`, `op_cancelada` / `op_motivo_cancelacion` / `op_cancelada_en`, `op_cierre_lat/lng` / `op_cierre_distancia_m`, `op_prueba_terminada` (terminó u omitió la prueba del energizador). La píldora de paso resume todo esto |
| Inspección, materiales, entrega | Pestaña **Hoja de trabajo** («Instalación de cerca eléctrica»): `insp_*`, `inst_*`, `ent_*` |
| Bitácora | Chatter de la intervención: «Llegada al sitio», «Materiales instalados», «Cancelada en sitio por el técnico», «Cierre lejos de la llegada», «Reintento tras cancelación en sitio», avisos al instalador |
| Fotos | Adjuntos de la intervención |
| Serie del energizador | Odoo › Inventario › Números de serie/lotes (producto Ohmbox/Energizador): existencias y ubicación; entrega de la orden de venta (línea «Energizador» con la serie) |
| Equipo y su titular | Dashboard de producción › Dispositivos: buscar por serie o MAC; ver titular (OWNER) y casa |
| Cuenta del cliente en la app | Dashboard de producción › Clientes: buscar por el correo del contacto de Odoo |
| Incidencias | Odoo › Servicio de asistencia › «Incidencias de campo» |
| Pagos al instalador | Odoo › Contabilidad › **Proveedores › Facturas**: factura de proveedor en borrador creada al cerrar, referencia «Intervención i… · S…». Paso a paso en «Pagar un servicio al instalador desde Odoo» y, para contabilidad, en el Manual de Contabilidad |
| Push | Contacto del instalador en Odoo: tokens push y zona horaria (`tz`) que registra la app al entrar |

## Preguntas frecuentes de instaladores

**No me llega el código.**
Causas posibles, en orden: (1) el correo no es el registrado en su contacto de Odoo; (2) su alta está incompleta: en vez del código le llega «Tu alta como instalador está en proceso — OhmSafe» (mientras duren las pruebas sólo frenan nombre, correo, teléfono y foto; CURP, RFC y constancia no); (3) está **Suspendido**: no se le manda código y la app no lo dice; (4) cayó en spam; (5) pidió más de 8 códigos en el día («Pediste demasiados códigos hoy…»). Entre un envío y otro hay 60 s de espera. El código vence a los 10 min y admite 5 intentos.

**«Tu cuenta de instalador está suspendida. Contacta a OhmSafe.»**
Estado = Suspendido en su contacto. Solo se quita cambiando el Estado en Odoo (decisión de OhmSafe).

**No veo mis instalaciones.**
Revisar: intervención en **Borrador** (el instalador no la ve hasta que se **Publica**); recurso distinto al del instalador; instalador sin **Recurso en Planificación** o con Estado distinto de «Activo»; intervención cancelada (se va a Historial); build de **pruebas** (ver arriba). Pedirle que jale hacia abajo para recargar. «Pendientes de agendar» = publicada sin fecha.

**No me llegan las notificaciones.**
El token se registra al iniciar sesión. Revisar permisos de notificaciones en el teléfono y que el contacto tenga token. Pedir que cierre sesión y vuelva a entrar. Desde la build 48, al cerrar sesión el teléfono deja de recibir los avisos de esa cuenta: si comparte teléfono con otro instalador, sólo recibe los de la cuenta con la que está dentro.

**«No se pudo iniciar la ruta: Esta intervención aún no está programada…»**
La intervención no tiene fecha. Operaciones debe agendarla desde el Gantt y publicarla.

**Me salí a medio servicio.**
La app retoma sola: la tarjeta dice «Continuar · …». El paso se deduce de lo guardado en Odoo (propiedades `op_*` y hoja de trabajo).

**«Estás lejos del sitio» al cerrar.**
El cierre está a más de 300 m de la llegada. Puede confirmar con «Sí, cerrar aquí»; queda nota «Cierre lejos de la llegada» en el chatter. Si marcó la llegada sin GPS, no hay referencia y no se valida distancia.

**Una foto dice «No se subió · Reintentar».**
Señal mala. Que toque la tarjeta para reintentar; al cerrar la app reintenta sola. Errores posibles del servidor: imagen vacía, mayor al límite, que no sea JPEG/PNG, u Odoo no la guardó («Odoo no almacenó la foto; inténtalo de nuevo»).

**Quiero corregir mis datos / mi foto / mi cuenta bancaria.**
Datos y foto: Odoo › Contactos (la foto oficial es la del contacto; ya no hay ficha de empleado). RFC: lo captura él en Facturación. Si factura a través de una **empresa**, OhmSafe la pone en el campo Empresa de su ficha y su RFC pasa a ser el de la empresa. La pantalla «Datos bancarios» de la app no envía nada a OhmSafe en esta build.

**Un pago no coincide.**
Los pagos nacen en borrador al cerrar («En revisión»). Se trabajan en Contabilidad › Proveedores › Facturas. Si un pago **no aparece** en «Mis pagos», revisar que siga siendo **Factura de proveedor**: si alguien lo cambió a «Recibo de compra», la app deja de mostrarlo. Si el monto no coincide, que lo reporte como incidencia.

**«Esperando señal…» al vincular o en la prueba.**
El equipo aún no reporta: uno recién encendido tarda 1 o 2 minutos y la pantalla revisa sola cada 5 s. A los 3 minutos cambia a «Sin señal reciente». Sin señal **sí puede vincular**; la **Prueba del energizador** necesita corriente y señal. Verificar en Dashboard prod › Dispositivos el último reporte; si nunca reporta, revisar luz y conexión del equipo.

**«Equipo nuevo: se da de alta al vincularlo».**
Normal: el equipo no existía en el monitoreo y se crea solo al vincular, con la serie y la MAC de su lote en Odoo. No hay que darlo de alta antes en el dashboard.

**Prueba del energizador / Agregar dispositivos (pasos 5 y 6).**
Ambos son opcionales. En la prueba el instalador controla la cerca del cliente sólo mientras la pantalla está abierta. En «Agregar dispositivos» se agrega sólo lo que el cliente compró y cada cosa se guarda sólo si la prueba en vivo funciona. Las puertas con cable, sirena y salidas piden firmware 2.10 o superior. Los sensores y cámaras **Wi‑Fi** (EZVIZ y Tuya) sólo aparecen desde la build 49 (hoy de pruebas); con Tuya, el cliente debe haber entrado una vez a OhmSafe GO.

## Errores de serie y vinculación: causa real y solución

| Mensaje / código | Causa real | Solución operativa | Cómo verificar |
|---|---|---|---|
| «…no está en el inventario de Ohmbox…» (`SERIE_NO_EN_INVENTARIO`) | No existe un número de serie con ese nombre para el producto Ohmbox/Energizador (modo estricto encendido). | Confirmar la etiqueta física. Si el equipo es bueno, dar de alta la serie en Inventario (con su MAC) y recibirla en almacén. | Inventario › Números de serie: buscar la serie exacta. |
| «…ya está registrado como instalado con otro cliente…» (`SERIE_YA_INSTALADA`) | La serie tiene existencia en una ubicación de cliente: ya se entregó en otra venta. | Revisar si es error de etiqueta o un equipo recuperado. Si se recuperó, regresarlo a almacén con un movimiento de inventario. | Inventario › Números de serie › ubicación actual. |
| «…no aparece en el almacén…» (`SERIE_SIN_EXISTENCIA`) | La serie existe pero no tiene existencia en una ubicación interna. | Recibir/ajustar inventario para esa serie. | Existencias de la serie por ubicación. |
| «…ya está apartado para otra instalación (S0…)…» (`SERIE_APARTADA`) | La serie está reservada en una entrega pendiente de **otra** orden de venta (la del paréntesis). | Si el instalador se llevó otro equipo, liberar la serie de esa entrega o que use el equipo asignado. | Entrega pendiente de la orden indicada: línea con esa serie. |
| «Al equipo … le falta un dato en almacén (su MAC)…» (`SIN_ALTA`) | El equipo no existe en el monitoreo de producción **y** su serie en Odoo no tiene MAC; sin MAC no se puede dar de alta solo. | Capturar la MAC en Inventario › Números de serie › OS-OBV01-#### (o al dar de alta/editar el equipo en el dashboard, que la pasa al lote). Luego el instalador vuelve a escanear y le saldrá «Equipo nuevo». | Inventario › Números de serie: columna MAC; Dashboard prod › Dispositivos por serie y MAC. |
| «Esperando señal…» / «Sin señal reciente» | El equipo no ha reportado en los últimos minutos. Desde la build 31 **ninguna prueba bloquea** la vinculación (se retiraron batería, línea y tierra física). | Si a los 3 min sigue sin señal: revisar luz y conexión del equipo. Puede vincular igual; para la prueba del paso 5 sí necesita señal. | Dashboard prod › Dispositivos › último reporte. |
| Aviso «…todavía no tiene cuenta en la app OhmSafe con el correo de su contrato…» (`CLIENTE_SIN_CUENTA`) | El correo del contacto (cliente) de la intervención en Odoo no coincide con ninguna cuenta de la app de clientes en producción (o el contacto no tiene correo). La vinculación en Odoo sí quedó. | Pedir al cliente que cree su cuenta con **el mismo correo de Odoo**, o corregir el correo del contacto en Odoo. Después, ligar el equipo a su cuenta. | Correo del contacto en Odoo vs. Dashboard prod › Clientes. |
| Aviso «Este equipo ya está dado de alta con otro cliente en el dashboard…» (`EQUIPO_DE_OTRO_TITULAR`) | El equipo ya tiene otro titular activo en producción, o su MAC está en un equipo de otro titular. No se le quita en silencio. | Confirmar etiqueta. Si es un error de alta, corregir el titular en el dashboard y volver a vincular. | Dashboard prod › Dispositivos › titular. |
| «No se pudo enviar el cierre: …» con texto de Odoo sobre número de serie | Odoo valida la entrega de material al completar; si la serie no quedó asignada en la entrega, rechaza el cierre. | Revisar la entrega de la orden de venta (línea «Energizador» con su serie) y que el paso de vinculación se haya hecho. | Orden de venta › Entrega. |

## A qué servidor apunta cada build

- **Builds de tienda** (Google Play / App Store): producción.
- **TestFlight**: depende de la build; lo dicen sus notas «Qué probar». Hoy la **48** es de producción y la **49** del servidor de pruebas.
- **Builds 23 y anteriores**: servidor de pruebas. Lo que se vinculó con ellas pudo quedar en el dashboard de **dev**, no en la cuenta real del cliente.
- Al pasar de una build de pruebas a una de producción (o al revés) pide entrar de nuevo con su contraseña: cada servidor tiene sus propias sesiones.
- Si el instalador ve datos «de prueba» o no ve un servicio publicado, lo primero es confirmar de dónde instaló la app.

## Comportamientos de la app que confunden

- **Terminar instalación** (botón final de la lista de pasos) no envía nada: el cierre real ya se mandó con «Terminar instalación» en la pantalla de firma. Si el instalador sale sin tocarlo, el servicio ya está cerrado.
- En la pantalla de vincular («Busca el energizador»), el botón «Reportar incidencias (opcional)» abre la **cancelación**, no una incidencia.
- Desde la build 25, **Ayuda › «Reportar incidencias»** abre el formulario real (el mismo de Inicio) y crea el ticket en Helpdesk › «Incidencias de campo». En builds 24 o anteriores ese botón no enviaba nada aunque dijera «Reporte enviado correctamente»: pide que actualice.
- Desde la build 25, Ayuda muestra y marca el número real de soporte (55 5199 1396), también por WhatsApp. En builds anteriores se mostraban números de ejemplo y el enlace de WhatsApp no abría el chat correcto.
- Las fotos del cierre dicen «Verificado» al tomarlas; la app no verifica la posición de cada foto. La única validación de ubicación es la del cierre contra la llegada (300 m).
- «Contrato firmado: Pendiente» aparece siempre en la tarjeta.
- Los contadores de materiales arrancan en 5, 5, 5, 5, 1 y 3; si el instalador no los ajusta, se guardan así.
- Los mantenimientos usan los pasos de la instalación, incluida la vinculación.

## Cancelación en sitio: qué hace el sistema

1. Marca la intervención como cancelada (`op_cancelada`, motivo y hora) y deja nota «Cancelada en sitio por el técnico» con motivo, técnico y ubicación; la foto queda adjunta.
2. Si no había llegada, la regresa a borrador sin fecha. Si ya había iniciado, crea una **intervención nueva** «por planificar» sobre la misma línea de venta (hereda los datos de la llamada con el cliente) y la iniciada se conserva acortada a lo realmente ocupado.
3. Abre un **ticket en Helpdesk › «Reagendamientos»** («Reagendar — cliente — motivo»), asignado a operaciones (auxservicios@), con contacto = cliente, teléfono, dirección, motivo, notas del técnico, fecha original, técnico, ubicación, la foto adjunta y la liga a la intervención (campo «Intervención»). Trae la actividad «Llamar al cliente para reagendar» (vence el mismo día) y manda un mensaje con el resumen a operaciones y a los seguidores (Santiago, Carlos). Al cliente no le llega aviso automático.
4. Cuando operaciones vuelve a **publicar** la intervención con fecha e instalador, el ticket pasa solo a **«Reagendada»** y su actividad se cierra. Si el cliente desiste: mover el ticket a «Cliente desistió» y cancelar la venta.

### Cómo trabaja operaciones la cola «Reagendamientos»

- Helpdesk › Reagendamientos. Etapas: **Por contactar** (recién cancelada) → **Contactado** (ya hablé con el cliente; pon la nueva fecha en Planeación) → **Reagendada** (se cierra sola al publicar) · **Cliente desistió** (cerrada a mano).
- Desde el ticket, el campo «Intervención» abre la intervención en Planeación; desde la intervención, el chatter tiene la nota «Cancelada en sitio por el técnico».
- **Incidencias de la app** (Helpdesk › «Incidencias de campo»): desde el 7-oct llegan igual que las cancelaciones: asignadas a operaciones (auxservicios@), con resumen legible (tipo, qué pasó, cliente con teléfono, dirección y Maps) y actividad «Atender incidencia». El cliente no recibe nada; el instalador sí sigue su ticket.
- Si falta el equipo «Reagendamientos» en Odoo (por ejemplo en una base nueva), la app cae al mecanismo anterior: actividad «Cancelada en sitio: llamar al cliente» sobre la intervención. Se crea con `scripts/setup-odoo-reagendamientos.mjs` del backend.

## Equipos nuevos: qué tiene que estar listo antes de la instalación

Desde la build 30 **ya no hay que dar de alta el energizador en el dashboard**: si no existe en el monitoreo, se crea solo al vincularlo y queda en la cuenta del cliente. Para que eso funcione:

1. La serie **OS-OBV01-####** debe existir en Odoo (Inventario › Números de serie, producto Ohmbox/Energizador) y estar **en almacén**.
2. Esa serie debe tener su **MAC** capturada (columna «MAC Address»). Se captura a mano en Odoo, en bloque con el script de carga de MACs del backend, o al dar de alta/editar el equipo en el dashboard (la MAC pasa sola al lote).
3. El cliente debe tener cuenta en la app OhmSafe **con el mismo correo de su contrato**; si no, el equipo se vincula pero no aparece en su app hasta que se ligue (aviso «Vinculado, pero falta la cuenta del cliente»).

Dar de alta el equipo en el dashboard antes sigue funcionando: si queda a nombre de personal de OhmSafe, al vincularlo en campo pasa solo a la cuenta del cliente; si está a nombre de **otro cliente**, la app avisa y no lo mueve.

## Series de prueba (OS-PRUEBA-0001 … 0005)

Son series **sólo para probar la app** en producción; nunca se entregan a un cliente real.
Llevan la MAC del energizador de pruebas de OhmSafe y sólo funcionan con el cliente de prueba
«Carlos M TestFlight». Si ves una serie OS-PRUEBA en una entrega, una suscripción o en el
dashboard, es una prueba que no se reinició: avisa al equipo de producto para que corra el
reinicio (`scripts/pruebas-instalador.mjs` en el backend; detalle en `docs/pruebas-instalador.md`).
No las cuentes como inventario vendible.
