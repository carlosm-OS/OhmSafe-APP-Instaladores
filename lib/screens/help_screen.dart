import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/incidencias/domain/incidencia.dart';
import '../widgets/ayuda.dart';
import '../widgets/menu_item_tile.dart';
import 'incidencias_screen.dart';

/// Ayuda (v2, 2026-10-23): raíz de pestaña con el encabezado de todos y la lista agrupada de iPhone.
/// Si algo no abre (teléfono, WhatsApp, Academia), el aviso queda en la pantalla con el número a mano.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  /// Qué no se pudo abrir («la llamada», «WhatsApp», «la Academia»).
  String? _noAbrio;

  // Helper method to launch URLs safely
  Future<void> _launchURL(String urlString, String que) async {
    setState(() => _noAbrio = null);
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) setState(() => _noAbrio = que);
    }
  }

  /// Soporte de OhmSafe (el mismo número que ohmsafe.com y la app cliente).
  static const _telefonoVisible = '55 5199 1396';
  static const _telefonoUrl = 'tel:+525551991396';
  static const _whatsappUrl = 'https://wa.me/525551991396';

  /// «Reportar incidencias» abre la pantalla real de incidencias: el reporte
  /// crea un ticket en el Helpdesk de Odoo («Incidencias de campo»). Antes era
  /// un formulario que sólo escribía en consola y decía «Reporte enviado».
  Future<void> _reportarIncidencia() async {
    final creada = await Navigator.of(context).push<Incidencia>(MaterialPageRoute(builder: (_) => const NuevaIncidenciaScreen()));
    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidencia ${creada.referencia} enviada a operaciones')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final chevron = Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoFlujo(titulo: 'Ayuda', subtitulo: 'Contáctanos', volver: false),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    children: [
                      if (_noAbrio != null)
                        MensajeFlujo(
                          icono: Icons.error_outline_rounded,
                          color: cs.error,
                          titulo: 'No se pudo abrir $_noAbrio',
                          texto: 'Marca desde tu teléfono al $_telefonoVisible; ahí también tenemos WhatsApp.',
                        ),
                      const EtiquetaSeccion('Contacto directo'),
                      GrupoFilas(
                        children: [
                          FilaFlujo(
                            leading: MosaicoIcono(icono: Icons.phone_rounded, color: ohm.success),
                            titulo: 'Llamar a soporte',
                            subtitulo: _telefonoVisible,
                            trailing: chevron,
                            onTap: () => _launchURL(_telefonoUrl, 'la llamada'),
                          ),
                          FilaFlujo(
                            leading: MosaicoIcono(icono: Icons.chat_bubble_outline_rounded, color: ohm.success),
                            titulo: 'WhatsApp',
                            subtitulo: _telefonoVisible,
                            trailing: chevron,
                            onTap: () => _launchURL(_whatsappUrl, 'WhatsApp'),
                          ),
                        ],
                      ),
                      const EtiquetaSeccion('¿Algo salió mal en sitio?'),
                      GrupoFilas(
                        pie: 'Operaciones lo recibe y te responde por la campana.',
                        children: [
                          FilaFlujo(
                            leading: MosaicoIcono(icono: Icons.warning_amber_rounded, color: cs.error),
                            titulo: 'Reportar incidencias',
                            trailing: chevron,
                            onTap: _reportarIncidencia,
                          ),
                        ],
                      ),
                      const EtiquetaSeccion('Recursos'),
                      GrupoFilas(
                        children: [
                          FilaFlujo(
                            leading: MosaicoIcono(icono: Icons.school_rounded, color: ohm.info),
                            titulo: 'Academia OhmSafe',
                            trailing: Icon(Icons.open_in_new_rounded, size: 20, color: cs.onSurfaceVariant),
                            onTap: () => _launchURL('https://academia.ohmsafe.com', 'la Academia'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar overlay
          const AppBottomNav(currentTab: "Ayuda"),
        ],
      ),
    );
  }
}
