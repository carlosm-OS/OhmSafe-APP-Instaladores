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
