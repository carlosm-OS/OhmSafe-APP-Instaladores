# Arquitectura de la app (contract-first)

La app usa **clean architecture por feature** para poder desarrollar contra
datos Mock y luego enchufar el backend real sin reescribir UI.

## Capas
- `lib/features/<feature>/domain/` — entidades + interfaz de repositorio.
- `lib/features/<feature>/data/` — modelos (fromJson), datasources (Mock + Api) y `RepositoryImpl`.
- `lib/core/` — `EnvConfig`, DI (`sl`), `DioClient`, `Result`/`Failure`.

## Switch Mock ↔ Api
`EnvConfig.useMock` (en `lib/main.dart`) decide qué datasource inyecta la DI:
- `true` → datasources Mock (la app corre 100% sin backend).
- `false` → datasources Api (`DioClient` contra `apiBaseUrl`, según el contrato en `CONTRATO-API-instalador.md`).

Enchufar el backend real = cambiar `useMock: false` + rellenar los `*RemoteDataSource`. La UI no cambia.

## Features actuales
- **auth** — login del instalador (entrada por `LoginScreen`). Mock acepta cualquier credencial no vacía; en modo Api valida contra Odoo vía `POST /instalador/auth/login`. El `accessToken` de la sesión se inyecta como `Authorization: Bearer` en `DioClient.setAuthToken` tras el login.
- **ordenes** — órdenes de servicio. Lectura: Reparaciones e Instalaciones consumen el repo. Escritura (todas cableadas a sus sub-pantallas): `iniciarRuta` (lista), `marcarLlegada` (RouteDetails), `guardarInspeccion` (PerimeterInspection), `guardarReparacion` (Reparacion), `vincularEnergizador` (LinkEnergizer, manda la MAC), `guardarCierre` (Cierre). Cada acción muestra un SnackBar y NO avanza el paso si el backend falla.
- **tarifas (calculadora de reparación dinámica)** — `getTarifas()` en el repo baja los precios vivos de Odoo (`GET /instalador/tarifas-reparacion`). `ReparacionScreen` los pide en `initState` y calcula con la entidad `Tarifas` (mano de obra, material y factores de dificultad); `repair_pricing.dart` queda solo como respaldo (`Tarifas.defaults()`) si el backend no responde. Editar un precio de producto en Odoo cambia el costeo en la siguiente apertura de la pantalla.

## Manejo de errores (red vs credenciales)
`DioClient` distingue: 401 → `UnauthorizedException` → `AuthFailure` ("Correo o contraseña incorrectos" en login / "Sesión expirada" en lecturas); otros HTTP>=400 → `ServerException`/`ServerFailure` (usa el `message` del backend); fallo real de socket → `NetworkException`/`NetworkFailure` ("Sin conexión a internet"). Antes un 401 se veía como "sin conexión"; ya no.

## Correr contra el backend local (macOS)
El repo vive en iCloud, que rompe la firma iOS. Camino que funciona: `flutter build macos --debug` (falla el codesign por "resource fork" de iCloud) → copiar el `.app` fuera de iCloud → `xattr -cr` → `codesign --force --deep --sign - --entitlements macos/Runner/DebugProfile.entitlements` → `open`. Requiere `com.apple.security.network.client` (ya agregado) y ATS `NSAllowsLocalNetworking` (ya en Info.plist) para hablar con `http://localhost:3001`. Web no sirve (DioClient usa `dart:io`).

## Pendiente al conectar backend real
- Persistir/renovar `refreshToken` (hoy el backend lo emite pero no lo persiste).
- Evidencias/firma reales por S3 (URLs prefirmadas); hoy se mandan fileKeys simuladas.
- Migrar perfil y datos bancarios/fiscales al mismo patrón repo.
