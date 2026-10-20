package com.ohmsafe.instalador

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Puente con el SDK de Imou (LCOpenSDK) para la app de instaladores (2026-10-20, build 52), gemelo
 * de [EzvizPlugin]: solo sesion y aprovisionamiento de Wi-Fi; nada de video. Canal `ohmsafe/imou`.
 *
 * La implementacion real vive en `src/imouOn` ([ImouBridgeFactory] con el AAR de Imou, que queda
 * FUERA del repo como el paquete de seguridad de Tuya); sin el AAR se compila `src/imouOff` y el
 * puente contesta IMOU_NOT_LINKED. Nada secreto en el log: ni el token, ni el SC, ni la contrasena.
 */
class ImouPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL_NAME = "ohmsafe/imou"
    const val EVENT_CHANNEL_NAME = "ohmsafe/imou/events"
    const val TAG = "OhmSafeImou"
    const val LOG = "[OhmSafe][Imou]"
  }

  private var channel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private val events = ImouEventSink()
  private var bridge: ImouBridge? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
    eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME).also { it.setStreamHandler(events) }
    bridge = ImouBridgeFactory.create(binding.applicationContext, events)
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
      result.error(ImouError.NOT_LINKED, "El puente de camaras Imou no esta disponible (${call.method}).", null)
      return
    }
    bridge.handle(call, ImouResult(call.method, result))
  }
}

/** Lo que implementan `src/imouOn` y `src/imouOff`. */
interface ImouBridge {
  fun handle(call: MethodCall, result: MethodChannel.Result)
  fun dispose()
}

object ImouError {
  const val NOT_LINKED = "IMOU_NOT_LINKED"
  const val NOT_CONFIGURED = "IMOU_NOT_CONFIGURED"
  const val NO_SESSION = "IMOU_NO_SESSION"
  const val PERMISSION = "IMOU_PERMISSION"
  const val WIFI_TIMEOUT = "IMOU_WIFI_TIMEOUT"
  const val WIFI_FAILED = "IMOU_WIFI_FAILED"
  const val UNSUPPORTED = "IMOU_UNSUPPORTED"
  const val TIMEOUT = "IMOU_TIMEOUT"
}

/** Contesta UNA vez, en el hilo principal y con plazo: el SDK contesta desde hilos de red o no contesta. */
class ImouResult(private val method: String, private val inner: MethodChannel.Result) : MethodChannel.Result {
  private val main = Handler(Looper.getMainLooper())
  private val done = AtomicBoolean(false)
  private val timeout = Runnable {
    if (done.compareAndSet(false, true)) {
      inner.error(ImouError.TIMEOUT, "El programa de Imou no respondio.", mapOf("method" to method, "providerCode" to 0))
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
    fun timeoutMsFor(method: String): Long = when (method) {
      "configure" -> 20_000L
      else -> 15_000L
    }
  }
}

/** `EventChannel('ohmsafe/imou/events')`: `wifiConfig {serial, step, status, code?, message?, error?}`. */
class ImouEventSink : EventChannel.StreamHandler {
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
}

/** Nombre de la red Wi-Fi actual del telefono (pide ubicacion concedida; si no, `<unknown ssid>` → null). */
@Suppress("DEPRECATION")
fun currentWifiSsid(context: Context): String? = try {
  val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
  val raw = wm?.connectionInfo?.ssid?.removeSurrounding("\"").orEmpty()
  if (raw.isEmpty() || raw == "<unknown ssid>") null else raw
} catch (t: Throwable) {
  null
}
