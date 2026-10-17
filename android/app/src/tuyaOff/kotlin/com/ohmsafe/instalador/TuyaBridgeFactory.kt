package com.ohmsafe.instalador

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Variante SIN el SDK de Tuya (no hay paquete de seguridad fuera del repo): la app compila igual y
// el puente dice la verdad. La misma clase existe en src/tuyaOn con la implementacion real.
object TuyaBridgeFactory {
  fun create(context: Context, events: TuyaEventSink): TuyaBridge = TuyaBridgeUnavailable()
}

class TuyaBridgeUnavailable : TuyaBridge {
  override fun handle(call: MethodCall, result: MethodChannel.Result) {
    result.error("TUYA_NOT_LINKED", "El SDK de Tuya no esta enlazado en esta compilacion (${call.method}).", null)
  }

  override fun dispose() = Unit
}
