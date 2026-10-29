package com.ohmsafe.instalador

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Variante SIN el SDK de EZVIZ (la de siempre desde 2026-10-20: la app solo ofrece Tuya). La app
// compila sin el AAR de EZVIZ (unos 40 MB menos) y el puente dice la verdad. La misma clase existe en
// src/ezvizOn con la implementacion real; se enlaza con `ohmsafeEzviz=true` u `OHMSAFE_EZVIZ=1`.
object EzvizBridgeFactory {
  fun create(context: Context, events: EzvizEventSink): EzvizBridge = EzvizBridgeUnavailable(context)
}

class EzvizBridgeUnavailable(private val context: Context) : EzvizBridge {
  override fun handle(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "currentSsid") {
      result.success(ohmsafeCurrentSsid(context))
      return
    }
    result.error(EzvizError.NOT_LINKED, "El SDK de EZVIZ no esta enlazado en esta compilacion (${call.method}).", null)
  }

  override fun dispose() = Unit
}
