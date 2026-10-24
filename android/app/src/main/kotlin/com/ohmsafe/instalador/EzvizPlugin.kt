package com.ohmsafe.instalador

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Puente con el SDK de EZVIZ para la app de instaladores (2026-10-17), gemelo de
 * `EzvizPlugin.swift`. Es la version RECORTADA del `EzvizPlugin.kt` de la app del cliente
 * (CONTRACTS 11.15 C): solo sesion, sondeo y aprovisionamiento de Wi-Fi; nada de video ni audio.
 * Misma tabla de metodos, eventos y codigos `EZVIZ_*` en las dos apps y en las dos plataformas.
 *
 * 2026-10-20 (Carlos: la app solo ofrece Tuya): el SDK de EZVIZ queda FUERA de la build por omision.
 * La implementacion real vive en `src/ezvizOn` ([EzvizBridgeFactory] con el SDK, solo si Gradle
 * recibe `ohmsafeEzviz=true` u `OHMSAFE_EZVIZ=1`); si no, se compila `src/ezvizOff` y el puente
 * contesta EZVIZ_NOT_LINKED. Las pantallas de EZVIZ siguen en la app, apagadas tras MarcasCamara.
 *
 *  1. Todo el SDK es bloqueante: TODO pasa por [EzvizBridge.work] y la respuesta vuelve al hilo
 *     principal por [EzvizResult].
 *  2. Nada secreto en el log: ni el token, ni el codigo de la etiqueta, ni la contrasena del Wi-Fi.
 */
class EzvizPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL_NAME = "ohmsafe/ezviz"
    const val EVENT_CHANNEL_NAME = "ohmsafe/ezviz/events"
    const val TAG = "OhmSafeEzviz"
    const val LOG = "[OhmSafe][EZVIZ]"
  }

  private var channel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private val events = EzvizEventSink()
  private var bridge: EzvizBridge? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
    eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME).also { it.setStreamHandler(events) }
    bridge = EzvizBridgeFactory.create(binding.applicationContext, events)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    eventChannel?.setStreamHandler(null)
    eventChannel = null
    bridge?.dispose()
    bridge = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    val bridge = this.bridge
    if (bridge == null) {
      result.error(EzvizError.NOT_LINKED, "El puente de camaras EZVIZ no esta disponible (${call.method}).", null)
      return
    }
    bridge.handle(call, EzvizResult(call.method, result))
  }
}

object EzvizError {
  const val NOT_LINKED = "EZVIZ_NOT_LINKED"
  const val NOT_CONFIGURED = "EZVIZ_NOT_CONFIGURED"
  const val NO_SESSION = "EZVIZ_NO_SESSION"
  const val TOKEN_EXPIRED = "EZVIZ_TOKEN_EXPIRED"
  const val WIFI_TIMEOUT = "EZVIZ_WIFI_TIMEOUT"
  const val WIFI_FAILED = "EZVIZ_WIFI_FAILED"
  const val UNSUPPORTED = "EZVIZ_UNSUPPORTED"
  const val TIMEOUT = "EZVIZ_TIMEOUT"
}

/** Contesta UNA vez, en el hilo principal y con plazo: el SDK contesta desde hilos de red o no contesta. */
class EzvizResult(private val method: String, private val inner: MethodChannel.Result) : MethodChannel.Result {
  private val main = Handler(Looper.getMainLooper())
  private val done = AtomicBoolean(false)
  private val timeout = Runnable {
    if (done.compareAndSet(false, true)) {
      inner.error(codeFor(method), "La camara no respondio. Revisa que tenga corriente.", mapOf("method" to method, "providerCode" to 0))
    }
  }

  init {
    main.postDelayed(timeout, timeoutMsFor(method))
  }

  override fun success(result: Any?) = reply { inner.success(result) }
  override fun error(code: String, message: String?, details: Any?) = reply { inner.error(code, message, details) }
  override fun notImplemented() = reply { inner.notImplemented() }

  private fun reply(block: () -> Unit) {
    if (!done.compareAndSet(false, true)) return
    main.removeCallbacks(timeout)
    if (Looper.myLooper() == Looper.getMainLooper()) block() else main.post(block)
  }

  companion object {
    fun codeFor(method: String): String = when (method) {
      "wifiConfigStart", "wifiConfigStop" -> EzvizError.WIFI_TIMEOUT
      else -> EzvizError.TIMEOUT
    }

    fun timeoutMsFor(method: String): Long = when (method) {
      "probe" -> 30_000L
      "wifiConfigStart" -> 40_000L
      else -> 15_000L
    }
  }
}

/** `EventChannel('ohmsafe/ezviz/events')`: `wifiConfig {serial, step, status, code?, message?, error?}` y `deviceOnline {serial, online}`. */
class EzvizEventSink : EventChannel.StreamHandler {
  private val main = Handler(Looper.getMainLooper())
  private var sink: EventChannel.EventSink? = null

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  private fun send(payload: Map<String, Any?>) {
    main.post { sink?.success(payload) }
  }

  fun wifiConfig(serial: String, step: String, status: String, code: Int? = null, message: String? = null, error: String? = null) =
    send(mapOf("type" to "wifiConfig", "serial" to serial, "step" to step, "status" to status, "code" to code, "message" to message, "error" to error))

  fun deviceOnline(serial: String, online: Boolean) = send(mapOf("type" to "deviceOnline", "serial" to serial, "online" to online))
}

/** Lo que implementan `src/ezvizOn` (SDK real) y `src/ezvizOff` (stub EZVIZ_NOT_LINKED). */
interface EzvizBridge {
  fun handle(call: MethodCall, result: MethodChannel.Result)
  fun dispose()
}

/** Nombre de la red Wi-Fi actual del telefono (pide ACCESS_FINE_LOCATION concedido; si no, `<unknown ssid>` → null). */
@Suppress("DEPRECATION")
fun ohmsafeCurrentSsid(context: Context): String? = try {
  val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
  val raw = wm?.connectionInfo?.ssid?.removeSurrounding("\"").orEmpty()
  if (raw.isEmpty() || raw == "<unknown ssid>") null else raw
} catch (t: Throwable) {
  null
}
