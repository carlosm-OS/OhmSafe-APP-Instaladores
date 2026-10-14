# Instalación paso a paso

Una instalación tiene 5 pasos. La app guarda cada paso en cuanto lo terminas: si cierras la app o se va la señal, al volver retomas donde te quedaste.

| Paso | Nombre en la app |
|---|---|
| 1 | «Técnico en ruta» |
| 2 | «Inspección del perímetro» |
| 3 | «Instalación de cerca eléctrica» |
| 4 | «Vinculación del energizador» |
| 5 | «Cierre de la instalación» |

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

## Paso 4 — Vinculación del energizador

Ver el procedimiento completo en [04 — Vincular energizador](04-vincular-energizador.md). Al terminar regresas a la lista de pasos.

## Paso 5 — Prueba del energizador (opcional, desde la build 39)

Al vincular el energizador la app abre sola esta pantalla con un reloj de **30 minutos** (puedes
extenderlo de 15 en 15 hasta 2 horas). Mientras corre:

- **Encender cerca** pone alto voltaje en la línea; **Apagar cerca** lo quita. Úsalo las veces que
  haga falta para mostrarle al cliente que el equipo trabaja. El equipo debe estar **en línea**;
  si no reporta, la app te lo dice y los botones se bloquean.
- Lo que dispare el equipo durante la prueba (por ejemplo, tocar las líneas) **no manda avisos
  ni llamadas** a nadie: queda registrado como prueba.
- **Terminar prueba y cerrar**: el control del equipo se retira en ese momento y pasas al cierre.
  Si la cerca queda encendida, la app te lo pregunta antes.
- **Omitir la prueba** hace lo mismo sin probar. Si sales con la flecha también se retira el
  permiso.

La sirena, el pánico y los sensores se prueban en otro paso (próximamente «Agregar dispositivos»).

## Paso 6 — Agregar dispositivos (opcional, desde la build 39)

Lo cableado al OhmBox se da de alta **probándolo en vivo**; la app sólo acepta lo que el equipo
confirma. Necesitas firmware **2.10 o superior** y el equipo en línea.

- **Entradas (puertas).** Toca «Probar» en la entrada. **Cierra la puerta** y espera a que el equipo
  la vea cerrada 3 segundos; luego **ábrela**. Cuando la tarjeta diga «Verificada», ponle nombre y
  «Dar de alta». Si no hay sensor conectado, la prueba nunca pasa y a los 3 minutos expira.
  Si la alarma estaba armada, la app la desarma antes para que la prueba no haga sonar la sirena.
- **Sirena.** «Probar 3 s»: el equipo la enciende y la apaga. Contesta «¿Sonó?».
- **Salidas auxiliares.** «Encender 5 s»: el relé cierra y se suelta. Contesta «¿Se encendió?» y,
  si sí, ponle nombre, di **qué es** (luz, bomba, portón, sirena externa, otro) y **cómo funciona**
  (encendido/apagado, o pulso como el botón de un portón). Si no encendió, queda en el acta y no
  se da de alta.

Todo lo probado y dado de alta queda escrito en el acta de la instalación (Odoo), que es lo que
soporte consulta después.

## Paso 7 — Cierre de la instalación

Toca «Cierre de la instalación». El cierre tiene 3 partes: «Evidencias», «Equipo» y «Firma».

### 5.1 Evidencias

1. En «EVIDENCIAS FOTOGRÁFICAS OBLIGATORIAS» toma las 4 fotos: «Perfil izquierdo», «Perfil derecho», «Energizador», «Letrero OhmSafe».
2. Para cada una elige «Tomar foto» o «Elegir de la galería».
3. Cada foto se sube en cuanto la tomas:
   - «Subiendo…» — espera.
   - «Subida» — lista.
   - «No se subió · Reintentar» — toca para reintentar sin volver a tomarla.
4. Si quieres, escribe observaciones en «COMENTARIOS Y JUSTIFICACIÓN DE ANOMALÍAS».
5. Toca «Siguiente Paso».

Si falta alguna foto: «Por favor, toma las 4 fotografías obligatorias.»

### 5.2 Equipo (entrega)

1. Marca «Entregué funcional el control remoto».
2. En «ADDONS DEL SERVICIO» responde las dos:
   - «Instalé y dejé funcionando cámaras»: «Instalé y funciona» o «No aplica».
   - «Instalé y dejé funcionando sensores»: «Instalé y funciona» o «No aplica».
   - «Instalé y dejé funcionando sirena»: «Instalé y funciona» o «No aplica» (por ahora es tu confirmación; más adelante el equipo lo validará solo).
3. En «ESTADO DE LA ENTREGA» elige «Todo funcional» o «Con anomalías».
   - Con anomalías: marca el tipo («Daño físico en el equipo», «Falla de funcionamiento», «El control remoto no funcionó») o descríbelo en «DESCRIPCIÓN DE LA ANOMALÍA».
4. Toca «Siguiente».

No se pide foto ni número de serie en esta parte. Mensajes si falta algo:

- «Confirma que entregaste el control remoto funcional.»
- «Indica si instalaste cámaras, sensores y sirena, o marca «No aplica».»
- «Indica el tipo de anomalía o descríbela en los comentarios.»

### 5.3 Firma

1. Pide al cliente que firme con el dedo en el recuadro.
2. «Limpiar» borra la firma; cuando esté bien, toca «Confirmar Firma». Verás «Firma Registrada». Para corregirla toca «Modificar».
3. Toca «TERMINAR INSTALACIÓN». Verás «Enviando Cierre...».

Al enviar, la app toma otra vez tu ubicación. Si estás a más de 300 m de donde marcaste la llegada aparece «Estás lejos del sitio»:

- «Revisar» — no cierra; acércate al domicilio y vuelve a intentar.
- «Sí, cerrar aquí» — cierra de todos modos. Queda registrado que cerraste lejos.

Otros mensajes:

- «No se pudo subir la foto de … Revisa tu conexión y toca «Reintentar» en el paso 1.» — antes de cerrar la app reintenta sola las fotos pendientes; si aun así faltan, regresa con «Atrás».
- «No se pudo capturar la firma. Pide al cliente que firme de nuevo.»
- «No se pudo enviar el cierre: …» — el cierre no se guardó. Revisa señal y vuelve a tocar «TERMINAR INSTALACIÓN».

### 5.4 Terminar

Al cerrar regresas a la lista de pasos con los 5 en verde. Toca «Terminar instalación»: aparece «¡Instalación Finalizada!» y el botón «Volver a Instalaciones».

## Qué pasa después del cierre

- El cliente recibe por correo su reporte de servicio (PDF) y una encuesta de satisfacción. Su calificación cuenta para tu promedio en el Perfil.
- El servicio sale de tu agenda y aparece en **Historial** como completado.
- Tu pago por esa instalación aparece en **Mi cuenta › Mis pagos** como «En revisión» hasta que operaciones lo valide.

## Retomar un servicio a medias

Si saliste a mitad del servicio, en la tarjeta el botón dice «Continuar · [paso]», por ejemplo «Continuar · Marcar llegada», «Continuar · Inspección del perímetro», «Continuar · Registrar instalación», «Continuar · Vincular energizador» o «Continuar · Cierre y firma». Tócalo y la app te lleva directo al paso pendiente; los anteriores ya aparecen completos.

## Instalación de varios días

Es un solo servicio que aparece en cada día de su rango. Al día siguiente ábrelo y sigue con «Continuar · …».

## Cancelar

Si no puedes hacer la instalación, usa «Cancelar instalación». Ver [05 — Cancelar en sitio](05-cancelar-en-sitio.md).
