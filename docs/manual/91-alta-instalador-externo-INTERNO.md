# Alta de un instalador externo en Odoo (guía de operaciones)

> **USO INTERNO — no publicar.** Para operaciones y SAC de OhmSafe. El instalador no toca Odoo: OhmSafe carga todo y él sólo activa la app con su correo.

## En una frase

El instalador externo es un **contacto** con la etiqueta «Instalador Externo-OS». Al guardarlo, el sistema crea solo su número de instalador, su código de venta, su ficha de empleado (archivada) y su acceso a la app. **Aparece en Planificación únicamente cuando OhmSafe pone su Estado en «Activo».**

## Antes de empezar: ten a la mano

| Dato | Obligatorio para operar | Nota |
|---|---|---|
| Nombre completo | Sí | Como quieres verlo en Planificación y en la app |
| Correo personal | Sí | Con él entra a la app. **Debe ser suyo y no estar ya como usuario de otra persona en Odoo** (ver «Problemas frecuentes») |
| Teléfono con lada | Sí | Formato `+52 55 1234 5678`. Odoo descarta números que no parecen válidos y la ficha queda «sin teléfono» |
| CURP | Sí | |
| Constancia de situación fiscal (PDF) | Sí | Se adjunta en la ficha |
| RFC | Sólo si factura a OhmSafe | |
| Foto | Recomendada | Es la foto oficial: se copia a su ficha de empleado y la ve el cliente en la app |
| Dirección | Recomendada | |

Mientras falte alguno de los obligatorios, la barra superior de la ficha dice **«Faltan datos»** y el chatter lista cuáles.

## Paso a paso

### 1. Crear el contacto desde la pestaña correcta

1. Odoo › **Contactos › Instaladores externos** (menú de arriba). Esta lista ya filtra por la etiqueta y, al crear desde aquí, la pone sola.
2. **Nuevo**. Se abre el formulario «Instalador externo» (barra *Avance de alta* arriba, foto a la derecha).
3. Escribe el **Nombre completo** y **no elijas ninguna sugerencia** del desplegable que aparece al escribir: ese desplegable es el autocompletado de empresas de Odoo y rellena la ficha con datos de un tercero (nombre, RFC y dirección de otra persona). Si ya pasó, corrige nombre, RFC y dirección antes de guardar.
4. Captura correo, teléfono, CURP, RFC si aplica, dirección y sube la **Constancia fiscal (PDF)** y la foto.
5. Verifica que en **Roles** esté «Instalador Externo-OS». Si además es cliente de OhmSafe, puede llevar también «Cliente Residencial»: es el mismo contacto.
6. **Guardar.**

Lo que pasa solo al guardar (tarda unos segundos; refresca la ficha):

- **Identificadores OhmSafe**: número de instalador (5 dígitos) y código de venta `OHMS-…`. Son de solo lectura.
- **Ficha de empleado** con su nombre, su foto, horario «Instalador externo · lunes a domingo» y rol «Instalador OhmSafe Externo». Nace **archivada**: todavía no se puede planificar.
- **Acceso a la app** con su correo, sin contraseña (la crea él al activar).
- Nota en el chatter: «Faltan datos…» o «Datos completos. Falta que descargue la app y active su cuenta con su correo».

### 2. Activarlo (lo decide OhmSafe)

1. En la ficha, **Estado (lo decide OhmSafe)** → **Activo**.
2. Guardar. En el chatter aparece «Disponible en Planificación: ya se le puede asignar trabajo».

Desde este momento su ficha de empleado está activa y sale en Planificación con **el nombre del contacto**. Si lo activas antes de que complete su alta, se puede planificar, pero no recibirá avisos hasta que active la app (el chatter lo advierte).

Los otros valores:

| Estado | En Planificación | En la app |
|---|---|---|
| Activo | Aparece | Entra |
| Temporalmente no disponible | No aparece | Entra (ve su historial, no recibe trabajo) |
| Suspendido | No aparece | Bloqueado («cuenta suspendida») |
| (vacío) | No aparece | Entra si ya activó |

### 3. Que active la app

Dile al instalador:

1. Instalar **OhmSafe Installer** (TestFlight en iPhone, Google Play en Android).
2. Entrar con **su correo** (el que capturaste) → «Te enviamos un código».
3. Escribir el código de 6 dígitos que le llega por correo (vale 10 minutos).
4. Crear su contraseña (mínimo 8, letras y números).

Cuando termina, el chatter del contacto dice «Activó su cuenta en la app de instaladores» y la barra pasa a **«Alta completa»**. Él recibe el correo de bienvenida «Instalador certificado OhmSafe».

### 4. Asignarle trabajo en Planificación

1. Odoo › **Planificación** › abre la intervención (o crea el turno).
2. En **Recurso**, empieza a escribir su nombre y **elige el que ya existe**.
3. Guarda y publica. La app le avisa y la intervención aparece en su agenda.

> **Nunca escribas un nombre nuevo en Recurso y pulses «Crear»**: Odoo crea un empleado suelto (sin contacto, con horario de 40 h, que además cuenta como usuario de pago) y el instalador real sigue sin trabajo. Si no aparece en el desplegable, revisa el paso 2.

## Cómo verificar que quedó bien

| Dónde | Qué debe verse |
|---|---|
| Contactos › Instaladores externos › ficha | Barra «Alta completa»; Estado «Activo»; número y código llenos; roles con «Instalador Externo-OS» |
| Chatter de la ficha | «Disponible en Planificación…» y «Activó su cuenta…» |
| Empleados (incluir archivados) | Una sola ficha con su nombre, ligada al contacto («Contacto laboral»); activa |
| Planificación › Recurso | Su nombre en el desplegable |
| App | Su agenda (vacía hasta la primera asignación) |

## Problemas frecuentes

| Síntoma | Causa | Qué hacer |
|---|---|---|
| No aparece en Planificación | Estado no es «Activo»; o no tiene la etiqueta; o la ficha de empleado está archivada | Poner Estado «Activo» y guardar. Si sigue sin salir, abre la ficha y vuelve a guardar (vuelve a correr la preparación) |
| Aparece en Planificación con **otro nombre** | El contacto se creó con un nombre (p. ej. el del autocompletado) y luego se corrigió | Guardar de nuevo la ficha: el nombre del empleado se actualiza solo (desde el 2026-10-05). Verifica también RFC y dirección |
| Hay **dos** empleados con su nombre | Alguien lo «creó» desde Planificación | Archivar el empleado que **no** tiene «Contacto laboral» (no borrarlo si ya tiene turnos) y volver a asignar con el correcto |
| Chatter: «No se pudo crear su acceso a la app: el correo … ya lo usa otro usuario de Odoo» | Ese correo ya es el usuario de otra persona (un empleado, por ejemplo) | Capturar un correo que sea sólo suyo. Pendiente definir con Carlos qué hacer cuando un empleado también instala |
| «Faltan datos: teléfono» aunque lo escribiste | Odoo descartó el número por formato | Volver a capturarlo con lada: `+52 …` |
| «Pediste demasiados códigos hoy» | Tope de 8 códigos por día y 60 s entre envíos | Esperar al día siguiente o, en periodo de pruebas, OhmSafe puede apagar el límite en el servidor |
| «Cuenta suspendida» en la app | Estado «Suspendido» | Es intencional. Para reactivar: Estado «Activo» |
| El código no le llega | Correo mal capturado o en spam | Corregir el correo en la ficha; que revise spam; pedir el código de nuevo desde la app |

## Baja o pausa

- **Pausa**: Estado «Temporalmente no disponible». Sale de Planificación; sus turnos ya asignados se quedan, reasígnalos.
- **Baja definitiva**: Estado «Suspendido» (bloquea la app) y, si procede, quitar la etiqueta «Instalador Externo-OS». No borres el contacto: su historial de intervenciones y pagos cuelga de él.

## Nota de costo (pendiente)

Hoy cada instalador activo tiene una ficha de empleado, y Odoo cobra los empleados activos sin usuario interno como usuarios de pago. Está en análisis cambiar a recursos de Planificación que no sean empleados; mientras tanto, mantén archivados (Estado distinto de «Activo») a los que no están operando.
