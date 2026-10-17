package com.ohmsafe.instalador

import android.app.Application
import android.content.Context
import android.util.Log
import com.thingclips.smart.home.sdk.ThingHomeSdk
import com.thingclips.smart.home.sdk.builder.ActivatorBuilder
import com.thingclips.smart.sdk.api.IThingActivator
import com.thingclips.smart.sdk.api.IThingSmartActivatorListener
import com.thingclips.smart.sdk.bean.DeviceBean
import com.thingclips.smart.sdk.enums.ActivatorModelEnum
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Variante CON el SDK de Tuya (paquete de seguridad fuera del repo). Solo `configure` y el
// emparejamiento con el token de nube de la casa; sin login, sin camaras IPC.
object TuyaBridgeFactory {
  fun create(context: Context, events: TuyaEventSink): TuyaBridge = TuyaBridgeImpl(context, events)
}

class TuyaBridgeImpl(private val context: Context, private val events: TuyaEventSink) : TuyaBridge {

  @Volatile private var configured = false
  private var activator: IThingActivator? = null

  override fun handle(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "configure" -> configure(call, result)
      "pairStart" -> pairStart(call, result)
      "pairCancel" -> {
        stopActivator()
        result.success(true)
      }
      else -> result.notImplemented()
    }
  }

  override fun dispose() = stopActivator()

  /** `configure {appKey, appSecret}` → `ThingHomeSdk.init`. Las llaves llegan por dart-define. */
  private fun configure(call: MethodCall, result: MethodChannel.Result) {
    val appKey = call.argument<String>("appKey").orEmpty()
    val appSecret = call.argument<String>("appSecret").orEmpty()
    if (appKey.isEmpty() || appSecret.isEmpty()) {
      result.error("TUYA_NO_KEYS", "Faltan las llaves de Tuya en esta compilacion.", null)
      return
    }
    if (configured) {
      result.success(true)
      return
    }
    val app = context.applicationContext as? Application
    if (app == null) {
      result.error("TUYA_NOT_CONFIGURED", "El SDK de Tuya necesita la Application de la app.", null)
      return
    }
    try {
      ThingHomeSdk.init(app, appKey, appSecret)
      configured = true
      Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] SDK iniciado")
      result.success(true)
    } catch (t: Throwable) {
      Log.w(TuyaPlugin.TAG, "[OhmSafe][Tuya] init fallo: ${t.javaClass.simpleName}")
      result.error("TUYA_NOT_CONFIGURED", "El SDK de Tuya no pudo iniciarse (${t.javaClass.simpleName}).", null)
    }
  }

  /**
   * `pairStart {mode:'EZ'|'AP', ssid, password, token, timeoutS}`: el token (region+token+secreto) lo
   * dio el backend para la cuenta de la casa; aqui NO se pide a Tuya ni se inicia sesion. El SDK sin
   * sesion puede no avisar del exito: el lado Dart lo confirma con el backend.
   */
  private fun pairStart(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error("TUYA_NOT_CONFIGURED", "El SDK de Tuya no esta configurado (pairStart).", null)
      return
    }
    val ssid = call.argument<String>("ssid").orEmpty()
    val password = call.argument<String>("password").orEmpty()
    val token = call.argument<String>("token").orEmpty()
    val modeText = (call.argument<String>("mode") ?: "EZ").uppercase()
    val timeoutS = (call.argument<Number>("timeoutS")?.toLong() ?: 120L).coerceIn(30L, 300L)
    if (ssid.isEmpty() || token.isEmpty()) {
      result.error("TUYA_PAIR_BAD_ARGS", "Falta el nombre de la red Wi-Fi o el permiso de la casa.", null)
      return
    }
    val mode = if (modeText == "AP") ActivatorModelEnum.THING_AP else ActivatorModelEnum.THING_EZ
    stopActivator()

    val builder = ActivatorBuilder()
      .setContext(context)
      .setSsid(ssid)
      .setPassword(password)
      .setActivatorModel(mode)
      .setTimeOut(timeoutS)
      .setToken(token)
      .setListener(
        object : IThingSmartActivatorListener {
          override fun onError(errorCode: String?, errorMsg: String?) {
            Log.w(TuyaPlugin.TAG, "[OhmSafe][Tuya] pairStart$modeText onError codigo $errorCode")
            events.pairError(code = errorCode ?: "TUYA_PAIR_FAILED", message = errorMsg ?: "El equipo no termino de conectarse a la red.")
          }

          override fun onActiveSuccess(devResp: DeviceBean?) {
            Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] pairStart$modeText onActiveSuccess")
            events.pairDone(
              devId = devResp?.devId.orEmpty(),
              name = devResp?.name.orEmpty(),
              productId = devResp?.productId.orEmpty(),
              category = devResp?.category.orEmpty(),
            )
          }

          override fun onStep(step: String?, data: Any?) {
            events.pairProgress(step.orEmpty().ifEmpty { "step" })
          }
        },
      )
    // Se asigna ANTES de `start()`: un fallo sincrono dejaria el activador sin quien lo parara.
    val created = ThingHomeSdk.getActivatorInstance().newActivator(builder)
    activator = created
    try {
      created.start()
    } catch (t: Throwable) {
      activator = null
      result.error("TUYA_PAIR_FAILED", "No se pudo iniciar el emparejamiento (${t.javaClass.simpleName}).", null)
      return
    }
    Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] emparejamiento $modeText: ssid ${ssid.length} car., plazo $timeoutS s")
    events.pairProgress(if (mode == ActivatorModelEnum.THING_AP) "ap_waiting" else "ez_waiting")
    result.success(true)
  }

  private fun stopActivator() {
    val a = activator ?: return
    activator = null
    runCatching { a.stop() }
    runCatching { a.onDestroy() }
  }
}
