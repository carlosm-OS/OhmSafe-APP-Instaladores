# Vincular el energizador

Este es el paso 4 de la instalación. Sirve para tres cosas:

- revisar que el equipo que vas a instalar sea del inventario de OhmSafe y esté libre,
- comprobar con datos reales del equipo que funciona,
- dejarlo en la cuenta del cliente para que lo vea en su app OhmSafe.

## Paso a paso (desde la build 43)

1. En la lista de pasos toca **«Vincular el energizador»** (paso 4).
2. En **«Busca el energizador»**:
   - **Escanear (lo normal):** toca **«Escanear QR»** (o la tarjeta del código) y apunta al código de la etiqueta. Puedes prender la linterna. Al leerlo, la app busca el equipo sola.
   - **Escribir:** si no se puede escanear, escribe la serie en el campo de «O ESCRIBE LA SERIE» y toca la **flecha** del campo. Basta con el número final (`26`); los guiones se ponen solos. El ⓘ junto a la etiqueta dice dónde está la serie.
3. Aparece la ficha oscura del equipo («OHMBOX») con la serie, la conexión, si la cerca está encendida y el último reporte; abajo, la MAC y el firmware.
   - Si dice **«Esperando señal…»** con una barra naranja, no revises cables todavía: un equipo recién encendido tarda 1 o 2 minutos en aparecer en línea y la pantalla se actualiza sola. Si a los 3 minutos sigue sin señal, cambia a «Sin señal reciente» en rojo.
   - Si es un **equipo nuevo** dice «Se ve al vincularlo»: su conexión sólo se puede ver después de vincularlo.
   - Sin señal **puedes vincularlo igual**; para la prueba del paso 5 sí necesita corriente y señal. En la prueba también verás «Esperando señal…» los primeros minutos.
   - Si no es el equipo, toca **«Buscar otro equipo»**.
4. Toca **«Vincular energizador»** (o «Dar de alta y vincular» si es un equipo nuevo).
5. Se abre la hoja **«¿Estás instalando en esta dirección?»** con la casa («Casa de» + el cliente, con la etiqueta «Nueva» o «Ya tiene equipo») y su dirección; la venta va en una línea gris abajo. Si estás ahí, toca **«Sí, vincular aquí»**; si no, **«No es esta dirección»** y avisa a operaciones. El ⓘ explica por qué esa casa.
6. Verás «Energizador vinculado a «casa»» y la app abre sola la **Prueba del energizador** (paso 5).

Si algo sale mal (serie no encontrada, apartada, etc.) el aviso aparece **dentro de la pantalla**, arriba de la tarjeta. «Cancelar instalación» y «Reportar incidencias (opcional)» abren la cancelación en sitio.

## Antes de empezar

- El energizador debe estar instalado, encendido y conectado a la luz.
- Quédate cerca del equipo.
- Ten a la mano la etiqueta con el número de serie o el código QR.

## El número de serie

Las series del inventario tienen el formato **OS-OBV01-0001** (letras OS, modelo, y un consecutivo). Escríbelo tal como viene en la etiqueta; la app lo pasa a mayúsculas y pone los guiones.

## Equipo nuevo

Si al buscar la serie la app dice **«Equipo nuevo: se da de alta al vincularlo»**, es un equipo que todavía no existe en el sistema de monitoreo. No hay que darlo de alta en ningún lado:

1. Toca **«Dar de alta y vincular»** y confirma la dirección en la hoja **«¿Estás instalando en esta dirección?»**.
2. El equipo queda creado y ligado a la cuenta del cliente. En la ficha dice «Se ve al vincularlo»: su conexión aparece cuando el equipo, ya encendido, empieza a reportar.
3. La app abre sola la **Prueba del energizador** (paso 5).

Si la app dice **«Al equipo … le falta un dato en almacén (su MAC)»**, almacén debe capturar la MAC del equipo en su número de serie de Odoo antes de poder vincularlo. Avisa a operaciones y vuelve a escanear cuando te confirmen.

## Datos del equipo

En la ficha ves: número de serie, MAC, conexión («En línea», «Esperando señal…» o «Sin señal reciente»), si la cerca está encendida, firmware y último reporte.

**No hay pruebas que bloqueen la vinculación.** Las pruebas de batería auxiliar y conexión a la luz, y la casilla de tierra física, se retiraron mientras los equipos no reporten esos datos de forma confiable (build 31). La tierra física se sigue haciendo en la instalación; la revisa control de calidad en sitio.

## A dónde va el equipo (desde la build 40)

**Ya no eliges casa.** La decide la venta, con una regla de negocio: **una casa = una suscripción**.

- **Plan nuevo** (la venta es una suscripción nueva): el equipo va a una **casa nueva** con la dirección de la compra, aunque el cliente ya tenga otras casas. Cada dirección del cliente es una casa con su propio plan.
- **Equipo adicional** (un complemento sobre un contrato que ya existe): el equipo va a la **casa de ese contrato**.

Al tocar **«Vincular energizador»** verás la hoja **«¿Estás instalando en esta dirección?»** con la casa y la venta. Toca **«Sí, vincular aquí»** para seguir o **«No es esta dirección»** para quedarte en la pantalla y avisar a operaciones.

Si la hoja dice **«Todavía no se puede vincular»**, la venta es equipo adicional pero no dice a qué casa va. Avisa a operaciones para que la ligue a su contrato en Odoo y vuelve a intentarlo.

**¿Un segundo energizador en la misma casa?** No se vincula aquí como si fuera otra instalación: después de vincular el principal, ve a **Agregar dispositivos → Agregar otro energizador en esta casa → Agregar otro OhmBox → Agregar** (paso 6). Ahí queda como complemento de la misma suscripción.

## Si la cámara no abre

- «La app no tiene permiso para usar la cámara. Actívalo en Ajustes para escanear el QR, o escribe el número de serie.» Toca «Abrir Ajustes» y da permiso de cámara.
- «No se pudo abrir la cámara. Escribe el número de serie del equipo.»
- En ambos casos puedes tocar «Escribir el número de serie» y seguir a mano.

## Mensajes de serie y vinculación

En los mensajes, «OS-OBV01-0001» representa la serie que escribiste o escaneaste.

| Mensaje en pantalla | Qué significa | Qué hacer |
|---|---|---|
| «Escanea el QR o escribe el número de serie.» | Tocaste la flecha con el campo vacío. | Escribe la serie o toca «Escanear QR». |
| «El número de serie OS-OBV01-0001 no está en el inventario de Ohmbox. Revisa la etiqueta del equipo o avisa a operaciones.» | Esa serie no existe en el inventario de OhmSafe. | Revisa que la escribiste bien. Si está bien, avisa a operaciones y no instales ese equipo. |
| «El número de serie OS-OBV01-0001 ya está registrado como instalado con otro cliente. Revisa la etiqueta del equipo o avisa a operaciones.» | El sistema dice que ese equipo ya está instalado en otra casa. | Revisa la etiqueta. Si es correcta, avisa a operaciones antes de seguir. |
| «El número de serie OS-OBV01-0001 no aparece en el almacén. Avisa a operaciones para que lo revise antes de instalarlo.» | La serie existe pero el almacén no la tiene disponible. | Avisa a operaciones; no lo instales hasta que te confirmen. |
| «El número de serie OS-OBV01-0001 ya está apartado para otra instalación (número de orden). Usa otro equipo o avisa a operaciones.» | Ese equipo está reservado para otra orden. | Usa otro equipo o pide a operaciones que lo liberen. |
| «Al equipo OS-OBV01-0001 le falta un dato en almacén (su MAC). Pide a almacén que lo capture y vuelve a escanear.» | El equipo es nuevo pero su serie no tiene MAC en el inventario; sin MAC no se puede dar de alta. | Avisa a operaciones; cuando la capturen, vuelve a escanear. |
| «No encontramos el equipo OS-OBV01-0001. Revisa el número o escanea el QR.» | No se encontró el equipo. | Revisa la serie; si sigue, avisa a operaciones. |
| «No pudimos leer el equipo: …» | Falló la lectura por otra causa (texto después de los dos puntos). | Si dice «Sin conexión a internet», busca señal. Si no, vuelve a intentar o avisa a operaciones. |
| «No pudimos vincular el energizador: …» | El equipo se encontró pero no se pudo guardar la vinculación. | Revisa señal y vuelve a tocar «Vincular energizador». |
| «… Sesión expirada, vuelve a iniciar sesión» | Tu sesión ya no es válida. | Cierra y abre la app y entra de nuevo. |

### Aviso «Vinculado, pero falta la cuenta del cliente»

El equipo **sí** quedó vinculado a la instalación, pero no llegó a la app del cliente. Puedes seguir con el cierre.

| Mensaje | Qué significa | Qué hacer |
|---|---|---|
| «El cliente todavía no tiene cuenta en la app OhmSafe con el correo de su contrato, así que el equipo aún no aparece en su app. Puedes seguir con la instalación; avisa a operaciones para que lo liguen cuando cree su cuenta.» | El cliente no ha creado su cuenta en la app OhmSafe, o la creó con otro correo. | Sigue con el cierre. Pide al cliente que cree su cuenta con el mismo correo de su contrato y avisa a operaciones. |
| «Este equipo ya está dado de alta con otro cliente en el dashboard, por eso no se ligó a este cliente. Revisa la etiqueta del equipo y avisa a operaciones antes de continuar.» | El equipo pertenece a otro titular en el sistema. | Revisa la etiqueta y avisa a operaciones antes de cerrar. |
| «El equipo no se pudo ligar a la cuenta del cliente. Avisa a operaciones.» | Otra causa. | Avisa a operaciones. |

## También desde esta pantalla

- «Cancelar instalación» y «Reportar incidencias (opcional)» abren la cancelación en sitio. Ver [05](05-cancelar-en-sitio.md).

## Cómo era antes (builds anteriores)

Sólo como referencia si alguien tiene una build vieja; lo de arriba es lo vigente.

- **Hasta la build 42:** el paso se llamaba «Vinculación del energizador» › «Identifica el energizador», y el botón «Vincular» en realidad buscaba el equipo.
- **Hasta la build 39:** al vincular aparecía **«¿Dónde va este equipo?»** para elegir entre «Casa nueva» y las casas del cliente. Desde la build 40 la casa la decide la venta.
- **Builds 37 y 38:** al vincular, la app pasaba directo al cierre. Desde la build 39 pasa a la **Prueba del energizador**.
- **Hasta la build 30:** eran obligatorias las pruebas de batería auxiliar y conexión a la luz en verde y la casilla de tierra física; un equipo que no existía en el monitoreo había que darlo de alta antes en el dashboard. Hasta la build 28 también había «Prueba de alto voltaje».
