# Novedades por versión

De la más reciente a la más antigua. Todas son versión 1.0.0; cambia el número de build.

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
