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
- **auth** — login del instalador (entrada por `LoginScreen`). Mock acepta cualquier credencial no vacía.
- **ordenes** — órdenes de servicio (Reparaciones ya consume el repo; Instalaciones pendiente de migrar).

## Pendiente al conectar backend real
- Inyectar el `accessToken` de la sesión como header `Authorization` (interceptor en `DioClient`), en vez del default actual.
- Migrar Instalaciones, perfil, cierre y tarifas al mismo patrón.
