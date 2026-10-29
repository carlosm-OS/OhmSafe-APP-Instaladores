package com.ohmsafe.instalador

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity: lo exige local_auth (BiometricPrompt) en Android.
class MainActivity : FlutterFragmentActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Puente de cámaras EZVIZ (2026-10-17): conectar la cámara a la Wi-Fi de la casa desde el
    // teléfono del instalador. Canal propio `ohmsafe/ezviz`.
    flutterEngine.plugins.add(EzvizPlugin())
    // Puente de Tuya (2026-10-17): emparejar sensores/cámaras Tuya con el token de la casa.
    flutterEngine.plugins.add(TuyaPlugin())
    // Puente de Imou (2026-10-20, build 52): conectar camaras Imou a la Wi-Fi de la casa sin Imou Life.
    flutterEngine.plugins.add(ImouPlugin())
  }
}
