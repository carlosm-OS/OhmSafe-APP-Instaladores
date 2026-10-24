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
- **Movimiento de GO (2026-10-20)**: `lib/widgets/movimiento.dart` — `Presionable` (escala 0.96 al presionar, 100 ms), `CambioSuave` (cambio de contenido: fundido + 3 % desde la derecha, 220 ms, entra `easeOutCubic` / sale `easeInCubic`), `EntradaSuave` (filas y tarjetas: fundido + sube 8 px, 260 ms, escalonado 40 ms por índice); y `OhmPageTransitionsBuilder` en `app_motion.dart` registrado en el tema para TODAS las pantallas (fundido + 3 % desde la derecha). Todo colapsa a cero con «Reducir movimiento».

## Tipografía — Sistema v2 (2026-10-23): Inter estática + InterDisplay
- Archivos ESTÁTICOS por peso en `assets/fonts/` (Inter-Regular/Medium/SemiBold/Bold e InterDisplay-SemiBold/Bold), de la versión oficial 4.0 de rsms/inter (licencia en `OFL-Inter.txt`). Se declaran con `weight:` en `pubspec.yaml`.
- Por qué: la Inter variable anterior venía cortada (tabla `gvar` truncada) y en iPhone no engrosaba; por eso las pantallas fijaban la letra a mano.
- Escala: 34/30/28/26/22/20 títulos (InterDisplay, espaciado negativo), 17 cuerpo y filas, 15 apoyo, 13 notas, 12 etiquetas.
- Lexend se retiró.

## Migración pendiente
`main.dart` ya usa el sistema. Quedan ~25 pantallas con `Color(0xFF…)` hardcodeado; migrarlas a tokens de forma incremental (buscar `Color(0xFF` en `lib/`).
