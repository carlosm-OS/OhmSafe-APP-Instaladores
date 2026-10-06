# Vincular el energizador

Este es el paso 4 de la instalación. Sirve para tres cosas:

- revisar que el equipo que vas a instalar sea del inventario de OhmSafe y esté libre,
- comprobar con datos reales del equipo que funciona,
- dejarlo en la cuenta del cliente para que lo vea en su app OhmSafe.

## Antes de empezar

- El energizador debe estar instalado, encendido y conectado a la luz.
- Quédate cerca del equipo.
- Ten a la mano la etiqueta con el número de serie o el código QR.

## El número de serie

Las series del inventario tienen el formato **OS-OBV01-0001** (letras OS, modelo, y un consecutivo). Escríbelo tal como viene en la etiqueta; la app lo pasa a mayúsculas.

## Paso a paso

1. En la lista de pasos toca «Vinculación del energizador». Se abre «Vincular energizador» › «Identifica el energizador».
2. Identifica el equipo de una de dos formas:
   - **Escribir:** pon la serie en «Número de serie del equipo» y toca «Vincular».
   - **Escanear:** toca «Escanear QR», apunta al código QR del energizador («Apunta al código QR del energizador OhmSafe»). Puedes prender la linterna. Al leerlo, la serie se escribe sola.
3. La app revisa la serie contra el inventario y lee el equipo. Si algo está mal verás un aviso arriba (ver la tabla de mensajes).
4. Si todo está bien se abre «Diagnóstico del equipo» con las pruebas y los datos del equipo.
5. Revisa que las 3 pruebas estén en verde («Completa»).
6. Marca «Confirmo que instalé la tierra física conforme al procedimiento».
7. Con todo en verde y la tierra confirmada, el título cambia a «Equipo listo para vincular». Toca «Continuar con cierre de instalación».
8. Si el equipo no quedó en la cuenta del cliente aparece «Equipo vinculado, falta la cuenta del cliente» (ver abajo). Toca «Entendido».
9. Regresas a la lista de pasos con el paso 4 completo.

Para volver a escribir otra serie, toca la flecha de regresar en «Diagnóstico del equipo».

## El diagnóstico

### Las pruebas

| Prueba | Verde («Completa») | Rojo («Error») | Gris («Pendiente») |
|---|---|---|---|
| «Conexión de batería auxiliar» | La batería reporta bien. | Batería baja. Revisa la batería. | El equipo no ha reportado su batería. |
| «Verificación de conexión a línea» | El equipo recibe energía de la calle. | «El equipo no recibe energía de la línea eléctrica». Revisa la conexión a la luz. | — |

- El botón «Continuar con cierre de instalación» solo se activa con las 2 pruebas en verde y la tierra física confirmada.
- Desde la build 29 ya no hay «Prueba de alto voltaje»: los equipos actuales no reportan ese sensor. El «Estado de la cerca» sigue apareciendo como dato informativo en el detalle del equipo.
- Si la conexión a línea sale en rojo aparece «Reintentar validación»: corrige y tócalo para leer el equipo otra vez.

### La tierra física

La tierra física no la mide el equipo: la confirmas tú al marcar la casilla. Es obligatoria, queda registrada a tu nombre y control de calidad la verifica en sitio.

### Datos del equipo

En la tarjeta ves: «Número de serie», «MAC», «Estado de la cerca» («Activa» o «Desarmada»), «Equipo en línea» («Sí» o «Sin reporte reciente»), «Firmware» y «Último reporte» (fecha y hora, o «Nunca»).

## Si la cámara no abre

- «La app no tiene permiso para usar la cámara. Actívalo en Ajustes para escanear el QR, o escribe el número de serie.» Toca «Abrir Ajustes» y da permiso de cámara.
- «No se pudo abrir la cámara. Escribe el número de serie del equipo.»
- En ambos casos puedes tocar «Escribir el número de serie» y seguir a mano.

## Mensajes de serie y vinculación

En los mensajes, «OS-OBV01-0001» representa la serie que escribiste o escaneaste.

| Mensaje en pantalla | Qué significa | Qué hacer |
|---|---|---|
| «Ingresa o escanea el número de serie del equipo» | Tocaste «Vincular» con el campo vacío. | Escribe la serie o toca «Escanear QR». |
| «El número de serie OS-OBV01-0001 no está en el inventario de Ohmbox. Revisa la etiqueta del equipo o avisa a operaciones.» | Esa serie no existe en el inventario de OhmSafe. | Revisa que la escribiste bien (letras, guiones, ceros). Si está bien, avisa a operaciones y no instales ese equipo. |
| «El número de serie OS-OBV01-0001 ya está registrado como instalado con otro cliente. Revisa la etiqueta del equipo o avisa a operaciones.» | El sistema dice que ese equipo ya está instalado en otra casa. | Revisa la etiqueta. Si es correcta, avisa a operaciones antes de seguir. |
| «El número de serie OS-OBV01-0001 no aparece en el almacén. Avisa a operaciones para que lo revise antes de instalarlo.» | La serie existe pero el almacén no la tiene disponible. | Avisa a operaciones; no lo instales hasta que te confirmen. |
| «El número de serie OS-OBV01-0001 ya está apartado para otra instalación (número de orden). Usa otro equipo o avisa a operaciones.» | Ese equipo está reservado para otra orden; entre paréntesis aparece el número de esa orden. | Usa otro equipo o pide a operaciones que lo liberen. |
| «El equipo OS-OBV01-0001 no está dado de alta en el dashboard. Avisa a operaciones.» | La serie es válida, pero el equipo no está registrado en el sistema de monitoreo; no hay datos que leer. | Avisa a operaciones para que lo den de alta y vuelve a tocar «Vincular». |
| «No se encontró un equipo con la serie "OS-OBV01-0001"» | No se encontró el equipo. | Revisa la serie; si sigue, avisa a operaciones. |
| «Diagnóstico del equipo exitoso» | Las 3 pruebas están en verde. | Confirma la tierra física y continúa. |
| «Hay pruebas en rojo, revisa el equipo» | Al menos una prueba no está en verde. | Corrige lo que marca la prueba y vuelve a leer el equipo. |
| «No se pudo leer el equipo: …» | Falló la lectura por otra causa (texto después de los dos puntos). | Si dice «Sin conexión a internet», busca señal. Si no, vuelve a intentar o avisa a operaciones. |
| «No se pudo vincular el energizador: …» | El diagnóstico pasó pero no se pudo guardar la vinculación. | Revisa señal y vuelve a tocar «Continuar con cierre de instalación». |
| «… Sesión expirada, vuelve a iniciar sesión» | Tu sesión ya no es válida. | Cierra y abre la app y entra de nuevo. |

### Aviso «Equipo vinculado, falta la cuenta del cliente»

El equipo **sí** quedó vinculado a la instalación, pero no llegó a la app del cliente. Puedes seguir con el cierre.

| Mensaje | Qué significa | Qué hacer |
|---|---|---|
| «El cliente todavía no tiene cuenta en la app OhmSafe con el correo de su contrato, así que el equipo aún no aparece en su app. Puedes seguir con la instalación; avisa a operaciones para que lo liguen cuando cree su cuenta.» | El cliente no ha creado su cuenta en la app OhmSafe, o la creó con otro correo. | Sigue con el cierre. Pide al cliente que cree su cuenta con el mismo correo de su contrato y avisa a operaciones. |
| «Este equipo ya está dado de alta con otro cliente en el dashboard, por eso no se ligó a este cliente. Revisa la etiqueta del equipo y avisa a operaciones antes de continuar.» | El equipo pertenece a otro titular en el sistema. | Revisa la etiqueta y avisa a operaciones antes de cerrar. |
| «El equipo no se pudo ligar a la cuenta del cliente. Avisa a operaciones.» | Otra causa. | Avisa a operaciones. |

## También desde esta pantalla

- «Cancelar instalación» (en «Identifica el energizador») abre la cancelación en sitio. Ver [05](05-cancelar-en-sitio.md).

## ¿Dónde va este equipo? (desde la build 28)

Al tocar **«Vincular»**, si el cliente **ya tiene casas** en su app OhmSafe aparece una hoja con sus casas (nombre, dirección y cuántos energizadores tiene cada una) y la opción **«Casa nueva»**.

- **Casa nueva** es la primera opción: sólo escribes el nombre; la dirección es la del ticket de instalación y no se puede cambiar ahí (desde la build 32).
- Debajo están las casas que el cliente ya tiene. Viene preseleccionada la que coincide con la dirección de la orden; si ninguna coincide, Casa nueva.
- **«Cancelar»** te regresa a la pantalla sin vincular.
- Si el cliente no tiene casas todavía, no se pregunta: la casa se crea sola con la dirección de la orden.

No afecta el cobro: un energizador adicional en una casa existente queda en la misma suscripción de esa casa.

## Equipo nuevo (desde la build 30)

Si al capturar la serie la app dice **«Equipo nuevo»**, es un equipo que todavía no existe en el sistema. No hay que darlo de alta en ningún lado:

1. Confirma la tierra física y toca **«Vincular y dar de alta el equipo»** (si el cliente ya tiene casas, elige a cuál va).
2. El equipo queda creado y ligado a la cuenta del cliente. Enciéndelo y conéctalo.
3. Cuando reporte, las pruebas de línea y batería se ponen en verde (usa **«Reintentar validación»** si aún no reporta) y entonces **«Continuar con cierre de instalación»**.

Si la app dice que la serie **no tiene MAC registrada**, almacén debe capturar la MAC del equipo en su número de serie de Odoo (Inventario › Lotes/Números de serie, columna «MAC Address») antes de poder vincularlo.

## Desde la build 31: sin validaciones por ahora

Las pruebas de **batería auxiliar**, **conexión a línea** y la casilla de **tierra física** se retiraron temporalmente (los equipos actuales no reportan esos datos de forma confiable). Hoy la pantalla hace esto:

1. Captura o escanea el número de serie → aparece la **ficha del equipo** (serie, MAC, estado, último reporte). Si es un equipo nuevo, lo dice.
2. Toca **«Vincular energizador»** (o «Vincular y dar de alta el equipo» si es nuevo); si el cliente tiene casas, elige a cuál va.
3. Verás **«Vinculación exitosa»** con la ficha; toca **«Continuar con cierre de instalación»**.

Las secciones anteriores sobre pruebas en verde/rojo aplican a builds anteriores y se reactivarán cuando vuelvan las validaciones.
