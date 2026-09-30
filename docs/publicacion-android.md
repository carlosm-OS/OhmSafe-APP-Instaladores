# Publicación en Google Play — OhmSafe Installer (Android)

`applicationId` **com.ohmsafe.instalador** · nombre visible **OhmSafe Installer** (igual que en TestFlight) ·
Firebase `ohmsafe-instaladores` (`android/app/google-services.json`, ya en el repo).

## Qué quedó configurado en el repo (2026-09-30)

| Pieza | Dónde | Nota |
|---|---|---|
| Nombre y permisos | `android/app/src/main/AndroidManifest.xml` | `OhmSafe Installer`; ubicación **sólo en uso** (fina/aproximada), cámara, internet, biometría. Sin ubicación en segundo plano, sin SMS. |
| Firma de release | `android/app/build.gradle.kts` | Lee `android/key.properties` (fuera de git). Sin ese archivo firma con debug para que `flutter run --release` siga sirviendo. R8 + shrink activados, `proguard-rules.pro`. |
| Iconos | `pubspec.yaml` → `flutter_launcher_icons` | Adaptive icon: fondo = degradado del ícono maestro sin arte (`assets/icon/android_adaptive_bg.png`), frente = arte blanco recortado a la zona segura (`assets/icon/android_adaptive_fg.png`). Regenerar: `dart run flutter_launcher_icons`. |
| Versión | `pubspec.yaml` `version: 1.0.0+N` | `N` = `versionCode`. Play exige que suba en cada subida. Se comparte con TestFlight (mismo N). |

Regenerar las capas del ícono desde el maestro de iOS (ImageMagick, `brew install imagemagick`):

```bash
SRC="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
magick "$SRC" -fuzz 14% -transparent "#151C25" -trim +repage -resize 690x690 -gravity center -background none -extent 1024x1024 assets/icon/android_adaptive_fg.png
magick "$SRC" -fuzz 30% -fill "#161E28" -opaque white -blur 0x48 assets/icon/android_adaptive_bg.png
dart run flutter_launcher_icons
```

## Llave de subida (upload key) — dónde vive y cómo NO perderla

Google Play firma lo que instalan los usuarios con **Play App Signing** (la llave la guarda Google). Nosotros sólo
firmamos el bundle con una **llave de subida**; si se pierde, se pide un reemplazo en Play Console sin perder la app.

- Keystore: `~/dev/ohmsafe/keys/ohmsafe-instalador-upload.jks` (alias `upload`, RSA 2048, válida hasta 2054, `chmod 600`,
  carpeta fuera de iCloud y fuera de cualquier repo).
- Contraseña (misma para keystore y llave): **sólo en el Llavero de macOS**, servicio `ohmsafe-instalador-upload-key`,
  cuenta `carlos`. Nunca se imprime ni se pega en un chat. Para leerla en un script:
  `security find-generic-password -a carlos -s ohmsafe-instalador-upload-key -w`.
- Huella SHA-256 de la llave de subida (pública, sirve para registrarla en Play si algún día se reemplaza):
  `CD:13:45:CF:EB:E9:C4:9C:D8:03:B2:CB:D2:B2:DE:CD:EF:B3:0F:A4:AC:FB:BD:0E:95:15:88:00:05:04:71:D0`.
- Respaldo: exportar el `.jks` + la contraseña al gestor de contraseñas de la empresa (bóveda compartida), no a iCloud Drive.
- `android/key.properties` (contiene la contraseña) existe **sólo en la copia de build** `~/dev/ohmsafe/Installer-Build/android/`.
  Está en `.gitignore` y el `rsync` de la receta lo excluye para no borrarlo.

## Cadena de herramientas en la Mac (sin sudo)

- JDK: `brew install openjdk@21` → `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
  (el cask `temurin` pide contraseña de administrador; no hace falta).
- SDK: `brew install --cask android-commandlinetools` y luego
  `sdkmanager --sdk_root=$HOME/Library/Android/sdk --install "platform-tools" "platforms;android-36" "build-tools;36.0.0" "cmdline-tools;latest"`,
  `yes | sdkmanager --licenses`, `flutter config --android-sdk $HOME/Library/Android/sdk --jdk-dir $JAVA_HOME`,
  `yes | flutter doctor --android-licenses`.
- No hace falta Android Studio ni emulador para publicar.

## Receta de build (bundle .aab)

Se compila en la copia fuera de iCloud, igual que iOS. La fuente se edita y commitea en iCloud.

```bash
SRC="/Users/carlos/Library/Mobile Documents/com~apple~CloudDocs/02-OhmSafe/OhmSafe-APP-Instaladores"
cd ~/dev/ohmsafe/Installer-Build
rsync -a --delete --exclude build/ --exclude ios/Pods/ --exclude .git/ --exclude .dart_tool/ \
      --exclude android/key.properties --exclude android/.gradle/ "$SRC/" ./
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
flutter pub get
# Pruebas internas (misma API que TestFlight):
flutter build appbundle --release --dart-define=API_BASE_URL=https://api-dev.dashboard.ohmsafe.com/v1 --dart-define=APP_ENV=testflight
# Producción (tienda):
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.ohmsafe.com/v1 --dart-define=APP_ENV=production
# Resultado: build/app/outputs/bundle/release/app-release.aab
```

Verificar la firma antes de subir: `$JAVA_HOME/bin/jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | tail -3`
(debe decir `jar verified` y el certificado `CN=OhmSafe Installer`).

## Pistas de Google Play (equivalente de TestFlight)

1. **Pruebas internas** (Internal testing): hasta 100 probadores por correo, sin revisión de Google, disponible en minutos.
   Es el equivalente de TestFlight interno. Cada probador recibe un enlace de invitación y descarga desde Play.
2. **Pruebas cerradas**: listas más grandes; la primera versión pasa revisión.
3. **Producción**: revisión completa (horas a días). Las cuentas de organización no tienen el requisito de
   «12 probadores durante 14 días» que aplica a cuentas personales nuevas.

Al crear la app en Play Console: nombre `OhmSafe Installer`, idioma predeterminado español (México), tipo App,
gratuita. Al subir el primer bundle, aceptar **Play App Signing** (predeterminado). Después, en
*Configuración › Integridad de la app* aparecen las huellas de la llave de firma de Play (no hacen falta para FCM).

## Declaraciones obligatorias en Play Console (Contenido de la app)

| Declaración | Respuesta para esta app |
|---|---|
| Política de privacidad | `https://ohmsafe.com/politicas-de-privacidad-ohmsafe-1` (existente; conviene que mencione ubicación y fotos del técnico). |
| Acceso a la app | Requiere inicio de sesión: dar instrucciones y una **cuenta de revisión** (instalador de prueba con contraseña propia, nunca la de una persona real). |
| Anuncios | No contiene anuncios. |
| Clasificación de contenido | Cuestionario IARC: utilidad/productividad, sin contenido sensible → Todos. |
| Público objetivo | Mayores de 18 (herramienta de trabajo). No dirigida a niños. |
| Apps de noticias / COVID / gobierno / salud / financieras | No. |
| Seguridad de los datos | Recopila: **ubicación precisa** (en uso: llegada, cancelación y cierre; no se comparte), **fotos** (evidencia y firma, subidas al backend), **datos personales** del técnico (nombre, correo, teléfono: gestión de cuenta), **IDs del dispositivo** (token de push). Todo cifrado en tránsito (HTTPS). Eliminación: a solicitud por correo a SAC (Play pide una URL o correo de solicitud de eliminación; las cuentas las crea OhmSafe, no hay registro en la app). |
| Permisos sensibles | Ninguno que requiera formulario (no hay ubicación en segundo plano, SMS ni registro de llamadas). |

## Ficha de la tienda (para producción)

Textos propuestos en `docs/play-store-ficha.md`. Recursos gráficos obligatorios: ícono 512×512 (exportar del maestro),
gráfico de funciones 1024×500, mínimo 2 capturas de teléfono (16:9 o 9:16, 320–3840 px). Las capturas se toman del
simulador/emulador con datos de prueba (sin clientes reales).

## Decisiones pendientes de Carlos

- Cuenta de Google Play Console: con qué cuenta de Google se entra (la que administra OhmSafe GO) y quién crea la app.
- Pista inicial: pruebas internas ahora (recomendado) y producción cuando se decida lo mismo que en iOS (pública u oculta;
  en Play no existe «oculta»: la alternativa es pruebas cerradas por lista o distribución gestionada por organización).
- Correo/URL para solicitudes de eliminación de datos y actualización de la política de privacidad.
- Cuenta de revisión para Google (instalador ficticio en Odoo con su contraseña).

## Bitácora — 2026-09-30: app creada y en pruebas internas

- Play Console: cuenta de organización **OhmSafe** (ID 7392211266474143372). Quien opera es la cuenta Google
  **devandroid@ohmsafe.com** (`/u/6/` en el navegador de Carlos); `carlos.mucinor@gmail.com` sólo tiene lectura.
- App creada: **OhmSafe Installer**, id de app en Play `4973298632574825440`, paquete `com.ohmsafe.instalador`,
  es-419, gratuita. Play App Signing aceptado al subir el primer bundle.
- **Pruebas internas ACTIVAS** con la versión 20 (1.0.0), sin revisión (19 MB de descarga). Lista de probadores
  «Instaladores OhmSafe»: castillonahum91@gmail.com, gea.santiago@gmail.com. Enlace para unirse:
  https://play.google.com/apps/internaltest/4701450879635723831 (la lista «Testers internos» de 13 personas es la de
  OhmSafe GO y NO se seleccionó).
- Declaraciones de contenido completadas (todas): privacidad (URL de ohmsafe.com), sin anuncios, detalles de acceso
  (cuadrilla1@ohmsafe.com; la contraseña la tecleó Carlos), público 18+, sin ID de publicidad (verificado en el
  manifiesto compilado: no hay `AD_ID`), seguridad de los datos (ubicación precisa, nombre, correo, teléfono, fotos,
  ID de dispositivo; cifrado en tránsito; necesarios; funciones de la app; sin compartir; cuentas creadas fuera de la
  app como cuentas de trabajo; **método de borrado = No** hasta tener una página web con los pasos), no gubernamental,
  sin funciones financieras, sin funciones de salud, clasificación IARC «Todas las edades» (Carlos aceptó los
  términos IARC; contacto devandroid@ohmsafe.com).
- Trampas de Play Console con el navegador automatizado: los botones «Comenzar declaración» del resumen no
  responden al clic por referencia, sólo por coordenada; en los diálogos de Seguridad de los datos el **primer clic
  tras abrir se pierde**; el cuestionario IARC vuelve al paso 1 (casilla de términos sin marcar) cada vez que se
  entra aunque las respuestas se conserven.
- Pendiente para producción: ficha de la tienda (textos de `docs/play-store-ficha.md`, capturas), países, y crear
  la página de solicitud de borrado de datos en ohmsafe.com para actualizar Seguridad de los datos.
- 2026-09-30 (tarde): **versión 21 (1.0.0)** publicada en pruebas internas con el ícono definitivo (círculo azul marino
  plano `#171F29`, diseño de Carlos; capas en `assets/icon/`, vista previa en `store/android/preview-iconos.png`).
  Es la «Versión más reciente» de la pista; la 20 quedó en el historial.
