# Auditoría de diseño, textos e interacción — 2026-10-23

Revisión de toda la app Installer (rama `CarlosClaudDev-solo-tuya`, después de f18027e) con criterios de
Apple (respuesta inmediata, interrumpible, consistencia, wayfinding, perdón, confirmar sólo lo destructivo)
y la regla de oro de Carlos (todo botón dice qué está pasando). **Es una propuesta: nada está aplicado.**
Las pantallas ajustadas viven en el lienzo «Proceso de instalación», página «Ajustes de diseño · propuesta»
(https://claude.ai/artifact/97Y4SVusV35r3KKAZj1gCD).

## Críticos (perder o duplicar trabajo)

| # | Dónde | Qué pasa | Propuesta |
|---|---|---|---|
| 1 | `widgets/app_bottom_nav.dart:68` | «Home» hace `popUntil` desde cualquier paso: se pierde firma, fotos, prueba; ignora `PopScope`. | Sin barra inferior dentro del flujo, o salida con confirmación. |
| 2 | `instalaciones_screen.dart:842`, `reparaciones_screen.dart:329` | «Iniciar ruta» sin estado de carga: doble toque = doble aviso al cliente; la lista no se refresca al volver. | `loading` «Avisando al cliente…», guard, `await push` + recarga silenciosa. |
| 3 | `cierre_instalacion_screen.dart:313` | «Terminar instalación» sigue activo hasta 4 s (firma + GPS): doble envío posible. | `_isLoading` antes de cualquier `await`, frases por etapa. |
| 4 | `service_steps_screen.dart:817` | Segundo «Terminar» simula 2.5 s de envío sin enviar nada. | Al volver con `cierre_completed`, mostrar éxito y salir. |

## Altos

- Gesto de regreso de iOS perdido (`app_theme.dart:129`, `app_motion.dart:67`); la transición ignora Reducir movimiento.
- Atrás del sistema distinto de la flecha: cierre (`:582`, borra todo el cierre) y vincular (`:328`). `PopScope`.
- Salir de Agregar dispositivos con atrás marca el paso como listo (`:207`).
- Diálogos encadenados: salida 12 V (`:575`) y «¿Sonó?» que salta a los 15 s (`:550`) → preguntas dentro de la fila.
- Hoja de cancelación se cierra arrastrando mientras envía (`cancellation_flow.dart:30`).
- «Reportar incidencias (opcional)» abre «Cancelar instalación» (`link_energizer_screen.dart:498`).
- Punto azul fijo sobre la campana (perfil `:210`, datos bancarios `:158`, contraseñas `:379`): miente.
- Botones de carga mudos: `OhmGradientButton:61`, `BotonesDialogo:79` y 11 pantallas con spinner sin texto.
- Errores crudos: `catch (e) → ServerFailure(e.toString())` en repos y `"…: ${f.message}"` en ~15 pantallas.
- Marcas visibles en pantallas apagadas (EZVIZ/Imou: `agregar:965`, `emparejador_ezviz`, `conectar_imou`) y «Odoo»/«dashboard»/«MAC» en textos.

## Sistema propuesto

- **Letra:** primero pasar Inter/Lexend a archivos estáticos por peso (`pubspec.yaml:91-97`); hoy la fuente
  variable sin pesos obliga a escribir `TextStyle` a mano (21 tamaños). Escala: 28/22/18/16/14/13/11.
- **Radios:** 8 chips · 12 campos y botones en fila · 16 botones, filas, avisos · 20 tarjetas · 28 diálogos y hojas (hoy 18 valores).
- **Color:** un naranja (`cs.primary`; `secondary` fuera de la UI), un rojo (`cs.error`, hoy 6), verde `ohm.success`,
  gris de apoyo `onSurfaceVariant` (la etiqueta gris actual al 40 % da 2.4:1), bordes de control `cs.outline`, texto
  sobre naranja claro en `onPrimaryContainer`. Cero `Colors.*`.
- **Piezas únicas:** `EncabezadoFlujo` en todas (13 pantallas tienen el suyo), `TarjetaFlujo` sin sombras, `FilaFlujo`,
  `BotonSecundario` (fusionar con `BotonContornoSecundario`), `EstadoVacio`, `Cargando(frase)`, `InsigniaUrgente`,
  `AlertDialog` del tema + `BotonesDialogo`.
- **Errores:** en pantalla `MensajeFlujo` rojo junto a la acción; en campo `errorText`; bajo botón apagado
  `FaltaParaSeguir`; SnackBar sólo para confirmar (con «Deshacer»).
- **Toque:** mínimo 48 (contadores de la cerca 32×38, `BotonFila` 38, `InfoAyuda` 40).

## Glosario

instalación/reparación (no orden, ticket, intervención) · energizador (no OhmBox, equipo) · vincular (no ligar) ·
conectar a la Wi‑Fi (no emparejar) · sensor inalámbrico (no 433, por radio) · sensor cableado · registrar
(no dar de alta) · «Volver a intentar» · «Presiona» · «Tu sesión venció. Entra de nuevo con tu contraseña.» ·
tipo oración en títulos y botones · «…» en vez de «...» · «carácter».

## Orden sugerido de implementación

1. Protecciones (críticos 1–4, `PopScope`, guards).
2. Botón con frase + mapeo único de errores + glosario.
3. Letra estática y tokens.
4. Piezas únicas en las 13 pantallas con componentes propios.
5. Pulido de movimiento (gesto iOS, Reducir movimiento, camión saltable, `EntradaSuave`, `Presionable` con onTapDown).

Código muerto: `lib/views/`, `widgets/ticket_card.dart`, `widgets/simulation_drawer.dart`, `cotizaciones_screen.dart` (sólo pruebas).
