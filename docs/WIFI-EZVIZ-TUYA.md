# Conectar cámaras EZVIZ a la Wi‑Fi desde la app de instaladores

> Fase 2 del emparejamiento Wi‑Fi (2026-10-17). La fase 1 (backend y dashboard) está en
> `docs/instalador-wifi.md` del repo del backend. Pedido de Carlos: «el instalador entra a la Wi‑Fi
> de la casa y hace el pair de los dispositivos: sensores, cámaras y todo lo Wi‑Fi que no pase por
> el OhmBox». EZVIZ va primero porque no depende de ninguna consola de terceros; Tuya espera a que
> Dan cree la app `com.ohmsafe.instalador` en la plataforma de Tuya (llaves + paquete de seguridad).

## Qué hace

Desde «Agregar dispositivos» → Cámaras → **«Conectar cámara a la Wi‑Fi»**, el instalador escanea la
etiqueta de la cámara, el cliente escribe la contraseña de su Wi‑Fi en el teléfono del instalador, y
la app, con el SDK de EZVIZ y **la cuenta de la casa** (no la del instalador), le pasa la red a la
cámara, espera a que llegue a la nube y la registra en la casa del cliente con el **nombre de la red**.

Reglas (decisiones de Carlos, 2026-10-17):

- La contraseña de la Wi‑Fi **no se guarda** ni viaja al backend: entra en `ConectarCamaraWifiScreen`,
  va a `EzvizPuente.configurarWifi` → SDK, y se borra el campo al terminar. Ni Swift ni Kotlin la
  registran en el log.
- Sí se guarda el **SSID**, la fecha y quién emparejó (`POST …/dispositivos-wifi` con `red`): cuando
  el cliente cambia de módem el equipo se desconecta y soporte necesita decirle a qué red estaba.
- La opción vieja («Agregar cámara» por serie + código) se queda como **«Cámara ya conectada»**: para
  cámaras que ya están en internet (Imou, o conectadas con la app del fabricante).
- La fila nueva sólo aparece si el backend dice `wifi.emparejar.ezviz === true` en
  `GET /instalador/ordenes/:id/dispositivos` (EZVIZ encendido en ese ambiente).

## Piezas

| Pieza | Archivo | Qué hace |
|---|---|---|
| Puente Dart | `lib/core/ezviz/ezviz_puente.dart` | `MethodChannel('ohmsafe/ezviz')` + `EventChannel('ohmsafe/ezviz/events')`: `configure`, `setSession`, `logout`, `probe`, `wifiConfigStart`, `wifiConfigStop`, `currentSsid`. Códigos `EZVIZ_*`. |
| Lógica | `lib/core/ezviz/emparejador_ezviz.dart` | `EmparejadorEzviz` (ChangeNotifier): el orden de pasos de abajo, los plazos y el copy de errores. Probado sin SDK. |
| Pantalla | `lib/screens/conectar_camara_wifi_screen.dart` | Formulario (serie, código, nombre, red, contraseña), progreso con `EsperandoSenal`, cancelar. |
| Etiqueta | `lib/core/utils/etiqueta_ezviz.dart` | Lee el QR de la etiqueta EZVIZ (`<url>\n<serie>\n<código>\n<modelo>`, pares con nombre, query). |
| Escáner | `lib/screens/escanear_serie_screen.dart` | Ahora recibe `leer` e `indicacion` para reutilizarse con otras etiquetas. |
| Datos | `ordenes_*_data_source.dart`, `ordenes_repository*.dart` | `wifiSesion`, `ezvizSondeo`, `dispositivoWifiAgregar`. |
| iOS | `ios/Runner/EzvizPlugin.swift`, `Runner-Bridging-Header.h` | Versión recortada del puente de la app del cliente: sin vídeo ni audio. Modo AP con `NEHotspotConfigurationManager` (el SDK no enlaza NetworkExtension). |
| Android | `android/.../EzvizPlugin.kt` | Ídem; el SDK se une solo al hotspot (`autoConnect=true`, sale el diálogo del sistema). |
| Pruebas | `test/ezviz_wifi_test.dart` | Contrato con el puente (nombres de métodos/argumentos, orden), promesas de seguridad, errores y plazos. |

Los nombres de métodos, eventos, pasos (`joining_hotspot`, `sending_config`, `registered`…) y códigos
son **los mismos** que en la app del cliente (`User-App-`, CONTRACTS §11.15 C): un arreglo en una
se lleva a la otra.

## Orden de pasos (`EmparejadorEzviz.empezar`)

1. `GET /instalador/ordenes/:id/wifi/sesion?proveedor=ezviz` → `appKey`, `areaDomain`, `accessToken`
   de la sub‑cuenta de la casa → `configure` + `setSession` (iOS valida el token con `getDeviceList`).
2. Sondeo: primero el SDK (`probe`, único que distingue «encendida y libre»), si no sabe, el backend
   (`POST …/wifi/ezviz/sondeo`). `bound_elsewhere` → se para con el copy de «otra cuenta».
   `online_unbound`/`bound_here` → ya está en internet, se registra sin tocar la Wi‑Fi.
3. `wifiConfigStart` en modo **AP** (u **onda de sonido** sólo si la cámara no sabe AP). El
   progreso llega por eventos `wifiConfig`. Si el SDK se rinde (`EZVIZ_WIFI_TIMEOUT`) o se calla
   (`topeWifi` + `margenWifi`), se sondea igual: la cámara pudo llegar sola.
4. Sondeo cada 5 s hasta `topeNube` (120 s). `not_found` significa «sigue esperando».
5. `POST …/dispositivos-wifi {proveedor: ezviz, clase: camara, externalId, nombre, codigo, red}`.

## Permisos y capacidades

- **iOS:** `com.apple.developer.networking.wifi-info` y `…HotspotConfiguration` en
  `Runner.entitlements` (capacidades gratuitas del App ID; con firma automática Xcode las activa en
  `com.ohmsafe.instalador` al archivar). `NSLocalNetworkUsageDescription` nuevo; ubicación ampliada
  (leer el SSID exige ubicación «mientras se usa»).
- **Android:** `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `ACCESS/CHANGE_NETWORK_STATE`,
  `CHANGE_WIFI_MULTICAST_STATE`, `NEARBY_WIFI_DEVICES`, `READ_PHONE_STATE` (lo pide el SDK, no se
  pide en tiempo de ejecución). Actividad `com.videogo.main.EzvizWebViewActivity` declarada (el SDK
  la resuelve por nombre). `uses-feature` wifi/telephony/portrait en `required=false` para que Play no
  excluya modelos. Reglas de R8 en `proguard-rules.pro` (el AAR trae un `proguard.txt` vacío y la
  app SÍ minifica).

## Trampas

- **Simulador de Apple silicon.** `EZOpenSDK` sólo trae la slice `ios-arm64`: con el pod enlazado
  la app no compila para el simulador. Para trabajar la interfaz: `OHMSAFE_EZVIZ=0 pod install` en
  `ios/` (el puente contesta `EZVIZ_NOT_LINKED`). Para TestFlight va enlazado por omisión.
- **Emulador x86_64 de Android.** El AAR sólo trae `arm64-v8a`/`armeabi-v7a`: `initLib` revienta y
  el puente contesta `EZVIZ_UNSUPPORTED`. Probar en teléfono.
- **Cámara en 5 GHz.** Las cámaras sólo ven 2.4 GHz. Si el teléfono está en la red de 5 GHz del mismo
  módem, el SSID prellenado puede ser el de 5 GHz: el instalador debe corregirlo.
- **`EZVIZ_APP_KEY`** no está en la app: la manda el backend en la sesión. Dan dijo (2026-10-17) que
  la llave es de la cuenta de desarrollador, no de cada app; si el SDK la rechaza desde
  `com.ohmsafe.instalador`, hay que dar de alta el bundle en la consola de EZVIZ.

## Pendiente

- Probar con una cámara EZVIZ real y una casa de dev (api-dev tiene EZVIZ encendido).
- Tuya (sensores y cámaras Tuya): espera la app de Tuya del instalador y sus llaves (Dan).
- Imou: v1 sigue siendo «Cámara ya conectada» (conectar con Imou Life y registrar aquí).

---

# Sensores y cámaras Tuya: emparejar con el token de la casa (2026-10-17)

Misma idea que EZVIZ, con una diferencia de fondo: **la app del instalador no inicia sesión en
Tuya**. Cada app con SDK de Tuya tiene su propio schema de usuarios y la cuenta de la casa vive en
el de OhmSafe GO; por eso el backend pide a Tuya un **token de emparejamiento** ligado al uid y al
hogar de la casa (`POST /instalador/ordenes/:id/wifi/tuya/token`) y la app sólo se lo transmite al
equipo. El equipo queda en la cuenta de la casa, visible y controlable desde GO; el backend lo ve por
el proyecto de nube. La contraseña Tuya de la casa nunca sale del servidor.

| Pieza | Archivo |
|---|---|
| Puente Dart | `lib/core/tuya/tuya_puente.dart` (`ohmsafe/tuya`: `configure`, `pairStart {mode, ssid, password, token, timeoutS}`, `pairCancel`, `currentSsid`) |
| Lógica | `lib/core/tuya/emparejador_tuya.dart` (token → configure → pairStart → `pairDone` del SDK **o** sondeo del backend `GET …/tuya/token/:token` → alta con la red) |
| Pantalla | `lib/screens/conectar_tuya_wifi_screen.dart` (sensor: puerta/movimiento/humo; cámara; modo Rápido (EZ) o Punto de acceso (AP)) |
| iOS | `ios/Runner/TuyaPlugin.swift` (`ThingSmartActivator.startConfigWiFi(_:ssid:password:token:timeout:)`); pods `ThingSmartHomeKit ~> 7.8.0` + `ThingSmartCryption` (paquete de seguridad fuera del repo) |
| Android | `TuyaPlugin.kt` (común) + `src/tuyaOn|tuyaOff/…/TuyaBridgeFactory.kt` (`ActivatorBuilder().setToken(token)`), `thingsmart:7.8.0` + `security-algorithm*.aar` fuera del repo |
| Pruebas | `test/tuya_wifi_test.dart` |

## Serie de etiqueta y «Equipo conectado» (2026-10-22)

Pedido de Carlos: identificar qué unidad física quedó en la casa. El emparejamiento no necesita la
serie (la nube devuelve el `devId`), pero sin ella no hay rastro para inventario ni garantía, y en
modo rápido podría entrar otro equipo cercano que estuviera en emparejamiento.

- `ConectarTuyaWifiScreen`: campo **«Número de serie (opcional)»** con escáner
  (`EscanearSerieScreen(leer: serieDeEtiqueta)`). `serieDeEtiqueta` (core/utils/serie_qr.dart) acepta
  la serie sola o un enlace con `?sn=` / `serial=` / `serie=` / `uuid=` / `id=` o con la serie al final.
- `EmparejadorTuya.empezar(serie:)` la manda en `POST …/dispositivos-wifi` como `serie` **sólo si hay**:
  el esquema del backend es estricto y uno sin Back-#156 rechazaría el campo. **Desplegar el backend antes
  que la app.**
- Al terminar, en vez de un aviso y salir, la pantalla muestra la tarjeta **«Equipo conectado»**: qué es,
  modelo (nombre de fábrica que da la nube), serie, ID del equipo (`devId`) y red. «Listo» sale;
  «No es este equipo» explica que hay que avisar a operaciones con el ID.
- Backend: columna `serial_number` en `wifi_sensors` y `cameras`, `pairing.serial` en los DTO, acta y
  reporte de servicio. Dashboard: «· serie …» en la línea del equipo (Dashboard-#16).
- Pruebas: `test/tuya_wifi_test.dart`.

## Selector de redes Wi‑Fi (2026-10-20)

`lib/widgets/campo_red_wifi.dart` (`CampoRedWifi`) + `lib/core/wifi/redes_wifi.dart`, recorte del
`wifi_networks.dart` de GO. Android escanea con `wifi_scan` (exige ubicación; el manifiesto ya no
lleva `neverForLocation` en `NEARBY_WIFI_DEVICES`, igual que GO): hoja con las redes cercanas, 2.4 GHz
primero y por señal, 5/6 GHz apagadas; la misma SSID en dos bandas se queda con la de 2.4. iOS no
puede listar redes (Apple no da la API): el campo relee la red conectada al volver al frente
(`didChangeAppLifecycleState`) y con el icono. `bandaPorNombre` avisa (no bloquea) cuando el nombre
huele a 5 GHz. Android frena a 4 escaneos / 2 min: se leen los resultados en caché. Pruebas en
`test/redes_wifi_test.dart` con un `ListadorRedes` falso.

## Llaves y paquetes (nunca en git)

- Cuenta de Tuya de OhmSafe (`admin@ohmsafe.com`): app «OhmSafe Installer» (Smart Life App SDK 7.8.0,
  `com.ohmsafe.instalador`). Cada plataforma tiene su propio AppKey/AppSecret.
- `~/dev/ohmsafe/keys/tuya-instalador/`: `ios/ios_core_sdk/` (pod `ThingSmartCryption` con `t_s.bmp`),
  `android/sec/security-algorithm-*.aar`, y `tuya-defines.json` con `TUYA_IOS_APP_KEY`,
  `TUYA_IOS_APP_SECRET`, `TUYA_ANDROID_APP_KEY`, `TUYA_ANDROID_APP_SECRET`.
- Build: `flutter build … --dart-define-from-file=$HOME/dev/ohmsafe/keys/tuya-instalador/tuya-defines.json`.
  Sin el archivo la app compila y la pantalla dice «Esta versión no puede emparejar equipos Tuya».
- `OHMSAFE_TUYA=0` (pod install / gradle) deja el SDK fuera (puente `TUYA_NOT_LINKED`); hace falta
  para el simulador de Apple silicon, igual que EZVIZ.

## Trampas

- El SDK sin sesión puede no avisar `pairDone` (sondea la nube con la sesión del usuario): por eso el
  emparejador también pregunta al backend cada 5 s y un `pairError` del SDK no tumba el intento.
- Sin uid Tuya de la casa el backend contesta 409 `TUYA_UID_DESCONOCIDO`: el cliente debe entrar una
  vez a GO (GO reporta el uid al guardar el hogar) o el servidor necesita `TUYA_APP_SCHEMA`.
- **Android con AGP 9:** varios AAR del SDK 7.8.0 comparten el namespace `com.thingclips.sdk.devicecore`
  y AGP 9 lo trata como error; `android/gradle.properties` lleva `android.uniquePackageNames=false`.
- **iOS con Tuya + EZVIZ:** los dos traen su propio OpenSSL/mbedTLS; el Podfile mueve
  `EZOpenSDKFramework` al final del enlazado (`ohmsafe_fix_crypto_link_order`, copiado de la app del
  cliente) para que Tuya no llame a un OpenSSL ajeno.
- Pendiente de probar con un sensor real: GO aún no existe en la cuenta nueva de Tuya (el bundle
  `com.ohmSafe` sigue en la cuenta de Dan).

---

# Retirada de EZVIZ e Imou de la app de instaladores (2026-10-20)

**Decisión de Carlos (20-oct):** la app de instaladores ofrece **sólo Tuya**. Motivo: varias marcas
complican tablas, procesos y peso, y el SDK de Imou nunca llegó a conectarse. Modo: **apagar, no
borrar** — el código, los puentes nativos y los SDKs siguen en el repo; lo que cambia es un
interruptor en la app. En GO y en el backend la retirada la lleva la sesión OS‑Product
(`docs/IMOU-RETIRADO.md` del backend; `IMOU_ENABLED=false`); EZVIZ sigue en el backend por ahora.

## Interruptor

`lib/core/config/marcas_camara.dart` → `MarcasCamara.habilitadas`, por omisión `{tuya}`; se compila
con `--dart-define=MARCAS_CAMARA=tuya,ezviz,imou` para reabrir marcas. Lo que apaga:

| Con la marca apagada | Qué pasa |
|---|---|
| EZVIZ | No aparece «Conectar cámara a la Wi‑Fi» aunque el backend diga `wifi.emparejar.ezviz`. |
| Imou | No aparece «Conectar cámara Imou». |
| EZVIZ e Imou | No aparece «Cámara ya conectada» (registro por serie + código); las Tuya se registran al emparejarlas. Las ayudas de la sección Cámaras no mencionan la marca. |
| (siempre) | Las cámaras y sensores YA registrados de cualquier marca se siguen listando con su marca. |

No se tocan: `ConectarCamaraWifiScreen`, `ConectarImouScreen`, `EmparejadorEzviz`, `EzvizPuente`,
`EzvizPlugin.swift/.kt`. Las pruebas de esas pantallas encienden todas las marcas en `setUp`.

## El SDK de EZVIZ sale de la build (peso)

Igual que en GO: el SDK de EZVIZ (unos 40 MB de librerías nativas) queda **fuera por omisión**, sin
borrar nada.

| Plataforma | Por omisión | Para reincorporarlo |
|---|---|---|
| iOS | `Podfile`: `OHMSAFE_EZVIZ_LINKED = ENV['OHMSAFE_EZVIZ'] == '1'` → sin `EZOpenSDK`; `EzvizPlugin.swift` ya compila sin el módulo (`#if canImport`) y contesta `EZVIZ_NOT_LINKED`. | `OHMSAFE_EZVIZ=1 pod install` |
| Android | `android/build.gradle.kts`: `ohmsafeEzvizLinked` → sin `ezviz-sdk`, okhttp ni gson; se compila `src/ezvizOff` (stub `EZVIZ_NOT_LINKED`, `currentSsid` sigue funcionando). La implementación real está en `src/ezvizOn/…/EzvizBridgeFactory.kt` (patrón de Tuya). | `-PohmsafeEzviz=true` (o `ORG_GRADLE_PROJECT_ohmsafeEzviz=true`) u `OHMSAFE_EZVIZ=1` |

La actividad `com.videogo.main.EzvizWebViewActivity` sigue declarada en el manifiesto y las reglas
de R8 de `com.videogo.**` en `proguard-rules.pro`: sin el SDK no hacen nada y así la reincorporación
es sólo volver a enlazar. Para una build con EZVIZ hace falta además `MARCAS_CAMARA` con `ezviz`.

## Lo que queda guardado para reincorporar Imou

- **SDK de Imou en la app (build 52, detenida):** rama `CarlosClaudDev-imou-sdk` y PR #4 (borrador,
  «NO fusionar») de `carlosm-OS/OhmSafe-APP-Instaladores`: puente `ohmsafe/imou` (Dart + Kotlin,
  `src/imouOn|imouOff`), `EmparejadorImou`, `conectar_imou_wifi_screen.dart` (modos rápido y por
  hotspot), repo `imouSesion/imouSondeo`, pruebas, docs. El AAR vive en `~/dev/ohmsafe/keys/imou-sdk/`
  (Android y el framework de iOS), fuera de git. iOS nunca se integró.
- **Backend:** `POST …/wifi/imou/sesion` y `…/sondeo` (Back-#133) quedan en main; se apagan con
  `IMOU_ENABLED=false` y contestan 503 `PROVIDER_NOT_CONFIGURED`.
- **Apple:** solicitud del entitlement *Multicast Networking* **QN7AHWA6RR** (20-oct, cuenta Ohm Safe)
  para `com.ohmsafe.instalador`. Si Apple lo aprueba, sólo sirve si Imou vuelve.
- **Cuenta Imou institucional** (`admin@ohmsafe.com`, AppId `lc4b2fe6…`) sigue existiendo; las llaves
  quedan en api-dev/prod aunque `IMOU_ENABLED` esté apagado.

Para volver: fusionar `CarlosClaudDev-imou-sdk` sobre `dev`, compilar con `MARCAS_CAMARA` incluyendo
`imou`, encender `IMOU_ENABLED` en el backend y repetir la prueba con una cámara real.

## Paso «Wi‑Fi de la casa» (2026-10-22)

Pedido de Carlos: un paso antes de «Agregar dispositivos» para capturar la Wi‑Fi de la casa una
vez, que se puede omitir y al que se puede volver. Contraseña: **opción A, sólo en el teléfono**.

- `WifiCasaScreen` (paso 4; «Agregar dispositivos» pasa a 5 y el cierre a 6). Guarda en el servidor
  sólo el nombre (`PUT …/wifi-casa`, Back-#157) y la contraseña en `WifiCasaLocal` (llavero del
  teléfono, por intervención, vence a las 24 h y se borra al «Terminar instalación»).
- La lista de pasos habilita «Agregar dispositivos» y el cierre cuando el paso queda listo u omitido.
- «Agregar dispositivos» muestra arriba la sección «WI‑FI DE LA CASA» (Agregar / Cambiar → vuelve al
  paso) y, con OhmBox, la fila «Segunda conexión por Wi‑Fi» (`POST …/ohmbox/wifi`); al vincular un
  OhmBox con Wi‑Fi ya capturada la app ofrece conectarlo.
- `ConectarTuyaWifiScreen` precarga red y contraseña desde `WifiCasaLocal`.
- Pruebas: `test/wifi_casa_test.dart`.

## Bluetooth (2026-10-22)

Lo tenía Dan en GO (escaneo BLE → activación multimodo, luego EZ, luego AP). En Installer se adaptó
al **token de la casa que da el backend** (sin sesión en Tuya):

- Dart: `TuyaPuente.buscarBluetooth` (`bleScanStart`), `detenerBusqueda` (`bleScanStop`),
  `emparejarBluetooth` (`pairStartBle {uuid, productId, ssid, password, token, homeId}`); eventos
  `bleFound {uuid, combo…}` y `bleScanEnd`. `EmparejadorTuya` con modo `BLE`: pide el token con
  `modo: BLE`, busca 20 s, empareja el primer equipo **combo** (Bluetooth + Wi‑Fi) y, si no hay permiso,
  no aparece ninguno o el SDK no arranca, pide un token `EZ` y sigue en modo rápido (`modoUsado`).
- Android (`src/tuyaOn`): `ThingHomeSdk.getBleOperator().startLeScan` + `newMultiModeActivator()` con
  `MultiModeActivatorBean.token` = token de la casa. Manifiesto: BLUETOOTH (≤30), BLUETOOTH_SCAN
  (`neverForLocation`), BLUETOOTH_CONNECT; permisos en tiempo de ejecución con `permission_handler`.
- iOS: `ThingSmartBLEManager` para buscar y `ThingSmartBLEWifiActivator.pairDevice(withUUID:token:ssid:pwd:timeout:)`
  (la variante con token; la de GO usa la sesión). `NSBluetoothAlwaysUsageDescription` ya estaba.
- Sin probar con hardware: los equipos sólo Bluetooth (no combo) se ignoran; los Wi‑Fi sin Bluetooth
  caen al modo rápido.
- Pruebas: `test/tuya_wifi_test.dart` (combo encontrado, respaldo a rápido, sin permiso).

## Modo punto de acceso con pausa y sondeo largo (2026-10-22, caso de Nahum en i77)

Evidencia: cámara GN-PT307-W600 en modo AP; tokens EZ (imposible) y AP que sondearon 50–85 s y nunca
llegó el alta. Cambios en la app (build 58):

1. **Pausa AP:** `EmparejadorTuya` pide el token AP con internet de la casa y queda en
   `EtapaTuya.esperandoRedEquipo`; la pantalla muestra «Conecta el teléfono a la red del equipo» con
   «Abrir ajustes de Wi‑Fi» (`openWifiSettings`: Android `ACTION_WIFI_SETTINGS`; iOS ajustes de la app).
   `continuarAP()` revisa `currentSsid` (`esRedDeEquipo`: prefijo `smartlife`) y entonces arranca el SDK;
   al volver a la app (`AppLifecycleState.resumed`) se llama sola; «Seguir de todos modos» la fuerza.
   Si el token está por vencer (< 45 s) pide empezar de nuevo.
2. **Sondeo:** `_plazoSondeo()` dura hasta `expiresAt` del token (≈5 min), nunca menos que el tope del SDK.
3. **Sugerir modo:** en Android, si el escaneo ve una red del equipo, la pantalla elige «Punto de acceso»
   (salvo que el instalador ya haya tocado el selector) y lo explica con el nombre de esa red.

Pendiente: conectar desde la app con `WifiNetworkSpecifier` (Android 10+) y el modo QR.
