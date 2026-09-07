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

## Tipografía
Por defecto usa la **fuente del sistema** (SF Pro / Roboto): legible y **sin red** (crítico offline en campo).

Para activar el par premium recomendado **Lexend (títulos) + Inter (cuerpo)**:
1. Copiar los `.ttf` a `assets/fonts/` (Lexend-Bold/ExtraBold, Inter-Regular/Medium/SemiBold/Bold).
2. Declararlos en `pubspec.yaml`:
   ```yaml
   fonts:
     - family: Lexend
       fonts: [{asset: assets/fonts/Lexend-Bold.ttf, weight: 700}, {asset: assets/fonts/Lexend-ExtraBold.ttf, weight: 800}]
     - family: Inter
       fonts: [{asset: assets/fonts/Inter-Regular.ttf}, {asset: assets/fonts/Inter-Medium.ttf, weight: 500}, {asset: assets/fonts/Inter-SemiBold.ttf, weight: 600}, {asset: assets/fonts/Inter-Bold.ttf, weight: 700}]
   ```
3. En `app_theme.dart` → `AppTypography`: `displayFamily = 'Lexend'`, `bodyFamily = 'Inter'`.

Lexend está diseñada para mejorar la fluidez de lectura y baja visión — ideal para exterior.

## Migración pendiente
`main.dart` ya usa el sistema. Quedan ~25 pantallas con `Color(0xFF…)` hardcodeado; migrarlas a tokens de forma incremental (buscar `Color(0xFF` en `lib/`).
