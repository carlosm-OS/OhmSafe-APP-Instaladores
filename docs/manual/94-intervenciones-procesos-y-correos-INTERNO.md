# Intervenciones en Planificación: procesos, tipos y correos al cliente (guía de operaciones)

> **USO INTERNO — no publicar.** Para operaciones y SAC de OhmSafe.

## En una frase

En Planificación cada intervención pertenece a un **proceso** (lo define el **rol**), es de un **tipo** (lo define el **producto** vendido) y avanza por un **flujo** (agendada, en ruta, en sitio, cerrada; reagendar es un paso de ese flujo). Los correos que recibe el cliente quedan guardados en el **historial (chatter) de la propia intervención**, con el PDF del reporte adjunto.

## La estructura: proceso, tipo y flujo

| Nivel | Qué es | Hoy |
|---|---|---|
| **Proceso** | El **rol** de Planificación. Dice *quién* hace el trabajo y qué reglas le aplican (avisos, app, permisos) | «Instalador OhmSafe Externo» (instaladores externos). Es el único proceso |
| **Tipo** | El **producto** de la venta | Instalación · Reparación · Mantenimiento · Reemplazo |
| **Flujo** | El estado de esa intervención | Por planificar → Agendada → En ruta → En sitio → Cerrada |

- **Reagendar no es un tipo.** Es la misma intervención que vuelve a agendarse: si el instalador cancela en sitio, nace un ticket «Reagendar» en Helpdesk (lo atiende quien agenda) que se cierra solo al volver a publicarla.
- **Un tipo nuevo** dentro de instaladores (por ejemplo, «revisión post-venta») es **un producto nuevo** ligado al rol de instalador. No hace falta otro rol.
- **Un proceso nuevo** (por ejemplo, un equipo comercial o de entregas en campo) es **un rol nuevo**, con su propia agenda, sus avisos y sus permisos. Nunca se usa el rol de instalador para citas que no son de instaladores.
- Todas las automatizaciones de instaladores (avisos, llamada obligatoria antes de publicar, metros a la app) aplican **sólo al rol de instalador**. La app del instalador también sólo ve ese rol.

Detalle técnico y checklist para agregar procesos: `docs/odoo-planeacion-procesos.md` en el repositorio del backend.

## Qué correos recibe el cliente y cuándo

| Correo | Asunto | Cuándo sale | Lo envía |
|---|---|---|---|
| Agendada | «Tu instalación OhmSafe está agendada · *fecha*» | Al **publicar** la intervención | Odoo |
| En ruta | «Tu técnico OhmSafe va en camino · *fecha*» | Cuando el instalador pulsa **«Iniciar ruta»** en la app | Sistema OhmSafe |
| Servicio cerrado | «Tu instalación OhmSafe quedó lista · Reporte de servicio» | Al **cerrar** la intervención. Lleva adjunto el PDF **«Reporte del servicio externo - *fecha*.pdf»** | Odoo |
| Encuesta | Invitación a «Satisfacción del servicio OhmSafe» | Al cerrar la intervención | Sistema OhmSafe |

Además salen avisos **internos** (no al cliente): «Te asignaron…» a operaciones y el aviso de turno nuevo al instalador.

## Dónde ver si se le envió al cliente

Los correos se guardan en el **historial (chatter) de la intervención**, a la derecha de su ficha completa.

### Camino 1 — desde Planificación

1. Odoo › **Planificación**.
2. Cambia a la vista **Lista** (icono de lista, arriba a la derecha) y busca la intervención por cliente o dirección.
3. Da clic en la fila: se abre la **ficha completa**. El historial está a la derecha.

La ventana rápida que aparece al dar clic en la agenda (vista de barras) y su botón «Editar» sirven para cambiar fechas y personas, pero no muestran el historial. Para revisar correos da clic en **«Intervención i…»**, arriba de esa ventana: te lleva a la ficha completa.

### Camino 2 — desde el contacto del cliente

1. Odoo › **Contactos** › el cliente.
2. Botón **«Servicios»** (arriba de la ficha): lista sus intervenciones.
3. Da clic en la intervención: ficha completa con el historial a la derecha.

### El número de la intervención

Cada intervención tiene un número con la forma **«i45»**, el mismo que usan la app del instalador y el equipo de sistemas. Se ve en:

- la **tarjeta** que aparece al dar clic en una barra de la agenda (primera línea, con el icono **#**). **Da clic en «Intervención i45»** y se abre la ficha completa con el historial: es el camino más rápido para revisar correos desde la agenda;
- la **ficha completa**, arriba: «Intervención i45»;
- la **vista Lista**, en la primera columna «Núm.».

Para encontrar una por número, escribe **i45** en la barra de búsqueda de Planificación y elige «Buscar Número de intervención». También puedes abrirla directo con `https://ohmsafe2.odoo.com/odoo/planning/45` (el número sin la «i»).

## Cómo leer el historial

- Cada correo aparece como un mensaje con **«Asunto: …»** y el texto que recibió el cliente. Los más recientes van arriba.
- Junto al mensaje hay un **icono de sobre**: si el envío falló se pone **rojo**. Da clic en él para ver el motivo (por ejemplo, correo inválido) y el botón para **reintentar**.
- El **PDF del reporte** aparece como tarjeta dentro del correo de «quedó lista». También está en el **clip** (adjuntos) de la barra de arriba del historial: ahí se descarga.
- En el mismo historial quedan las huellas del servicio: cambios de estado, posición del instalador al llegar y al cerrar, materiales capturados y notas.

## Si el correo no aparece

| Falta | Revisa |
|---|---|
| «Está agendada» | Que la intervención esté **publicada** (no sólo guardada) y que el contacto del cliente tenga **correo** |
| «Va en camino» | Que el instalador haya pulsado **«Iniciar ruta»** en la app. Si llegó sin pulsarlo, el cliente no recibe este aviso |
| «Quedó lista» con PDF | Que la intervención esté **cerrada** desde la app (estado «Completado») |
| Cualquiera, con sobre rojo | El motivo del error en el sobre; corrige el correo del cliente y reintenta |

Si el cliente dice que no le llegó pero el historial lo muestra enviado sin error, pídele que revise **spam** y **promociones**.
