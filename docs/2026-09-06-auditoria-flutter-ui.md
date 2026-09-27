# Auditoría Flutter UI — OhmSafe App Instaladores

- **Fecha:** 2026-09-06
- **Commit auditado:** `351c49d` (main)
- **Herramienta:** `flutter_ui_audit.py` del skill `flutter-ui` (repo Naimehossein77/claude-flutter-ui-skills), instalado en `~/.claude/skills/flutter-ui/scripts/`
- **Alcance:** 38 ficheros Dart en `lib/`

Cómo repetirla:

```bash
python3 ~/.claude/skills/flutter-ui/scripts/flutter_ui_audit.py .
```

## Resumen

| Severidad | Hallazgos |
|---|---|
| 🔴 Críticos | 8 |
| 🟡 Avisos | 447 |
| 🟢 Info | 16 |

| Regla | Conteo | Qué significa |
|---|---|---|
| `PERF_HARDCODED_COLOR` | 231 | `Color(0x…)` suelto; rompe tema y modo oscuro |
| `PERF_HARDCODED_FONT_SIZE` | 216 | `fontSize` fijo; rompe accesibilidad y escalado de texto |
| `PERF_LIST_VIEW_CHILDREN` | 8 | `ListView(children: […])` renderiza todo de golpe; usar `ListView.builder` |

**Gestor de estado detectado: ninguno.** El script no encuentra Riverpod ni Provider. El skill `flutter-ui` exige uno de los dos, así que es la primera decisión de arquitectura antes de rediseñar pantallas.

## Críticos (8)

Todos son `ListView` con hijos fijos:

| Fichero | Línea |
|---|---|
| `lib/screens/home_screen.dart` | 112 |
| `lib/screens/route_details_screen.dart` | 126 |
| `lib/screens/link_energizer_screen.dart` | 250, 581 |
| `lib/screens/perimeter_inspection_screen.dart` | 161 |
| `lib/screens/fence_installation_screen.dart` | 141 |
| `lib/screens/service_steps_screen.dart` | 455 |
| `lib/widgets/simulation_drawer.dart` | 114 |

## Estado visual actual (base para la dirección de diseño)

- Solo `lib/main.dart` define un `ThemeData`; no hay `ThemeExtension` ni tokens.
- Tipografía: `fontFamily: 'System'` en 6 sitios, sin par tipográfico definido.
- Colores más repetidos (hardcodeados):

| Color | Usos | Rol aparente |
|---|---|---|
| `#FF5A00` | 71 | naranja primario OhmSafe |
| `#1E293B` | 47 | slate oscuro, textos |
| `#334155` | 18 | slate medio |
| `#94A3B8` | 17 | slate claro, secundarios |
| `#E2E8F0` | 15 | bordes/superficies |
| `#FF8D28` | 12 | naranja secundario |
| `#F1F5F9` / `#F8FAFC` / `#F5F6F8` | 31 | fondos claros |
| `#7E92A9` / `#64748B` | 19 | grises de apoyo |
| `#166534` | 7 | verde éxito |

- Assets: `avatar.png`, `logo_light.png`, `logo_white.png`. Dependencias UI: solo `cupertino_icons`; sin Lottie ni Rive.

## Ficheros con más hallazgos

| Fichero | Hallazgos |
|---|---|
| `lib/screens/cierre_instalacion_screen.dart` | 63 |
| `lib/screens/link_energizer_screen.dart` | 52 |
| `lib/screens/service_steps_screen.dart` | 50 |
| `lib/screens/instalaciones_screen.dart` | 36 |
| `lib/screens/contrasenas_screen.dart` | 30 |
| `lib/screens/perimeter_inspection_screen.dart` | 24 |
| `lib/screens/facturacion_screen.dart` | 22 |
| `lib/screens/profile_main_screen.dart` | 21 |
| `lib/screens/route_details_screen.dart` | 19 |
| `lib/screens/fence_installation_screen.dart` | 19 |
| `lib/widgets/menu_item_tile.dart` | 17 |
| `lib/screens/help_screen.dart` | 15 |

## Plan de acción propuesto

1. **Dirección visual** con `/ui-ux-pro-max:ui-ux-pro-max`: paleta light+dark, par tipográfico, radios, elevación y motion, partiendo de los colores de la tabla anterior. Contexto de uso: exterior, sol directo, guantes → alto contraste y áreas táctiles grandes.
2. **Sistema de tema** en `lib/core/theme/` (`ThemeData` + `ThemeExtension` con tokens). Elegir gestor de estado (Riverpod recomendado por `flutter-ui`).
3. **Corregir los 8 críticos** pasando a `ListView.builder`.
4. **Migrar los 447 avisos pantalla por pantalla** al tema nuevo, empezando por los ficheros de la tabla anterior.
5. **Motion** con `/motion-design` + `/flutter-animations` (Rive para estados interactivos, Lottie para decorativo).

## Salida completa del script

<details>
<summary>Ver los 471 hallazgos (salida sin editar)</summary>

```text
🔍 Scanning Flutter project: /Users/carlos/Documents/Antigravity-Ohmsafe/ohmsafe_app
📁 Found 38 Dart files
📊 State manager detected: UNKNOWN


============================================================
FLUTTER UI AUDIT RESULTS
============================================================
🔴 Critical: 8  🟡 Warning: 447  🟢 Info: 16
============================================================

🔴 CRITICAL (8 findings):
----------------------------------------
  [PERF_LIST_VIEW_CHILDREN] lib/screens/link_energizer_screen.dart:250
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/link_energizer_screen.dart:581
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/perimeter_inspection_screen.dart:161
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/fence_installation_screen.dart:141
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/service_steps_screen.dart:455
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/home_screen.dart:112
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/screens/route_details_screen.dart:126
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

  [PERF_LIST_VIEW_CHILDREN] lib/widgets/simulation_drawer.dart:114
  ⚠  ListView() with children renders ALL items eagerly
  ✅  Fix: Use ListView.builder(itemCount: n, itemBuilder: ...)

🟡 WARNING (447 findings):
----------------------------------------
  [PERF_HARDCODED_COLOR] lib/main.dart:53
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:54
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:55
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:66
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:68
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:72
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:76
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:80
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:88
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:99
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:107
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:111
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/main.dart:120
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_generales_screen.dart:56
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_generales_screen.dart:57
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_generales_screen.dart:60
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_generales_screen.dart:67
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/datos_generales_screen.dart:105
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_generales_screen.dart:157
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_generales_screen.dart:196
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/datos_generales_screen.dart:278
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_generales_screen.dart:283
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_generales_screen.dart:294
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:90
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:91
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_bancarios_screen.dart:94
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_bancarios_screen.dart:101
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:142
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_bancarios_screen.dart:194
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_bancarios_screen.dart:233
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:270
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:340
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/datos_bancarios_screen.dart:345
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/datos_bancarios_screen.dart:356
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:156
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:192
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:259
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:269
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:281
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:302
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:315
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:333
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:349
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:362
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:386
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:424
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:454
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:547
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:560
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:569
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:590
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:600
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:610
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:633
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:657
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:671
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:673
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:686
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:710
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:711
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:720
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:742
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:763
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:764
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:765
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:769
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:770
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:771
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:776
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:777
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:778
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:807
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:824
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:840
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:858
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:865
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:879
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:880
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:882
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:883
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:885
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:886
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/link_energizer_screen.dart:911
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/link_energizer_screen.dart:926
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:212
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:235
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:237
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:245
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:246
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:260
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:271
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:291
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:292
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:295
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:302
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:340
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:392
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:431
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:488
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:489
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:495
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:540
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:587
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:600
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:630
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:644
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:651
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:653
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:660
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:661
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:706
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/contrasenas_screen.dart:760
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:785
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/contrasenas_screen.dart:811
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:100
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:115
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:122
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:166
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:167
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:168
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:171
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:210
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:262
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:301
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:339
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:348
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:359
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:377
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:389
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:401
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:402
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:411
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:435
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:474
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/facturacion_screen.dart:483
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/facturacion_screen.dart:600
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:98
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:133
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:169
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:184
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:197
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:212
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:219
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:236
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:277
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:279
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:292
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:328
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:352
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:368
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:404
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:423
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:460
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:461
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:465
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/perimeter_inspection_screen.dart:477
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:480
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:494
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/perimeter_inspection_screen.dart:498
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:195
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:242
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:274
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:297
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:306
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:317
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:367
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:368
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:371
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:372
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:375
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:376
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:379
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:380
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:383
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:384
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:419
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:437
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:449
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:454
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:464
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:474
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:486
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:496
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:508
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:532
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:548
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:549
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:563
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:594
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:604
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/instalaciones_screen.dart:624
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:636
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:652
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:680
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/instalaciones_screen.dart:692
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:78
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:113
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:149
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:164
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:177
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:192
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:199
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:215
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:239
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:252
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:281
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:308
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:325
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:351
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:361
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:378
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/fence_installation_screen.dart:390
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/fence_installation_screen.dart:400
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:145
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:156
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:168
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:223
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:392
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:427
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:478
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:487
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:492
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:502
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:514
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:524
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:536
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:562
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:585
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:604
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:740
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:741
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:742
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:756
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:785
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:788
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:804
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:818
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:819
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:844
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:854
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:861
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:869
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:903
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:926
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:935
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:958
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:969
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1005
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1007
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1010
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1012
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1013
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1014
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1018
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1021
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1025
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1027
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1032
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/service_steps_screen.dart:1033
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:1068
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:1082
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/service_steps_screen.dart:1091
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:352
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:353
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:385
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:430
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:465
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:547
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:564
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:584
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:587
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:594
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:628
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:636
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:653
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:655
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:668
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:688
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:700
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:705
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:724
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:729
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:740
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:742
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:755
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:770
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:791
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:819
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:822
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:829
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:840
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:842
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:855
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:886
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:888
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:895
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:900
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:910
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:912
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:923
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:938
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:957
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:984
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:994
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:996
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1009
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1028
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1061
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1066
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1087
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1090
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1098
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1111
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1116
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1181
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1250
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1283
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1291
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1312
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1317
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1354
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1370
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/cierre_instalacion_screen.dart:1380
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1387
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/cierre_instalacion_screen.dart:1395
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:61
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:84
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:107
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:120
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:130
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:147
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:148
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:150
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/help_screen.dart:188
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:223
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:262
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:274
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:315
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:369
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/help_screen.dart:380
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:37
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:94
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:146
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:197
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:225
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:238
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:239
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:240
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:241
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:242
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:247
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:261
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:262
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:304
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:305
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:314
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:346
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:350
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:351
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/screens/profile_main_screen.dart:362
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/profile_main_screen.dart:368
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/home_screen.dart:44
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/home_screen.dart:77
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/home_screen.dart:103
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/home_screen.dart:105
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/route_details_screen.dart:63
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:98
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:149
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:158
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:163
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:173
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:185
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:195
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:207
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:231
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:254
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/route_details_screen.dart:278
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:288
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:308
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:331
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/screens/route_details_screen.dart:347
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:383
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/screens/route_details_screen.dart:402
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/instalaciones_screen.dart:27
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/views/instalaciones_screen.dart:44
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/instalaciones_screen.dart:56
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/instalaciones_screen.dart:71
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/views/instalaciones_screen.dart:90
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/instalaciones_screen.dart:109
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/instalaciones_screen.dart:113
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/instalaciones_screen.dart:120
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/views/instalaciones_screen.dart:172
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/views/instalaciones_screen.dart:182
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/home_screen.dart:16
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/views/home_screen.dart:20
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:51
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:60
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/home_screen.dart:94
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:113
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/home_screen.dart:115
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:136
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:146
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/views/home_screen.dart:240
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/views/home_screen.dart:254
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/simulation_drawer.dart:48
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:88
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:157
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:164
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:176
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:209
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/simulation_drawer.dart:234
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/avatar_halo.dart:40
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/avatar_halo.dart:135
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/avatar_halo.dart:136
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/avatar_halo.dart:147
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/cancellation_flow.dart:37
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/cancellation_flow.dart:60
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/cancellation_flow.dart:97
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:62
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:79
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:82
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/ticket_card.dart:123
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:139
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:142
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/ticket_card.dart:148
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:169
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/ticket_card.dart:175
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/ticket_card.dart:182
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/app_bottom_nav.dart:40
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/app_bottom_nav.dart:79
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:68
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:69
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:73
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:74
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:78
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:79
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:83
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:84
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:88
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:89
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:93
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:94
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:108
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:118
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/menu_item_tile.dart:143
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

  [PERF_HARDCODED_COLOR] lib/widgets/menu_item_tile.dart:218
  ⚠  Hardcoded Color() — breaks theming and dark mode
  ✅  Fix: Use Theme.of(context).colorScheme.* or ThemeExtension

  [PERF_HARDCODED_FONT_SIZE] lib/widgets/menu_item_tile.dart:241
  ⚠  Hardcoded fontSize — breaks accessibility and text scaling
  ✅  Fix: Use Theme.of(context).textTheme.bodyLarge or similar

🟢 INFO: 16 info findings (use --all to show)

============================================================
❌ Fix all 🔴 CRITICAL issues before shipping.

```

</details>
