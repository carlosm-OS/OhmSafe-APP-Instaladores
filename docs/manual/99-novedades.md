# Novedades por versión

De la más reciente a la más antigua. Todas son versión 1.0.0; cambia el número de build.

## Build 58 (en preparación)

- **La Wi‑Fi no se vuelve a pedir.** Al conectar una cámara o un sensor Wi‑Fi ya no aparecen los campos de red y contraseña: sale «Conectado a la Wi‑Fi de la casa» con la red del paso 4 y el botón «Cambiar». Si todavía no la capturaste, la pantalla te manda al paso con «Ir a Wi‑Fi de la casa».
- **Modo punto de acceso, paso a paso.** Si eliges «Punto de acceso», la app pide el permiso de la casa y luego te pide conectar el teléfono a la red del equipo: «Abrir ajustes de Wi‑Fi», eliges la red nueva y abierta del equipo y regresas; la app sigue sola. Si el teléfono ve esa red desde el principio, elige «Punto de acceso» por ti.
- **Más tiempo para que el equipo llegue.** La app espera lo que dura el permiso (unos 5 minutos), no sólo 1 minuto.
- **Mensaje claro si la nube de los equipos rechaza el permiso**, con su código para soporte.

## Build 57 (TestFlight y APK, servidor de pruebas) — 22 de octubre de 2026

- **Número de intervención en el historial.** Cada tarjeta del historial muestra su número (por ejemplo «i67»), igual que en la lista de instalaciones; también puedes buscarlo.
- **El reporte dice lo que de verdad instalaste.** En el cierre ya no se contestan «Cámaras», «Sensores» y «Sirena»: el reporte del cliente lista lo que diste de alta en «Agregar dispositivos» (energizador, sensores cableados, salidas, sensores 433, controles, sensores Wi‑Fi, cámaras y la prueba de sirena).
- **Salidas auxiliares de 12 V.** Al registrar una salida, las opciones ahora son «Estrobo», «Sirena extra» u «Otro equipo de 12 V» (ya no luz, bomba ni portón).
- **Control remoto desde la app.** En «Agregar dispositivos › Sensores inalámbricos» vuelve la opción «Control remoto»: la app pide cada botón y lo deja con botón 1 = encender y apagar la cerca, botón 2 = pánico.
- **Nuevo paso 4: «Wi‑Fi de la casa».** Antes de «Agregar dispositivos» capturas la Wi‑Fi una vez (el cliente escribe la contraseña, que se queda sólo en tu teléfono y se borra al terminar) o la omites si la casa no la necesita. Los sensores y cámaras Wi‑Fi la usan sin volver a pedirla y el OhmBox puede conectarse a ella como segunda conexión además de la red celular. Puedes volver al paso hasta el cierre. «Agregar dispositivos» pasa a ser el paso 5 y el cierre el 6.
- **Serie de los equipos Wi‑Fi.** Al conectar un sensor o una cámara Wi‑Fi puedes escanear o escribir su número de serie (opcional). Queda en la ficha del equipo, en el dashboard y en el reporte de servicio: sirve para inventario y garantía.
- **«Equipo conectado».** Al terminar de conectar un sensor o cámara Wi‑Fi ya no sólo sale un aviso: aparece una tarjeta con qué es, el modelo, la serie, el ID del equipo y la red, para confirmar que es el que tienes en la mano. Si no es, «No es este equipo» te dice qué avisar a operaciones.
- **Emparejar por Bluetooth.** Al conectar un sensor o una cámara Wi‑Fi, el modo normal ahora es «Bluetooth»: el teléfono busca el equipo cerca y le pasa la red. Si no lo ve en 20 segundos, sigue solo en modo rápido. La primera vez el teléfono pide permiso de Bluetooth.
- **Sin nombres de marca.** La ayuda para conectar sensores y cámaras Wi‑Fi ya no menciona marcas: en el modo «Punto de acceso» dice que te conectes a la red nueva que crea el equipo.
- **Sirena de demostración.** En «Agregar dispositivos › Sirena» hay «Encender» y «Apagar»: puedes hacerla sonar las veces que quieras frente al cliente (se apaga sola a los 15 segundos). La primera vez la app pregunta si sonó, como antes.

## Build 56 (TestFlight, servidor de pruebas) — 20 de octubre de 2026

- **Sólo ves instalaciones con fecha.** Desaparece la sección «Pendientes de agendar»: una intervención asignada pero sin día y hora ya no aparece (antes salía todos los días). Cuando operaciones le ponga fecha, aparece en su día y te llega el aviso.
- **Movimiento como en OhmSafe GO.** Las pantallas entran fundiendo y deslizándose un poco desde la derecha; las filas y tarjetas aparecen escalonadas; los botones se encogen al presionarlos; los cambios de estado (marcar, probar) se funden en vez de saltar. Con «Reducir movimiento» del teléfono todo es instantáneo.
- **RFC de sólo lectura en «Datos generales».** Desaparece la pantalla «Facturación» de Mi cuenta: el RFC se ve junto a nombre, teléfono, correo y CURP, y sólo el equipo de OhmSafe lo corrige en Odoo (como el resto de los datos).

## Build 55 (servidor de pruebas) — 20 de octubre de 2026

- **Agregar dispositivos avisa si no pudo leer la casa.** En la 54, cuando el servidor no podía resolver la casa, la pantalla se quedaba sólo con «Vincular energizador» y sin sensores Wi‑Fi ni cámaras, sin explicar nada. Ahora muestra el motivo. (El servidor de pruebas también se corrigió: ya no crea casas repetidas.)
- **Cierre › Fotos:** las dos fotos de la cerca se llaman «Foto cerca 1» y «Foto cerca 2» (antes «Perfil izquierdo» y «Perfil derecho»).
- **Sin marcas en pantalla.** Los sensores y cámaras Wi‑Fi se llaman así, sin el nombre del fabricante, en filas, avisos y listas.

## Build 54 (servidor de pruebas) — 20 de octubre de 2026

- **El energizador ya no es obligatorio.** Los pasos «Vincular el energizador» y «Prueba del energizador» desaparecen de la lista: ahora la instalación tiene 5 pasos (ruta y llegada, inspección, instalación, **Agregar dispositivos**, cierre). En «Agregar dispositivos», la primera sección es **Energizador (OhmBox)**: si la casa lleva energizador, toca «Vincular» (y la prueba de la cerca se abre sola); si no, sigue con sensores Wi‑Fi y cámaras. Sensores cableados, sirena, salidas y sensores inalámbricos sólo aparecen cuando hay energizador. «Probar» y «Agregar otro OhmBox» están en esa misma sección.
- Requiere el servidor con el cambio «energizador opcional» (ya en el servidor de pruebas).

## Build 53 (servidor de pruebas) — 20 de octubre de 2026

- **Buscador de redes Wi‑Fi** al conectar un sensor o cámara Wi‑Fi: en Android, el icono junto a «Nombre de la red» abre la lista de redes cercanas (las de 2.4 GHz primero, con su señal; las de 5 GHz se ven apagadas porque el equipo no las ve) y tocas una. En iPhone Apple no permite listar redes: el campo sigue leyendo la red del teléfono, se actualiza solo al volver de Ajustes › Wi‑Fi y el icono la relee a mano.
- **Aviso de 5 GHz:** si el nombre elegido o escrito parece de 5 GHz («…5G»), la app lo dice debajo del campo (no impide continuar).

## Build 52 — 20 de octubre de 2026

- **Una sola plataforma de cámaras y sensores Wi‑Fi.** Por decisión de dirección, la app deja de ofrecer las otras dos plataformas de cámaras: en «Agregar dispositivos» → Cámaras ya no aparecen «Conectar cámara a la Wi‑Fi» (otra plataforma), «Conectar cámara (otra plataforma)» ni «Cámara ya conectada». Queda **«Conectar cámara Wi‑Fi»** y, en Sensores Wi‑Fi, **«Conectar sensor Wi‑Fi»**. Las cámaras de otras marcas que ya estaban registradas se siguen viendo en la lista.
- **App más ligera:** un programa de cámaras que ya no se usa dejó de viajar dentro de la app (unos 40 MB menos de descarga).

## Build 51 (TestFlight, servidor de pruebas) — 20 de octubre de 2026

Sólo para pruebas internas: apunta al **servidor de pruebas** (api-dev).

- **«Conectar cámara Imou»** en «Agregar dispositivos» → Cámaras: pantalla completa con **escaneo del QR de la guía rápida** (llena la serie y el código SC solos), pasos para dejarla en internet y registro en la casa. «Cámara ya conectada» usa la misma pantalla para cámaras conectadas con la app del fabricante.
- **Adiós a los diálogos con campos:** registrar una cámara ya no es un cuadro que el teclado tapaba; es una pantalla que se desplaza y deja el botón a la vista.
- **Serie del energizador:** si tecleas un cero en vez de la letra O («0SPRUEBA0001»), la app lo corrige sola a «OS‑PRUEBA‑0001».
- **Lista de dispositivos en orden:** en «Agregar dispositivos», los sensores Wi‑Fi y las cámaras salen numerados **en el orden en que los diste de alta**, con su marca (Tuya, EZVIZ, Imou), sin importar el tipo.
- **Textos más claros al conectar a la Wi‑Fi:** cómo poner el equipo en modo de emparejamiento, cuál es la red de 2.4 GHz (la que no dice «5G») y que la contraseña la escribe el cliente en tu teléfono.

## Build 50 (TestFlight y Play, producción) — 19 de octubre de 2026

Mismo contenido que la 49, pero apunta al **servidor de producción**. Todo lo que des de alta queda en casas y cuentas reales; úsala sólo en casas de prueba (OS‑PRUEBA) hasta que se publique en tiendas.

## Build 49 (TestFlight, servidor de pruebas) — 17 de octubre de 2026

Sólo para pruebas internas: apunta al **servidor de pruebas** (api-dev), no a producción. Los instaladores siguen con la 47 de la tienda o la 48 de TestFlight.


- **Sensores y cámaras Tuya desde la app.** En «Agregar dispositivos» aparecen **«Conectar sensor Wi‑Fi»** y **«Conectar cámara Tuya»** (cuando el servidor tiene Tuya encendido): el teléfono le pasa la red de la casa al equipo con el permiso de la casa, y el equipo queda en la cuenta del cliente (lo ve en OhmSafe GO). La contraseña no se guarda; el nombre de la red sí. Si la casa aún no tiene cuenta Tuya, la app lo dice: el cliente debe entrar una vez a OhmSafe GO.
- **Conectar cámaras EZVIZ a la Wi‑Fi desde la app.** En «Agregar dispositivos» → Cámaras hay una fila nueva, **«Conectar cámara a la Wi‑Fi»**: escaneas la etiqueta, el cliente escribe su contraseña en tu teléfono y la app le pasa la red a la cámara y la registra en la casa. La contraseña no se guarda; el nombre de la red sí (para soporte). La opción de antes se llama ahora **«Cámara ya conectada»** (para cámaras que ya están en internet). Sólo aparece cuando el servidor tiene EZVIZ encendido.
- **Cierre, paso Entrega:** el botón «Siguiente» ocupa ahora el doble que «Atrás» y ya no se corta en teléfonos chicos.
- **Avisos de error en rojo:** un rojo un poco más oscuro para que el texto blanco se lea bien al sol.

## Build 48 (TestFlight, producción) — 17 de octubre de 2026

- **Notificaciones:** al cerrar sesión, el teléfono deja de recibir los avisos de esa cuenta. Antes, si cambiabas de cuenta en el mismo teléfono (por ejemplo, de Juan a Chuck), te llegaban los avisos de las dos.

## Build 47 (producción: Google Play y App Store) — 17 de octubre de 2026

Primera build de tienda con todo lo de las builds 38 a 46 (prueba en sitio, agregar dispositivos, ajustes del lienzo de diseño y «Esperando señal del equipo…»). Apunta a producción.

## Build 46 — 15 de octubre de 2026

- **«Esperando señal del equipo…»** con barra de progreso en Vincular y en la Prueba: un equipo recién encendido tarda 1 o 2 minutos en aparecer en línea. La pantalla vuelve a revisar sola cada 5 segundos; el aviso rojo de «sin señal» sólo sale si a los 3 minutos sigue sin reportar.
- **Equipo nuevo:** la conexión dice «Se ve al vincularlo» en vez de «Sin señal reciente» en rojo (antes de vincularlo no hay forma de saberla).

## Build 45 — 15 de octubre de 2026 (ajustes del lienzo de diseño)

- **Confirmar la casa al vincular:** la hoja pregunta **«¿Estás instalando en esta dirección?»**. Muestra «Casa de» + el nombre del cliente con la etiqueta «Nueva» (o «Ya tiene equipo») y la dirección; la venta va en una línea gris. Botones: **«Sí, vincular aquí»** y **«No es esta dirección»**.
- **Ficha del energizador oscura** (vincular y prueba): «OHMBOX» arriba; «En línea» y «Encendida» en naranja. En la prueba, la serie va resaltada en blanco.
- **Agregar dispositivos:** las secciones se llaman **Sensores cableados**, **Salidas auxiliares** y **Agregar otro energizador en esta casa**. El recuadro de los energizadores de la casa es oscuro, y el tipo de sensor se elige en filas con borde.
- **Ventanas emergentes:** el botón secundario («Cancelar», «No») tiene borde gris y texto oscuro; el naranja queda sólo en la acción principal. Los títulos van en 16.
- **Avisos de error** en rojo relleno con texto blanco (sin señal, no pudimos conectar, foto fuera del domicilio).
- **Pasos de la orden:** los pasos hechos van en blanco con borde verde. «Cómo llegar» es un enlace naranja sin contorno.
- **Cierre:** el recuadro de firma tiene borde oscuro.

## Build 44 — 15 de octubre de 2026

- **Arreglo:** «Agregar dispositivos» ya no muestra la pantalla de error al guardar el nombre de una puerta (u otro dato) con el teclado abierto.
- **Ventanas emergentes con botones claros:** arriba el botón principal naranja («Guardar», «Sí») y abajo el secundario con contorno naranja («Cancelar», «No»).
- **Con el teclado abierto**, las ventanas emergentes se desplazan en vez de cortarse (p. ej. «¿Qué conectaste a la salida?»).
- **Sensores Wi‑Fi:** por ahora no se pueden agregar.
- **Otro energizador en esta casa:** los energizadores que ya tiene la casa se ven en un recuadro gris de sólo información (serie, «Principal», «En línea»); debajo, «Agregar otro OhmBox».
- El aviso «Sigue cargando…» sale abajo, sobre la barra, en vez de tapar el título.

## Build 43 — 15 de octubre de 2026

- **Barra de progreso** arriba de la pantalla cuando la app espera al servidor o al GPS; si tarda más de 6 segundos dice «Sigue cargando… la señal está lenta». Ya no parece trabada.
- **Mismo diseño que los pasos 1 a 3** en vincular, prueba y agregar dispositivos (encabezado, tarjetas blancas, filas con su botón a la derecha). Íconos ⓘ discretos junto a las etiquetas explican lo que puede confundir (cómo se prueba una puerta, qué debe verse en cada foto, por qué esa casa…).
- **Vincular**: «Escanear QR» es la acción principal; la serie escrita se busca con la flecha del campo. Los avisos salen dentro de la pantalla.
- **Prueba del energizador**: un solo botón que enciende o apaga, y la lista «Muéstrale al cliente» que se marca sola.
- **Agregar dispositivos**: secciones con nombres claros (Puertas con cable, Luces y portón, Sensores inalámbricos…), la prueba de puertas va «1 de 2 / 2 de 2» y el OhmBox adicional pasa al final.
- **Cierre**: textos más simples, indicación «Firma aquí con el dedo» y, si el botón final está apagado, «Para terminar falta: …».

## Build 42 — 14 de octubre de 2026

- «Agregar dispositivos» ya no muestra marcas. Las cámaras se agregan sólo con número de serie, código de verificación y nombre; los sensores Wi‑Fi con su id.

## Build 41 — 14 de octubre de 2026

- Corrige la build 40: «Prueba del energizador» y «Agregar dispositivos» salían en gris (la barra inferior y los botones estaban mal armados).
- Al retomar una instalación ya vinculada, la app vuelve a la **prueba del energizador** (o a Agregar dispositivos si la prueba ya se hizo), no al cierre. En la lista, el botón dice «Continuar · Probar energizador» / «Continuar · Dispositivos y cierre».
- Los pasos se activan en orden: prueba → agregar dispositivos (opcional, se puede volver a abrir) → cierre.
- El aviso «Técnico en camino» ya no aparece al retomar, y la fecha de creación sale en hora local.

## Build 40 — 14 de octubre de 2026

- **Ya no eliges la casa al vincular.** Se retira «¿Dónde va este equipo?». La venta decide: plan nuevo va a una casa nueva con la dirección de la compra y equipo adicional va a la casa de su contrato. Ves una hoja de confirmación antes de vincular.
- **Sensores 433, sensores Wi‑Fi y cámaras** en «Agregar dispositivos», además de las entradas cableadas, sirena y salidas.
- **OhmBox adicional** en «Agregar dispositivos»: el segundo energizador de una casa se agrega ahí y queda como complemento de la misma suscripción.
- En la lista de instalaciones y reparaciones, cada tarjeta muestra su número de intervención («i69») junto al cliente.
- **Prueba del energizador sin reloj**: el control del equipo dura lo que estés en la pantalla y se retira al salir. Al terminar regresas a la lista de pasos.
- **Agregar dispositivos** se abre sólo al tocarlo, regresa a la lista al terminar y sigue disponible hasta el cierre.

## Build 39 — 13 de octubre de 2026

- **Nuevo paso 5, «Prueba del energizador»** (opcional): al vincular, la app abre una ventana de 30 minutos (ampliable de 15 en 15 hasta 2 horas) para **encender y apagar la cerca** y mostrarle al cliente que el equipo trabaja (alto voltaje en la línea). Al tocar «Terminar prueba y cerrar» u «Omitir», el control del equipo se retira y sigue el cierre, que ahora es el paso 6. Mientras dura la prueba, lo que dispare el equipo (por ejemplo, tocar las líneas) no manda avisos ni llamadas a nadie.
- **Nuevo paso 6, «Agregar dispositivos»** (opcional): puertas, sirena y salidas cableadas al OhmBox, probadas en vivo. Entradas: toca «Probar», cierra la puerta (el equipo debe verla cerrada 3 segundos), ábrela y, cuando diga «Verificada», ponle nombre y dala de alta; un lazo sin sensor nunca pasa. Sirena: «Probar 3 s» y contesta si sonó. Salidas: «Encender 5 s», contesta si se encendió y di qué es (luz, bomba, portón, sirena externa, otro) y cómo funciona (encendido/apagado o pulso). Todo queda en el acta de la instalación. Sólo con equipos de firmware 2.10 o superior.
- El cierre pasa a ser el paso 7.

## Build 37 — 9 de octubre de 2026

- **Vincular energizador → cierre, sin toques extra**: al tocar «Vincular energizador» (o «Vincular y dar de alta el equipo») y quedar vinculado, la app ya no se queda en la ficha esperando «Continuar»: muestra «Vinculación exitosa · casa «…»» y abre sola el **Cierre de instalación**. Si regresas a la ficha, el botón sigue diciendo «Continuar con cierre de instalación».

## Build 36 — 9 de octubre de 2026

- **Número de serie sin buscar el guion**: al escribir la serie los guiones se ponen solos (escribe `OSOBV010026` y queda `OS-OBV01-0026`). También basta con escribir sólo el número: `26` se completa como `OS-OBV01-0026`.
- **«¿Dónde va este equipo?»**: sólo aparecen las casas del cliente que ya tienen algún equipo (energizador, cámaras, sensores…); las casas vacías no se ofrecen. En **Casa nueva** ves la **dirección de la compra** (con su número de venta) y **dónde estás tú ahora**; si estás lejos de la dirección de la compra, la app te avisa para que lo confirmes con el cliente.
- **Metros a instalar** ahora muestra el metraje real que mediste en la inspección (antes, si volvías a entrar a la orden, mostraba el metraje agendado).
- **«¿Dónde va este equipo?» te dice qué se vendió**: arriba de las opciones ves la venta (por ejemplo «Venta S00255 · Servicio nuevo: Plan Hogar Seguro - Mensual · 1 Ohmbox» o «Equipo adicional · 1 Ohmbox»). Si eliges una casa que no cuadra con lo vendido (un servicio nuevo en una casa que ya existe, o equipo adicional en casa nueva) la app te avisa, pero tú decides.
- **La suscripción sigue a la casa que eliges**: cuando la venta es un servicio nuevo, al vincular la suscripción de esa venta queda ligada a la casa elegida; el mensaje de «Vinculación exitosa» te dice qué pasó (ligada, ya estaba ligada, o quedó pendiente para operaciones).
- **Cierre, paso 2**: nueva casilla **«Instalé y dejé funcionando sirena»** junto a cámaras y sensores («Instalé y funciona» o «No aplica»). Por ahora es tu confirmación; más adelante el equipo lo validará solo.

## Build 35 — 7 de octubre de 2026

- Se retiran del Inicio, por ahora, **Mantenimientos** y **Cotizar venta** (serán de una fase 2). Quedan Instalaciones y Reportar incidencias.

## Build 34 — 7 de octubre de 2026

- **«Reportar incidencias» del Inicio pregunta primero qué necesitas**: *Reportar una incidencia* (equipo dañado, riesgo, falta de material… operaciones lo recibe como ticket; no cambia tu agenda) o *Cancelar una instalación en sitio* (mal clima, el cliente no puede, emergencia: la instalación sale de tu agenda y operaciones la vuelve a agendar). Si tienes varias instalaciones pendientes, eliges cuál se cancela.
- Al reportar una incidencia, la instalación en curso viene preseleccionada como orden relacionada.
## Build 33 — 7 de octubre de 2026

- **«¿Se cancela la instalación de hoy?»**: si tienes una instalación en curso y abres «Reportar incidencia», la app te pregunta primero si lo que quieres es **cancelarla en sitio** (mal clima, emergencia, el cliente no puede). Reportar una incidencia no reagenda; cancelar en sitio sí: operaciones recibe un ticket con tu motivo y vuelve a agendar.
- Las incidencias que reportas con una orden relacionada quedan ligadas a esa intervención en Odoo.

## Build 32 — 6 de octubre de 2026

- **«¿Dónde va este equipo?»** reorganizada: **Casa nueva** es la primera opción (sólo escribes el nombre; la dirección es la del ticket de instalación y no se edita) y debajo, en una lista más clara, las casas que el cliente ya tiene. Viene preseleccionada la casa que coincide con la dirección; si ninguna coincide, Casa nueva.

## Build 31 — 6 de octubre de 2026

- **Vincular energizador, simplificado por ahora**: se retiran las validaciones de batería auxiliar, conexión a línea y la casilla de tierra física (los equipos aún no las reportan de forma confiable; volverán cuando estén listas). El flujo es: capturar o escanear la serie → ficha del equipo → **«Vincular»** → mensaje «Vinculación exitosa» con la ficha → **«Continuar con cierre de instalación»**.

## Build 30 — 6 de octubre de 2026

- **Equipo nuevo al escanear**: ya nadie tiene que darlo de alta antes. Si el equipo no existe pero su número de serie tiene registrada la MAC en el almacén, la app te deja **«Vincular y dar de alta el equipo»** (se liga al cliente del ticket y a la casa que elijas) y después verifica línea y batería con «Reintentar» hasta que reporte.
- Si la serie no tiene MAC registrada, la app te lo dice para que almacén la capture.

## Build 29 — 6 de octubre de 2026

- **Vincular energizador**: se quita por ahora la «Prueba de alto voltaje» (los equipos todavía no reportan ese sensor). Bastan línea eléctrica y batería en verde más la tierra física confirmada.

## Build 28 — 6 de octubre de 2026

- **Vincular energizador**: si el cliente ya tiene casas en su app, antes de vincular te preguntamos **«¿Dónde va este equipo?»**: a una de sus casas (viene preseleccionada la que coincide con la dirección de la orden) o a una casa nueva. Así un segundo energizador de la misma propiedad ya no aparece como otra casa.

## Build 27 — 6 de octubre de 2026

- **Ícono de la app**: el número rojo sobre el ícono ahora es tu cantidad de **avisos sin leer** (la misma que la campana). Se borra cuando abres la campana. Antes se quedaba en «1» para siempre.

## Build 26 — 6 de octubre de 2026

- **Cierre**: las observaciones del reporte ya no muestran «Paso 1: | Paso 2:» vacíos; sólo aparece lo que escribas.
- **Avisos** (del lado del servidor, sin actualizar la app): si operaciones te quita una instalación ya programada, recibes «Servicio reasignado»; al publicar ya no llegan dos avisos iguales.

## Build 25 — 4 de octubre de 2026

- **Ayuda**: «Reportar incidencias» ahora sí envía el reporte a operaciones (es el mismo formulario que en Inicio) y te muestra su número de incidencia.
- **Ayuda**: teléfono y WhatsApp de soporte corregidos (55 5199 1396).

## Build 24 — 4 de octubre de 2026

- La app trabaja con el sistema real de OhmSafe (producción) en iPhone (TestFlight) y Android (Google Play). Las instalaciones son reales y el energizador queda en la cuenta real del cliente.
- **Actualiza a esta versión.** Las versiones anteriores trabajaban con el sistema de pruebas.

## Build 23 — 2 de octubre de 2026

- Vincular energizador acepta la serie del inventario de OhmSafe con formato **OS-OBV01-0001**, escrita o leída del QR (también dentro de un enlace).
- Si el equipo quedó vinculado pero no llegó a la cuenta del cliente, la app lo dice: «Equipo vinculado, falta la cuenta del cliente».
- Mensaje claro cuando el equipo no está dado de alta: «El equipo … no está dado de alta en el dashboard. Avisa a operaciones.»

## Build 22 — 30 de septiembre de 2026

- Los metros reales que mides en la inspección pasan al paso de instalación («Metros a instalar») y a la tarjeta del servicio sin recargar.

## Build 21 — 30 de septiembre de 2026

- App lista para Google Play (Android), con ícono definitivo.

## Build 20 — 28 de septiembre de 2026

- Cancelar en sitio con motivo, notas, foto opcional y ubicación; ahora sí llega a operaciones.
- El Historial muestra completadas y canceladas en sitio (etiqueta «Cancelada», fecha y motivo).

## Build 19 — 26 de septiembre de 2026

- Teclado con barra «Listo» en iPhone; tocar fuera lo cierra y la barra inferior ya no se sube sobre el contenido.
- Vincular: «Vincular» revisa la serie escrita y «Escanear QR» abre la cámara real. Una serie repetida se avisa al capturarla, no hasta el cierre.
- El contador de Instalaciones cuenta solo lo pendiente.

## Build 18 — 26 de septiembre de 2026

- Botón «Cómo llegar»: Google Maps, Waze, Apple Maps o copiar la dirección.

## Build 17 — 26 de septiembre de 2026

- Ya no se queda la pantalla en negro al regresar después de cerrar o cancelar un servicio.
- El inicio de sesión recuerda tu correo.
- La constancia fiscal ya no se sube desde la app; la carga OhmSafe.

## Build 16 — 26 de septiembre de 2026

- Datos generales del Perfil como texto de solo lectura.
- App en español (menús de copiar/pegar, fechas) y botón «Pegar código».
- Arreglo: el campo de contraseña nueva ya no se traba en iPhone.

## Build 15 — 26 de septiembre de 2026

- Primer ingreso con código por correo, bienvenida de instalador certificado y contraseña propia.
- Nombre, teléfono, correo, CURP y foto solo los cambia OhmSafe.

## Build 14 — 26 de septiembre de 2026

- Instalaciones de varios días en el calendario, con su rango de fechas.
- Avisos al publicarte un servicio.
- «Mis pagos» y «Cotizar venta».

## Build 12 — 25 de septiembre de 2026

- «Reportar incidencias», lista de «Mantenimientos» y calificación real de tus clientes en el Perfil.

## Build 11 — 25 de septiembre de 2026

- La app trabaja sobre las intervenciones de servicio y registra tu ubicación real en la llegada y el cierre.

## Build 10 — 24 de septiembre de 2026

- La sesión se mantiene y puedes entrar con Face ID / huella.
- Inicio simplificado.
- Las notificaciones se ven aunque tengas la app abierta.

## Build 8 — 18 de septiembre de 2026

- Fechas y horas en la hora de tu teléfono.
