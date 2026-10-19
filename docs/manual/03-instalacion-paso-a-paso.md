# Instalación paso a paso

Una instalación tiene 5 pasos. La app guarda cada paso en cuanto lo terminas: si cierras la app o se va la señal, al volver retomas donde te quedaste.

| Paso | Nombre en la app |
|---|---|
| 1 | «Técnico en ruta» |
| 2 | «Inspección del perímetro» |
| 3 | «Instalación de cerca eléctrica» |
| 4 | «Vincular el energizador» |
| 5 | «Prueba del energizador» |
| 6 | «Agregar dispositivos» (opcional) |
| 7 | «Cierre de la instalación» |

## Antes de salir: revisa la orden

1. En **Instalaciones**, toca el día y abre la tarjeta del servicio.
2. Revisa dirección, teléfono, «Metraje» y «Condiciones del terreno».
3. Lleva el material y el energizador. El metraje que ves es el que el cliente le dio a operaciones por teléfono; el real lo mides tú en el paso 2.

## Cómo llegar

El botón «Cómo llegar» está en la tarjeta y dentro del servicio.

1. Toca «Cómo llegar».
2. Elige «Google Maps», «Waze» o «Apple Maps» (solo iPhone), o «Copiar dirección».
3. Si el cliente tiene ubicación guardada, el mapa usa sus coordenadas; si no, la dirección.

Si no abre: «No se pudo abrir el mapa. Copia la dirección y pégala en tu app de mapas.»

## Paso 1 — En ruta y llegada

1. En la tarjeta toca «Iniciar ruta de servicio».
2. Confirma en «¿Estás seguro de iniciar la ruta?» con «Iniciar ruta de servicio».
   - Al confirmar, el cliente recibe un correo de que vas en camino.
3. Ves la animación «Iniciando Ruta de servicio» y luego la lista «PASOS DE LA ORDEN».
4. Toca el paso «Técnico en ruta». Se abre «Detalles de Ruta».
5. Al llegar al domicilio toca «Marcar llegada».
   - La app toma tu ubicación. Esa ubicación es la referencia para el cierre: debes cerrar a menos de 300 m de donde marcaste la llegada.
   - Si el teléfono pide permiso de ubicación, acéptalo.

Si falla verás «No se pudo marcar la llegada: …» y el paso no avanza. Inténtalo de nuevo con señal.

Si la orden aún no tiene fecha, al iniciar ruta verás: «No se pudo iniciar la ruta: Esta intervención aún no está programada. Operaciones debe confirmar día y hora con el cliente antes de iniciar la ruta.»

## Paso 2 — Inspección del perímetro

1. Toca «Inspección del perímetro».
2. Revisa «Metraje agendado» y corrige «Metraje real» con lo que mediste en sitio (en metros).
3. En «OBSTÁCULOS EN EL TERRENO» marca todos los que haya: «Malla ciclónica», «Vegetación», «Concertina», «Árboles», «Herrería», «Desniveles», «Arcos», «Cableado», «Altura superior».
   - Si no hay ninguno, marca «Perímetro sin obstáculos».
4. Toca «Completar perímetro».

El metraje real queda como «Metros a instalar» en el paso 3 y en la tarjeta del servicio.

## Paso 3 — Instalación de cerca eléctrica

1. Toca «Instalación de cerca eléctrica».
2. Verás «Metros a instalar» (el real del paso 2).
3. En «CONTEO DE MATERIALES» ajusta con «−» y «+» lo que realmente instalaste: «Postes esquina», «Postes de paso», «Líneas», «Abanicos», «Letrero Ohmsafe», «Letrero Precaución».
   - Los contadores ya traen números de inicio. Corrígelos siempre con lo real.
4. Toca «Completar instalación».

## Ayuda en pantalla (desde la build 43)

- Donde algo puede confundir hay un ícono **ⓘ**. Tócalo: se abre una hoja corta con el «cómo funciona». Se cierra con **«Entendido»**.
- Si el botón final del cierre está apagado, la pantalla dice **qué falta** («Para terminar falta: …»).

## Paso 4 — Vincular el energizador

Ver el procedimiento completo en [04 — Vincular energizador](04-vincular-energizador.md). Al vincular, la app abre sola la prueba del energizador.

## Paso 5 — Prueba del energizador

Es obligatoria para poder cerrar. Sirve para que el cliente vea que la cerca funciona.

1. Arriba ves la serie, la conexión y si la cerca está encendida o apagada.
2. Toca **«Encender la cerca»** y luego **«Apagar la cerca»** (es el mismo botón, cambia según el estado). Mientras el equipo responde verás «Enviando al energizador…».
3. En **«MUÉSTRALE AL CLIENTE»** se marcan «Encendiste la cerca» y «La apagaste» conforme lo haces. Con las dos marcadas, **«Terminar prueba»** se vuelve el botón principal.
4. Toca **«Terminar prueba»**. Si la cerca quedó encendida, la app pregunta **«¿Dejas la cerca encendida?»**.

- El equipo debe tener señal. Si no, verás **«El energizador no tiene señal»**; la pantalla se actualiza sola.
- Lo que dispare el equipo durante la prueba (por ejemplo, tocar las líneas) **no manda avisos ni llamadas**: queda registrado como prueba.
- Sólo controlas la cerca del cliente **mientras esta pantalla está abierta**. Al terminar, o al salir con la flecha o el gesto de regresar, el control se retira y queda sólo en manos del cliente.

## Paso 6 — Agregar dispositivos (opcional)

Agrega **sólo lo que el cliente compró**. Cada cosa se prueba en vivo y sólo se guarda si funciona. Si no instalaste nada extra, salta este paso. Puedes volver a entrar hasta antes del cierre (por ejemplo, si el cliente compra algo más en sitio). Al terminar toca **«Listo, volver a los pasos»**. Cada sección tiene su ⓘ.

Las secciones, en este orden:

> **Según tu build:** «Conectar sensor Wi‑Fi», «Conectar cámara a la Wi‑Fi» y «Conectar cámara Tuya» llegan con la **build 49**, que hoy está **sólo en pruebas**. En la build de la tienda (47) la sección de sensores Wi‑Fi está apagada y en Cámaras sólo aparece la captura de serie y código («Cámara ya conectada»).

- **Sensores cableados** (puertas con cable). Toca **«Probar»** en la entrada. La fila te guía: **«1 de 2 · Cierra la puerta y espera 3 segundos»** y luego **«2 de 2 · Ahora ábrela»**. Cuando diga **«Funciona»**, toca **«Guardar»** y escribe qué puerta es. Si dice «No vimos la puerta cerrar y abrir», revisa el cable del sensor y toca **«Reintentar»**. Si la alarma estaba armada, la app la desarma antes para que la prueba no haga sonar la sirena.
- **Sirena.** Toca **«Probar»**: suena 3 segundos (avísale al cliente antes). Contesta **«¿Sonó la sirena?»**.
- **Salidas auxiliares** (luces, portón y otros). Toca **«Probar»**: la salida se enciende 5 segundos. Contesta **«¿Se encendió?»** y, si sí, escribe el nombre, **qué es** (luz, bomba, portón, sirena externa, otro) y **cómo funciona** (encendido/apagado, o pulso como un portón). Si no encendió, no se guarda y queda anotado en el reporte.
- **Sensores inalámbricos** (puerta, movimiento, humo o botón de pánico, por radio). Toca **«Agregar»**, elige el tipo y haz lo que diga la pantalla (abrir la puerta, pasar frente al sensor, apretar su botón). Cuando diga **«Aprendido»**, ponle nombre y **«Guardar»**. El energizador debe tener señal. Los controles remotos (llaveros) se dan de alta desde el dashboard.
- **Sensores Wi‑Fi (Tuya).** Toca **«Conectar sensor Wi‑Fi»** (aparece cuando el servidor tiene Tuya encendido). Antes: pon el sensor en modo de emparejamiento (mantén su botón 5–10 s hasta que la luz parpadee rápido), tu teléfono en la Wi‑Fi de la casa **de 2.4 GHz**, y el cliente a la mano. Elige qué es (puerta, movimiento, humo), ponle nombre, revisa el **nombre de la red** y que el cliente **escriba su contraseña** (no se guarda). Modo **Rápido** es el normal; si falla, **Punto de acceso** (el teléfono se une a la red «SmartLife-XXXX» del sensor). Toca **«Conectar el sensor»**; tarda hasta 2 minutos. El sensor queda en la cuenta del cliente y lo ve en OhmSafe GO.
    - «La casa todavía no tiene cuenta Tuya»: el cliente debe entrar una vez a OhmSafe GO en su teléfono; luego vuelves a intentar.
    - «El equipo no llegó a la nube»: casi siempre es la contraseña o una red de 5 GHz; revisa que la luz siga parpadeando rápido.
- **Cámaras.** Hay dos caminos:
  - **«Conectar cámara a la Wi‑Fi»** (cámara EZVIZ nueva, recién sacada de la caja). Antes: la cámara enchufada 2 minutos y con la luz parpadeando (si ya se usó antes, mantén RESET 10–15 s); tu teléfono en la Wi‑Fi de la casa, **de 2.4 GHz** (no 5 GHz); y el cliente a la mano. En la pantalla: escanea el QR de la etiqueta (o escribe la **serie** y el **código de verificación** de 6 letras), ponle nombre, revisa que el **nombre de la red** sea la Wi‑Fi de la casa y pídele al cliente que **escriba su contraseña** (sólo sirve para pasársela a la cámara; **no se guarda**). Toca **«Conectar la cámara»**. Si el teléfono pregunta «¿Conectarse a la red EZVIZ_…?», acepta: es la cámara. Tarda hasta 3 minutos; no cierres la app ni te alejes. Al terminar, la cámara queda en la casa del cliente con el nombre de su red (así soporte sabe a qué red estaba si cambian de módem).
    - «Esta cámara está ligada a otra cuenta de EZVIZ»: el cliente la tiene en su app EZVIZ. Que la quite de ahí o restablece la cámara de fábrica.
    - «La cámara no llegó a internet»: casi siempre es la contraseña, o una red de 5 GHz. Revisa y vuelve a intentar.
    - «No está en modo de configuración»: mantén RESET 10–15 s hasta que la luz parpadee y espera a que esté lista.
  - **«Cámara ya conectada»** (cámara que ya está en internet: Imou, o conectada con la app del fabricante). Escribe la **serie**, el **código de verificación** y un nombre.
  - **«Conectar cámara Tuya»** (cámara Tuya nueva). Igual que el sensor Wi‑Fi: modo de emparejamiento, red de 2.4 GHz, contraseña del cliente, «Conectar la cámara».
- **Agregar otro energizador en esta casa.** Arriba, en un recuadro oscuro, ves los energizadores que ya tiene la casa (serie, «Principal» y si está «En línea»); es sólo información. Si el cliente compró un segundo energizador para la misma casa, toca **«Agregar»** en **«Agregar otro OhmBox»** y escanea o escribe su serie. Se suma como complemento de la suscripción de esa casa; no crea una nueva.

Las puertas con cable, la sirena y las salidas piden firmware **2.10 o superior**; si el equipo es más viejo verás «Este energizador necesita actualizarse» (lo demás sí se puede agregar). Todo lo guardado queda en el acta de la instalación (Odoo).

## Paso 7 — Cierre de la instalación

Toca «Cierre de la instalación». Tiene 3 partes: **1 · Fotos**, **2 · Entrega** y **3 · Firma**.

### 7.1 Fotos

1. En **«FOTOS OBLIGATORIAS»** toma las 4: «Perfil izquierdo», «Perfil derecho», «Energizador», «Letrero OhmSafe». El ⓘ dice qué debe verse en cada una.
2. Para cada una elige «Tomar foto» o «Elegir de la galería».
3. Cada foto se sube en cuanto la tomas: «Subiendo…», «Subida» o «No se subió · Toca para reintentar».
4. Cada foto guarda su ubicación. Si una dice **«Lejos del domicilio»**, aparece «Una foto no se tomó en el domicilio» y el campo cambia a **«¿POR QUÉ NO COINCIDE LA UBICACIÓN?»**: explica el motivo (por ejemplo, no había señal de GPS).
5. Si quieres, escribe algo en **«COMENTARIOS (OPCIONAL)»**.
6. Toca **«Siguiente»**. Si falta alguna: «Faltan fotos: toma las 4 para seguir.»

### 7.2 Entrega

1. Marca **«Le entregué el control remoto y funciona»**.
2. En **«EXTRAS DEL SERVICIO»** responde **Cámaras**, **Sensores** y **Sirena** con «Instalé y funciona» o «No aplica» (no venía en lo que compró). El ⓘ lo explica.
3. En **«¿CÓMO QUEDÓ TODO?»** elige «Todo funciona» o «Con problemas».
   - Con problemas: en **«¿QUÉ PASÓ?»** marca «El equipo está dañado», «Algo no funciona» o «El control remoto no funcionó», o descríbelo en **«CUÉNTANOS QUÉ PASÓ»**.
4. Toca **«Siguiente»**.

Mensajes si falta algo: «Falta confirmar la entrega del control remoto.», «Responde cámaras, sensores y sirena (o marca «No aplica»).», «Marca qué pasó o descríbelo abajo.»

### 7.3 Firma

1. Pide al cliente que firme con el dedo en el recuadro que dice **«Firma aquí con el dedo»**.
2. «Limpiar» borra la firma; cuando esté bien, toca **«Confirmar firma»**. Verás «Firma guardada». Para corregirla toca **«Volver a firmar»**.
3. Toca **«Terminar instalación»**. Verás «Enviando el cierre…». Si el botón está apagado, la línea **«Para terminar falta: …»** dice qué hace falta.

Al enviar, la app toma otra vez tu ubicación. Si estás a más de 300 m de donde marcaste la llegada aparece «Estás lejos del sitio»:

- «Revisar» — no cierra; acércate al domicilio y vuelve a intentar.
- «Sí, cerrar aquí» — cierra de todos modos. Queda registrado que cerraste lejos.

Otros mensajes:

- «No se pudo subir la foto de … Revisa tu conexión y toca «Reintentar» en el paso 1.» — antes de cerrar la app reintenta sola las fotos pendientes; si aun así faltan, regresa con «Atrás».
- «No se pudo capturar la firma. Pide al cliente que firme de nuevo.»
- «No se pudo enviar el cierre: …» — el cierre no se guardó. Revisa señal y vuelve a tocar «Terminar instalación».

### 7.4 Terminar

Al cerrar regresas a la lista de pasos con todo en verde. Toca «Terminar instalación»: aparece «¡Instalación terminada!» y el botón «Volver a instalaciones».

## Qué pasa después del cierre

- El cliente recibe por correo su reporte de servicio (PDF) y una encuesta de satisfacción. Su calificación cuenta para tu promedio en el Perfil.
- El servicio sale de tu agenda y aparece en **Historial** como completado.
- Tu pago por esa instalación aparece en **Mi cuenta › Mis pagos** como «En revisión» hasta que operaciones lo valide.

## Retomar un servicio a medias

Desde la build 41, si el energizador ya está vinculado la app retoma en **Prueba del energizador**; si la prueba ya se terminó u omitió, en **Agregar dispositivos** con el cierre disponible.


Si saliste a mitad del servicio, en la tarjeta el botón dice «Continuar · [paso]», por ejemplo «Continuar · Marcar llegada», «Continuar · Inspección del perímetro», «Continuar · Registrar instalación», «Continuar · Vincular energizador» o «Continuar · Cierre y firma». Tócalo y la app te lleva directo al paso pendiente; los anteriores ya aparecen completos.

## Instalación de varios días

Es un solo servicio que aparece en cada día de su rango. Al día siguiente ábrelo y sigue con «Continuar · …».

## Cancelar

Si no puedes hacer la instalación, usa «Cancelar instalación». Ver [05 — Cancelar en sitio](05-cancelar-en-sitio.md).
