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
| POST | `/v1/instalador/auth/login` | `{email, password}` | `{accessToken, refreshToken, instalador:{id, nombre, numeroInstalador, rol}}` |
| POST | `/v1/instalador/auth/refresh` | `{refreshToken}` | `{accessToken, refreshToken}` |
| POST | `/v1/instalador/auth/logout` | — | `204` |

## 2. Perfil (bidireccional con Odoo)
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/perfil` | `{id, nombre, numeroInstalador, rol, calificacion, codigoVentas, avatarUrl, telefono, email, curp}` |
| PUT | `/v1/instalador/perfil` | datos generales (nombre, telefono, email, curp) |
| GET/PUT | `/v1/instalador/datos-bancarios` | `{titular, clabe, banco, cuenta}` |
| GET/PUT | `/v1/instalador/facturacion` | datos fiscales |

## 3. Órdenes de servicio (dominio nuevo `field-service`)
| Método | Ruta | Notas |
|---|---|---|
| GET | `/v1/instalador/ordenes?tipo=&estado=&dia=` | `tipo=instalacion\|reparacion\|mantenimiento`; `estado=por_hacer\|en_curso\|completo\|cancelado`. Lista: `[{id, tipo, titulo, estado, urgente, cliente, direccion, ciudad, cp, telefono, metraje, fechaCreacion, diasAbierto}]` |
| GET | `/v1/instalador/ordenes/{id}` | detalle + `registroInstalacion:{perimetroMetros, lineasInstaladas, postesEsquinaInstalados, postesPasoInstalados, abanicosInstalados, aisladoresPorPoste, edadCercaAnios}` + `pasosCompletados:[...]` |
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
