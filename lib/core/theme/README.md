# Sistema de tema OhmSafe — dirección "Faena"

App de campo para instaladores de cercos eléctricos. Restricción #1: **uso al aire libre con sol directo y a veces con guantes** → alto contraste, áreas táctiles grandes y **bordes en vez de sombras** (bajo sol las sombras se lavan).

## Archivos
| Archivo | Qué contiene |
|---|---|
| `app_palette.dart` | Tokens primitivos de color (light + dark). No usar directo en widgets. |
| `app_theme_extension.dart` | `OhmColors`: tokens semánticos que M3 no tiene (success/warning/info + tiers de superficie + gradiente de marca). Atajo `context.ohm`. |
| `app_dimens.dart` | Espaciado (base-4), radios, bordes, elevación, áreas táctiles. |
| `app_motion.dart` | Duraciones, curvas y `AppMotion.duration(context, …)` que respeta *reducir movimiento*. |
| `app_theme.dart` | `AppTheme.light` / `AppTheme.dark`: ColorScheme de marca + tipografía + temas de componentes. |

## Cómo consumir
```dart
final cs = Theme.of(context).colorScheme;   // primary, surface, error, outline…
final ohm = context.ohm;                     // success, warning, info, gradiente…
Text('Hola', style: Theme.of(context).textTheme.titleLarge);
Container(padding: const EdgeInsets.all(AppSpacing.lg), ...);
```
**Nunca** `Color(0xFF…)` ni tamaños mágicos en widgets: usar tokens.

## Decisiones de "Faena"
- **Naranja de marca reservado a acciones** (`primary`). No pintar superficies grandes de naranja.
- **Tarjetas sin sombra, con borde 1px** (`outlineVariant`).
- **Botón primario 56px**, icon 48px, filas accionables 64px.
- **Foco 2px naranja** en inputs (visible con guantes/sol).
- **Motion funcional**: 200ms `easeOutCubic`; confirmaciones con `easeOutBack` corto.

## Tipografía — ACTIVA: Lexend (títulos) + Inter (cuerpo)
Ambas son **fuentes variables OFL** empaquetadas en `assets/fonts/` (Lexend.ttf, Inter.ttf) — **sin red**, offline-safe. Al ser variables, Flutter mapea `fontWeight` (400–800) al eje `wght`; no hay que declarar pesos por archivo. Licencias en `assets/fonts/OFL-*.txt`.

- Declaradas en `pubspec.yaml` → `flutter: fonts:`.
- Activadas en `app_theme.dart` → `AppTypography.displayFamily = 'Lexend'`, `bodyFamily = 'Inter'`.

**Volver a la fuente del sistema:** poner ambas constantes en `null` (son `String?` a propósito).

Lexend está diseñada para mejorar la fluidez de lectura y baja visión — ideal para exterior. Para actualizar las fuentes, re-descargar los `.ttf` variables del repo oficial `google/fonts` (`ofl/inter`, `ofl/lexend`) y reemplazar en `assets/fonts/`.

## Migración pendiente
`main.dart` ya usa el sistema. Quedan ~25 pantallas con `Color(0xFF…)` hardcodeado; migrarlas a tokens de forma incremental (buscar `Color(0xFF` en `lib/`).
