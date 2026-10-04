# Guía SAC — App OhmSafe Installer

> **USO INTERNO — no publicar.** Este archivo no se sube a Odoo › Conocimiento. Es para soporte/SAC y operaciones. Describe la build 1.0.0 (24).

## Antes de diagnosticar: tres preguntas

1. **¿Qué build tiene?** La app no muestra su versión. Pídele que la vea en TestFlight (iPhone) o en la ficha de Google Play (Android). Desde la **build 24** la app habla con **producción**; las builds 23 y anteriores hablan con el servidor de pruebas (api-dev). Si tiene 23 o menos: que actualice antes de cualquier otra cosa.
2. **¿Qué intervención es?** En la app se ve la «Orden de venta» (S0…) en la tarjeta, y el id de la intervención (i…) en la campana («Orden #i…»), en incidencias y en «Mis pagos» («Intervención i… · S0…»).
3. **¿Qué mensaje exacto ve?** Pide captura. Los textos de la app están en el manual público (01–07).

## Dónde se verifica cada cosa

| Qué | Dónde |
|---|---|
| Estado del instalador (Activo / Temporalmente no disponible / Suspendido), alta completa, número de instalador, código de venta | Odoo › Contactos › ficha del instalador (formulario «Instalador externo»); barra *Avance de alta* y chatter («Activó su cuenta en la app») |
| Que pueda recibir trabajo | Odoo › Empleados: debe tener ficha de empleado con recurso. Sin recurso, la app le muestra la agenda vacía |
| Agenda / intervención | Odoo › Planificación › intervención: estado (Borrador / Publicado / En curso / Completado), recurso, fecha y fin |
| Avance del servicio en la app | Propiedades de la intervención: `op_hora_salida` (inició ruta), `op_hora_llegada` + `op_llegada_lat/lng` (llegada), `op_vinculado`, `op_serie`, `op_mac`, `op_tierra_confirmada`, `op_cancelada` / `op_motivo_cancelacion` / `op_cancelada_en`, `op_cierre_lat/lng` / `op_cierre_distancia_m` |
| Inspección, materiales, entrega | Pestaña **Hoja de trabajo** («Instalación de cerca eléctrica»): `insp_*`, `inst_*`, `ent_*` |
| Bitácora | Chatter de la intervención: «Llegada al sitio», «Materiales instalados», «Cancelada en sitio por el técnico», «Cierre lejos de la llegada», «Reintento tras cancelación en sitio», avisos al instalador |
| Fotos | Adjuntos de la intervención |
| Serie del energizador | Odoo › Inventario › Números de serie/lotes (producto Ohmbox/Energizador): existencias y ubicación; entrega de la orden de venta (línea «Energizador» con la serie) |
| Equipo y su titular | Dashboard de producción › Dispositivos: buscar por serie o MAC; ver titular (OWNER) y casa |
| Cuenta del cliente en la app | Dashboard de producción › Clientes: buscar por el correo del contacto de Odoo |
| Incidencias | Odoo › Servicio de asistencia › «Incidencias de campo» |
| Pagos al instalador | Odoo › Compras: factura de proveedor en borrador creada al cerrar |
| Push | Contacto del instalador en Odoo: tokens push y zona horaria (`tz`) que registra la app al entrar |

## Preguntas frecuentes de instaladores

**No me llega el código.**
Causas posibles, en orden: (1) el correo no es el registrado en su contacto de Odoo; (2) su alta está incompleta: en vez del código le llega «Tu alta como instalador está en proceso — OhmSafe»; (3) está **Suspendido**: no se le manda código y la app no lo dice; (4) cayó en spam; (5) pidió más de 8 códigos en el día («Pediste demasiados códigos hoy…»). Entre un envío y otro hay 60 s de espera. El código vence a los 10 min y admite 5 intentos.

**«Tu cuenta de instalador está suspendida. Contacta a OhmSafe.»**
Estado = Suspendido en su contacto. Solo se quita cambiando el Estado en Odoo (decisión de OhmSafe).

**No veo mis instalaciones.**
Revisar: intervención en **Borrador** (el instalador no la ve hasta que se **Publica**); recurso distinto al del instalador; instalador sin ficha de empleado/recurso; intervención cancelada (se va a Historial). Pedirle que jale hacia abajo para recargar. «Pendientes de agendar» = publicada sin fecha.

**No me llegan las notificaciones.**
El token se registra al iniciar sesión. Revisar permisos de notificaciones en el teléfono y que el contacto tenga token. Pedir que cierre sesión y vuelva a entrar.

**«No se pudo iniciar la ruta: Esta intervención aún no está programada…»**
La intervención no tiene fecha. Operaciones debe agendarla desde el Gantt y publicarla.

**Me salí a medio servicio.**
La app retoma sola: la tarjeta dice «Continuar · …». El paso se deduce de lo guardado en Odoo (propiedades `op_*` y hoja de trabajo).

**«Estás lejos del sitio» al cerrar.**
El cierre está a más de 300 m de la llegada. Puede confirmar con «Sí, cerrar aquí»; queda nota «Cierre lejos de la llegada» en el chatter. Si marcó la llegada sin GPS, no hay referencia y no se valida distancia.

**Una foto dice «No se subió · Reintentar».**
Señal mala. Que toque la tarjeta para reintentar; al cerrar la app reintenta sola. Errores posibles del servidor: imagen vacía, mayor al límite, que no sea JPEG/PNG, u Odoo no la guardó («Odoo no almacenó la foto; inténtalo de nuevo»).

**Quiero corregir mis datos / mi foto / mi cuenta bancaria.**
Datos y foto: Odoo (Contactos para datos, Empleados para foto). RFC: lo captura él en Facturación. La pantalla «Datos bancarios» de la app no envía nada a OhmSafe en esta build.

**Un pago no coincide.**
Los pagos nacen en borrador al cerrar («En revisión»). Validarlos en Compras. Si no coincide, que lo reporte como incidencia.

## Errores de serie y vinculación: causa real y solución

| Mensaje / código | Causa real | Solución operativa | Cómo verificar |
|---|---|---|---|
| «…no está en el inventario de Ohmbox…» (`SERIE_NO_EN_INVENTARIO`) | No existe un número de serie con ese nombre para el producto Ohmbox/Energizador (modo estricto encendido). | Confirmar la etiqueta física. Si el equipo es bueno, dar de alta la serie en Inventario (con su MAC) y recibirla en almacén. | Inventario › Números de serie: buscar la serie exacta. |
| «…ya está registrado como instalado con otro cliente…» (`SERIE_YA_INSTALADA`) | La serie tiene existencia en una ubicación de cliente: ya se entregó en otra venta. | Revisar si es error de etiqueta o un equipo recuperado. Si se recuperó, regresarlo a almacén con un movimiento de inventario. | Inventario › Números de serie › ubicación actual. |
| «…no aparece en el almacén…» (`SERIE_SIN_EXISTENCIA`) | La serie existe pero no tiene existencia en una ubicación interna. | Recibir/ajustar inventario para esa serie. | Existencias de la serie por ubicación. |
| «…ya está apartado para otra instalación (S0…)…» (`SERIE_APARTADA`) | La serie está reservada en una entrega pendiente de **otra** orden de venta (la del paréntesis). | Si el instalador se llevó otro equipo, liberar la serie de esa entrega o que use el equipo asignado. | Entrega pendiente de la orden indicada: línea con esa serie. |
| «El equipo … no está dado de alta en el dashboard. Avisa a operaciones.» (`SIN_ALTA`) | En la base de **producción** no existe un equipo con esa serie ni con la MAC registrada en la serie de Odoo. Desde la build 24 esto se revisa contra producción: equipos que solo existían en dev ya no cuentan. | Dar de alta el equipo en el dashboard de producción con la serie OS-OBV01-… y su MAC, y que reporte. Luego el instalador toca «Vincular» otra vez. | Dashboard prod › Dispositivos: buscar por serie y por MAC. |
| Pruebas en rojo / gris | Telemetría del equipo: línea = energía de la calle; batería = estado de batería (sin dato = gris «Pendiente», bloquea); alto voltaje = cerca armada. No se exige «Equipo en línea». | Revisar instalación física; si la batería nunca reporta, revisar el equipo en el dashboard. | Dashboard › Dispositivos › estado y último reporte. |
| Aviso «…todavía no tiene cuenta en la app OhmSafe con el correo de su contrato…» (`CLIENTE_SIN_CUENTA`) | El correo del contacto (cliente) de la intervención en Odoo no coincide con ninguna cuenta de la app de clientes en producción (o el contacto no tiene correo). La vinculación en Odoo sí quedó. | Pedir al cliente que cree su cuenta con **el mismo correo de Odoo**, o corregir el correo del contacto en Odoo. Después, ligar el equipo a su cuenta. | Correo del contacto en Odoo vs. Dashboard prod › Clientes. |
| Aviso «Este equipo ya está dado de alta con otro cliente en el dashboard…» (`EQUIPO_DE_OTRO_TITULAR`) | El equipo ya tiene otro titular activo en producción, o su MAC está en un equipo de otro titular. No se le quita en silencio. | Confirmar etiqueta. Si es un error de alta, corregir el titular en el dashboard y volver a vincular. | Dashboard prod › Dispositivos › titular. |
| «No se pudo enviar el cierre: …» con texto de Odoo sobre número de serie | Odoo valida la entrega de material al completar; si la serie no quedó asignada en la entrega, rechaza el cierre. | Revisar la entrega de la orden de venta (línea «Energizador» con su serie) y que el paso de vinculación se haya hecho. | Orden de venta › Entrega. |

## La app apunta a producción desde la build 24

- Builds ≤ 23: servidor de pruebas. Lo que se vinculó con esas builds pudo quedar en el dashboard de **dev**, no en la cuenta real del cliente. Revisar en el dashboard de producción las instalaciones cerradas con builds viejas.
- Al actualizar a la 24 le pedirá entrar de nuevo con su contraseña: la sesión que tenía era del servidor de pruebas y no sirve en producción.
- Si el instalador ve datos «de prueba» o no ve un servicio publicado, lo primero es confirmar que tiene la 24.

## Comportamientos de la app que confunden

- **Terminar instalación** (botón final de la lista de pasos) no envía nada: el cierre real ya se mandó con «TERMINAR INSTALACIÓN» en la pantalla de firma. Si el instalador sale sin tocarlo, el servicio ya está cerrado.
- En la pantalla «Diagnóstico del equipo», el botón «Reportar incidencias (opcional)» abre la **cancelación**, no una incidencia.
- Desde la build 25, **Ayuda › «Reportar incidencias»** abre el formulario real (el mismo de Inicio) y crea el ticket en Helpdesk › «Incidencias de campo». En builds 24 o anteriores ese botón no enviaba nada aunque dijera «Reporte enviado correctamente»: pide que actualice.
- Desde la build 25, Ayuda muestra y marca el número real de soporte (55 5199 1396), también por WhatsApp. En builds anteriores se mostraban números de ejemplo y el enlace de WhatsApp no abría el chat correcto.
- Las fotos del cierre dicen «Verificado» al tomarlas; la app no verifica la posición de cada foto. La única validación de ubicación es la del cierre contra la llegada (300 m).
- «Contrato firmado: Pendiente» aparece siempre en la tarjeta.
- Los contadores de materiales arrancan en 5, 5, 5, 5, 1 y 3; si el instalador no los ajusta, se guardan así.
- Los mantenimientos usan los pasos de la instalación, incluida la vinculación.

## Cancelación en sitio: qué hace el sistema

1. Marca la intervención como cancelada (`op_cancelada`, motivo y hora) y deja nota «Cancelada en sitio por el técnico» con motivo, técnico y ubicación; la foto queda adjunta.
2. Si no había llegada, la regresa a borrador sin fecha. Si ya había iniciado, crea una **intervención nueva** «por planificar» sobre la misma línea de venta (hereda los datos de la llamada con el cliente) y la iniciada se conserva acortada a lo realmente ocupado.
3. Abre al responsable de operaciones la actividad «Cancelada en sitio: llamar al cliente». Al cliente no le llega aviso automático.

## Alta de un equipo nuevo en el dashboard (antes de la instalación)

Desde la build 24 la app trabaja con **producción**. Para que el instalador pueda vincular un energizador nuevo:

1. En el dashboard de producción › Dispositivos › «Crear dispositivo», escribe el **Número de serie OhmSafe** de la etiqueta (OS-OBV01-####) y la **MAC** del equipo.
2. **En «Asignar a usuario» elige al cliente** si ya tiene cuenta en la app. **No lo dejes en «(Sin asignar)»**: en ese caso el dashboard pone como titular a quien lo da de alta y, al vincular, la app avisará «ya está dado de alta con otro cliente» y el equipo no llegará a la cuenta del cliente.
3. Si el cliente todavía no tiene cuenta, avisa al equipo de producto antes de la instalación (hoy no hay forma automática de pasarle el equipo cuando cree su cuenta).
4. Anota la MAC también en la serie del inventario en Odoo (Inventario › Números de serie › OS-OBV01-#### › MAC Address); así la app lo encuentra aunque la serie del dashboard estuviera mal escrita.

