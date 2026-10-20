package com.ohmsafe.instalador

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Variante SIN el SDK de Imou (no hay LCOpenSDK.aar fuera del repo): la app compila igual y el
// puente dice la verdad. La misma clase existe en src/imouOn con la implementacion real.
object ImouBridgeFactory {
  fun create(context: Context, events: ImouEventSink): ImouBridge = ImouBridgeUnavailable(context)
}

class ImouBridgeUnavailable(private val context: Context) : ImouBridge {
  override fun handle(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "currentSsid") {
      result.success(currentWifiSsid(context))
      return
    }
    result.error(ImouError.NOT_LINKED, "El SDK de Imou no esta enlazado en esta compilacion (${call.method}).", null)
  }

  override fun dispose() = Unit
}
