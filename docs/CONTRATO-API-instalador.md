# Contrato API — App Instaladores (borrador v0.1)

> Borrador derivado de los flujos reales de la app. Formato pensado para volverse
> anotaciones `@swagger` en el backend `ohmsafe`. Para revisión de Carlos + Dan
> **antes** de construir. Nada aquí está implementado todavía.

## Convenciones
- **Base:** `/v1/instalador/*` (nuevo dominio `field-service` en el backend `ohmsafe`).
- **Auth:** `Authorization: Bearer <accessToken>` (login contra usuario de Odoo; reusa `User` + `RefreshToken`).
- **Escrituras idempotentes:** header `Idempotency-Key: <uuid>` en todos los `POST/PUT` de acción.
- **Fechas:** ISO-8601. **IDs:** string. **Errores:** `{ "code": "STRING", "message": "...", "details"?: {...} }`.
- **Fuente de verdad:** Odoo para la operación del instalador; HubSpot donde nacen los tickets (reflejados vía motor `Sync*` existente); evidencias en **S3** (`integrations/s3`); energizador vía `domains/devices`.

---

## 1. Auth
| Método | Ruta | Cuerpo | Respuesta |
|---|---|---|---|
| POST | `/v1/instalador/auth/login` | `{email, password, deviceId?, deviceName?}` | `{accessToken, refreshToken, expiresIn?, sesionPersistente, debeCambiarPassword, instalador:{id, nombre, numeroInstalador, rol}}`. Con `deviceId` el refresh es persistente (30 d deslizantes, tope 180, ligado al dispositivo) |
| POST | `/v1/instalador/auth/refresh` | `{refreshToken, deviceId}` | `{accessToken, refreshToken, expiresIn}` — rota; 401 = sesión muerta (revocada, vencida u otro dispositivo) |
| POST | `/v1/instalador/auth/logout` | `{refreshToken}` | `{ok:true}` — público e idempotente |

**Sesión en la app (nivel A):** el refresh vive en Keychain/Keystore (`SecureSessionStore`), el access sólo en memoria; `DioClient` reintenta UNA vez tras un 401 usando `SessionManager.refrescar()` (single-flight). Face ID/Touch ID no habla con el servidor: sólo desbloquea el uso del refresh guardado; se invita una vez tras el primer inicio, se pide al arrancar y al volver del fondo pasados 15 min, y se administra en Perfil › Seguridad. Ver `docs/sesiones-instalador.md` del backend.

## 2. Perfil (bidireccional con Odoo)
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/perfil` | `{id, nombre, numeroInstalador, rol, calificacion, codigoVentas, avatarUrl, telefono, email, curp}` |
| PUT | `/v1/instalador/perfil` | datos generales (nombre, telefono, email, curp) |
| GET/PUT | `/v1/instalador/datos-bancarios` | `{titular, clabe, banco, cuenta}` |
| GET/PUT | `/v1/instalador/facturacion` | datos fiscales |

## 2b. Push y zona horaria
| Método | Ruta | Notas |
|---|---|---|
| POST | `/v1/instalador/push/registrar` | `{token, platform, zonaHoraria?}`. `zonaHoraria` es el IANA del dispositivo (`America/Tijuana`), leído con `flutter_timezone`; el backend lo guarda en el `tz` del instalador en Odoo y con él redacta la hora de los avisos y del PDF. Respuesta `{ok, zonaHoraria}` |

**Fechas:** todo lo que llega del backend con forma `"YYYY-MM-DD HH:MM:SS"` (`fechaAgendada`,
`fechaCreacion`, `fechaPagoConfirmado`, `fecha` de notificaciones) está en **UTC sin zona**, tal
como lo guarda Odoo. La app lo convierte siempre a la hora del dispositivo con
`FechasOdoo` (`lib/core/utils/fechas_odoo.dart`); nunca parsear el texto crudo.

## 2g. Perfil: datos de identidad bloqueados (2026-09-26)
Por seguridad, **nombre, apellidos, teléfono, correo y CURP** del instalador sólo los cambia el equipo
de OhmSafe en Odoo. En la app son de sólo lectura (Perfil › Datos generales, sin botón Guardar).
`PUT /v1/instalador/perfil` sólo acepta `{ rfc }` (Facturación); si trae `nombre`, `apellidos`,
`telefono`, `email`, `correo` o `curp` responde `403 { error: 'DATO_NO_EDITABLE', message, details: { campos } }`
sin escribir nada (los builds ≤14 los mandaban al pulsar Guardar y ahora ven ese mensaje).

**La foto de perfil** tampoco se sube desde la app: `POST /v1/instalador/perfil/avatar` responde siempre
`403 DATO_NO_EDITABLE` (`details.campos = ['foto']`). La sube el equipo de OhmSafe en Odoo, en la ficha de
empleado del instalador; `GET /perfil` devuelve esa foto en `fotoBase64` (respaldo: la del contacto).

## 2h. Primer ingreso con código por correo (2026-09-26)
El instalador ya no recibe una contraseña temporal. La app pide primero el **correo**:

| Método | Ruta | Notas |
|---|---|---|
| POST | `/v1/instalador/auth/correo` | `{email, olvide?}` → `{siguiente: 'password' \| 'codigo', esperaSegundos?}`. «password» si ya creó su contraseña. Cualquier otro caso responde «codigo» (no revela quién es instalador) y, si procede, manda el código al correo. `olvide: true` fuerza el código |
| POST | `/v1/instalador/auth/codigo` | `{email, codigo}` (6 dígitos) → `{activacion, primeraVez, instalador:{nombre, numeroInstalador, fotoBase64}}`. Errores: `CODIGO_INCORRECTO` (details.intentosRestantes), `CODIGO_VENCIDO`, `DEMASIADOS_INTENTOS` |
| POST | `/v1/instalador/auth/activar` | `{activacion, password, deviceId, deviceName}` → misma respuesta que `/auth/login`. Contraseña ≥ 8 con letras y números (`WEAK_PASSWORD`); token de un solo uso (`ACTIVACION_VENCIDA`) |

> **App (2026-09-26):** el teléfono recuerda el último correo que entró (`dispositivo.ultimo_correo`, fuera de las claves de sesión: sobrevive al cierre y a la revocación). Si existe, el login abre directo en la contraseña con «Cambiar» y **no llama** a `/auth/correo`; el aviso «¿Primera vez?» sólo se muestra en un teléfono donde nadie ha entrado.

Pantallas: correo → (contraseña) o (código → **bienvenida «Instalador certificado OhmSafe»** sólo si
`primeraVez` → crear contraseña) → Face ID → inicio. El login de un instalador suspendido responde
`403 CUENTA_SUSPENDIDA`. La constancia fiscal también la carga OhmSafe: `POST|DELETE /perfil/constancia`
→ `403 DATO_NO_EDITABLE`; `GET /perfil` trae `constancia` (nombre del archivo), `estado`
(activo / no_disponible / suspendido / '') y `alta` (pendiente_datos / pendiente_activacion / completa).

## 2c. Órdenes con dos orígenes (fase 2, 2026-09-25) — **desde la fase 6 (2026-09-26) sólo hay un origen**
> El flujo de tareas de Proyecto se retiró: toda orden es una intervención de Planificación con id `i<n>`.
> Un id sin ese formato responde `400 VALIDATION_ERROR`. Los webhooks `/webhooks/instalacion`,
> `/webhooks/asignacion` y `/webhooks/reagenda` ya no existen. Lo que sigue en esta sección es histórico.

Una orden con id `i<n>` (p. ej. `i2`) es una **intervención de Planificación** de Odoo;
un id numérico es una tarea de Proyecto (las viejas, hasta cerrarse). Todos los
endpoints de `/ordenes/:id/...` aceptan ambos y devuelven la misma forma. Campos aditivos
en las intervenciones: `origen: 'intervencion'`, `ordenVenta` (p. ej. `S00152`),
`hojaTrabajo: [{nombre, etiqueta, tipo, valor}]`. En intervenciones `pasoActual` sale de
los marcadores de Odoo (salida, llegada = sign in, hoja de trabajo, equipo vinculado,
firma). Las notificaciones traen `ordenId` con el mismo prefijo. La app trata el id como
texto opaco: no requiere cambios para leerlas.

## 2d. Ubicación en llegada y cierre (fase 3, 2026-09-25)
`POST /ordenes/:id/marcar-llegada` acepta `{ubicacion:{lat,lng,precision}}` (opcional). En
intervenciones esa posición es la referencia del cierre. `POST /ordenes/:id/cierre` acepta
`ubicacion` y `confirmarUbicacion`. Si el cierre está a más de **300 m** de la llegada el
backend responde **409 `FUERA_DE_SITIO`** con `details:{distanciaM, radioM}`; la app muestra el
diálogo «Estás lejos del sitio» y reenvía con `confirmarUbicacion:true` si el instalador
confirma (queda en el chatter de Odoo). La app **nunca inventa** una posición: sin GPS o
permiso manda la petición sin `ubicacion`. `ServerFailure` ahora trae `code` y `details`.

## 2e. Postventa (fase 4, 2026-09-25)
| Método | Ruta | Notas |
|---|---|---|
| POST | `/v1/instalador/incidencias` | `{tipo, descripcion, ordenId?, fotoBase64?, ubicacion?}` → ticket de **Helpdesk** (equipo «Incidencias de campo»). `tipo` ∈ `equipo_danado \| cliente_ausente \| riesgo_en_sitio \| falta_material \| acceso_al_sitio \| otro`. Respuesta `{id, referencia, tipo, titulo, descripcion, estado, fecha, ordenId}` |
| GET | `/v1/instalador/incidencias` | mis tickets (los que sigo con la etiqueta de la app), misma forma |
| GET | `/v1/instalador/perfil` | ahora trae `calificacion` (promedio 1-5 de las encuestas de satisfacción, **null** sin respuestas) y `respuestasEncuesta` |

Al vincular un energizador el backend lo registra en **Mantenimiento** con su preventivo anual;
al cerrar manda la **encuesta** al cliente. Ninguno de los dos bloquea el paso de la app.

## 2f. Dinero (fase 5, 2026-09-25)
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/pagos` | `{pagos:[{id, referencia, concepto, ordenId, fecha, monto, pendiente, moneda, estado}], totales:{pagado, porPagar, pendienteValidacion, moneda}}`. Cada pago es una factura de proveedor en Odoo (Compras) que nace en borrador al cerrar la intervención. `estado` ∈ `pendiente_validacion \| por_pagar \| pagado \| cancelado` |
| GET | `/v1/instalador/catalogo` | productos con la etiqueta «App instalador», vendibles y con precio: `[{id, codigo, nombre, descripcion, precio, categoria, esServicio}]` |
| POST | `/v1/instalador/cotizaciones` | `{cliente:{nombre, email, telefono?, direccion?, ciudad?, cp?}, lineas:[{productoId, cantidad}], nota?, enviar?}` → orden de venta en Odoo atribuida al instalador (UTM «App instalador / Venta en campo» + código de venta en `origin`), enviada al cliente con la plantilla nativa. Respuesta `{id, referencia, cliente, fecha, total, moneda, estado, urlPortal}`. Error `PRODUCTO_NO_VENDIBLE` (400) si algún producto no está en el catálogo |
| GET | `/v1/instalador/cotizaciones` | mis cotizaciones, misma forma; `estado` ∈ `borrador \| enviada \| confirmada \| cancelada` |

Al cerrar una intervención el backend también crea la **factura al cliente** en borrador desde la
orden de venta; no bloquea el paso. Importes de pago al instalador: `standard_price` de los
productos `PAGO-*` en Odoo (hoy 0 hasta que Carlos los fije).

## 3. Órdenes de servicio (dominio nuevo `field-service`)
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/ordenes?tipo=&estado=&dia=` | `tipo=instalacion\|reparacion\|mantenimiento`; `estado=por_hacer\|en_curso\|completo\|cancelado`. Lista: `[{id, tipo, titulo, estado, urgente, cliente, direccion, ciudad, cp, telefono, direccionCompleta, coordenadas, metraje, fechaCreacion, diasAbierto}]`. `direccionCompleta` (calle, colonia, CP ciudad, estado, país) y `coordenadas:{lat,lng}\|null` (geolocalización del contacto en Odoo; null si Odoo tiene 0,0) alimentan el botón **«Cómo llegar»** (Google Maps / Waze / Apple Maps / copiar dirección; ver `lib/core/utils/como_llegar.dart`) |
| GET | `/v1/instalador/ordenes/{id}` | detalle + `registroInstalacion:{perimetroMetros, lineasInstaladas, postesEsquinaInstalados, postesPasoInstalados, abanicosInstalados, edadCercaAnios}` + `pasosCompletados:[...]` |
| POST | `/v1/instalador/ordenes/{id}/iniciar-ruta` | pasa a `en_curso`; notifica al cliente |
| POST | `/v1/instalador/ordenes/{id}/marcar-llegada` | completa paso 1 |
| POST | `/v1/instalador/ordenes/{id}/inspeccion-perimetro` | `{sinObstaculos:bool, obstaculos:[string]}` |
| POST | `/v1/instalador/ordenes/{id}/cancelar` | `{motivo}` |

## 4. Reparación — costeo
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/tarifas-reparacion` | reemplaza `repair_pricing.dart`. `{visita, metroHilo, posteEsquina, postePaso, abanico, aisladorSuelto, tensor, energizadorSimple, energizadorBateria, materiales:{...}, factoresDificultad:{normal, medio, alto}, tramoMaxMetros, vidaMinAisladorAnios, vidaMinCableAnios}`. Fuente: listas de precio de Odoo |
| POST | `/v1/instalador/ordenes/{id}/reparacion` | `{hilos:[{metros, dificultad}], componentes:{postesEsquina, postesPaso, abanicos, aisladoresSueltos, tensores}, energizador:"ninguno\|simple\|bateria", causaFalla:"evento_externo\|desgaste", resumen:{manoObra, material, total}}` |

## 5. Energizador / dispositivo (reusa `domains/devices`)
| Método | Ruta | Notas |
|---|---|---|
| POST | `/v1/instalador/ordenes/{id}/vincular-energizador` | `{qr}` o `{serial}` → liga el device → `{deviceId}` |

## 6. Cierre
| Método | Ruta | Notas |
|---|---|---|
| POST | `/v1/instalador/ordenes/{id}/evidencias:solicitar-subida` | `{archivos:[{nombre, tipo, tamano}]}` → `[{uploadUrl, fileKey}]` (URLs prefirmadas S3, subida directa PUT) |
| POST | `/v1/instalador/ordenes/{id}/cierre` | `{evidencias:[{fileKey, categoria, geo:{lat,lng,timestamp,mismatch}}], firmaFileKey, entregaEquipo:{controlRemotoEntregado:bool, entregaFuncional:bool, anomalias:[string], comentarios}, comentariosGenerales}` → marca `completo`; escribe a Odoo (pago/factura) + estado en HubSpot |

## 7. Historial
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/historial?rango=&q=&page=&pageSize=` | `rango=semana\|mes\|todo`. Lista de completadas: `[{id, tipo, titulo, cliente, direccion, ciudad, completadoEn}]` |

## 8. Catálogos (estáticos o de Odoo)
| Método | Ruta |
|---|---|
| GET | `/v1/instalador/catalogos/obstaculos-perimetro` |
| GET | `/v1/instalador/catalogos/tipos-anomalia` |

---

## Transversal
- **Espejo/actualizaciones:** webhooks Odoo/HubSpot → API (motor `Sync*` existente) → la app refresca por push/poll.
- **Estados de orden:** `por_hacer → en_curso → completo` (o `cancelado`).
- **Seguridad:** secretos solo en el servidor; la app nunca habla directo con HubSpot/Odoo/S3.

## Preguntas abiertas para Dan
1. ¿Modelamos las órdenes de servicio en **Odoo** (¿módulo Field Service?) o como entidad propia en el backend reflejada por el motor sync?
2. Login de instalador: ¿validación directa contra Odoo, o `User` del API mapeado vía `SyncEntityMap`?
3. Evidencias: ¿URLs prefirmadas de S3 (recomendado) o subida multipart al API?
4. ¿Reusar `domains/devices` tal cual para la vinculación del energizador?
