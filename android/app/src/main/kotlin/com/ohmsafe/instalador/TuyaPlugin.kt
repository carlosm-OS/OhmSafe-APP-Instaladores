package com.ohmsafe.instalador

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Puente con el Smart Life App SDK de Tuya para la app de instaladores (2026-10-17), gemelo de
 * `TuyaPlugin.swift`: solo `configure` y el emparejamiento Wi-Fi (EZ / AP) con un **token de nube**
 * que da el backend. Esta app NUNCA inicia sesion en Tuya: el SDK transmite la red y el token al
 * equipo y el equipo queda en la cuenta de la casa.
 *
 * El codigo que toca el SDK vive en `TuyaBridgeFactory` (src/tuyaOn con el paquete de seguridad fuera
 * del repo; src/tuyaOff contesta TUYA_NOT_LINKED). Nada secreto en el log.
 */
class TuyaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL_NAME = "ohmsafe/tuya"
    const val EVENT_CHANNEL_NAME = "ohmsafe/tuya/events"
    const val TAG = "OhmSafeTuya"
  }

  private var channel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private val events = TuyaEventSink()
  private var bridge: TuyaBridge? = null
  private var context: Context? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
    eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME).also { it.setStreamHandler(events) }
    bridge = TuyaBridgeFactory.create(binding.applicationContext, events)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    eventChannel?.setStreamHandler(null)
    eventChannel = null
    bridge?.dispose()
    bridge = null
    context = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "currentSsid") {
      result.success(currentSsid())
      return
    }
    // Modo punto de acceso (2026-10-22): el instalador se une a la red del equipo desde los ajustes.
    if (call.method == "openWifiSettings") {
      val ok = try {
        context?.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        context != null
      } catch (t: Throwable) {
        false
      }
      result.success(ok)
      return
    }
    val bridge = this.bridge
    if (bridge == null) {
      result.error("TUYA_NOT_LINKED", "El puente de Tuya no esta disponible (${call.method}).", null)
      return
    }
    bridge.handle(call, TuyaResult(call.method, result))
  }

  /** Nombre de la red Wi-Fi actual (pide ubicacion concedida; si no, `<unknown ssid>` → null). */
  @Suppress("DEPRECATION")
  private fun currentSsid(): String? = try {
    val wm = context?.applicationContext?.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    val raw = wm?.connectionInfo?.ssid?.removeSurrounding("\"").orEmpty()
    if (raw.isEmpty() || raw == "<unknown ssid>") null else raw
  } catch (t: Throwable) {
    null
  }
}

interface TuyaBridge {
  fun handle(call: MethodCall, result: MethodChannel.Result)
  fun dispose()
}

/** Contesta UNA vez, en el hilo principal y con plazo. */
class TuyaResult(private val method: String, private val inner: MethodChannel.Result) : MethodChannel.Result {
  private val main = Handler(Looper.getMainLooper())
  private val done = AtomicBoolean(false)
  private val timeout = Runnable {
    if (done.compareAndSet(false, true)) inner.error("TUYA_TIMEOUT", "El SDK de Tuya no respondio ($method).", null)
  }

  init {
    main.postDelayed(timeout, if (method == "pairStart") 30_000L else 15_000L)
  }

  override fun success(result: Any?) = reply { inner.success(result) }
  override fun error(code: String, message: String?, details: Any?) = reply { inner.error(code, message, details) }
  override fun notImplemented() = reply { inner.notImplemented() }

  private fun reply(block: () -> Unit) {
    if (!done.compareAndSet(false, true)) return
    main.removeCallbacks(timeout)
    if (Looper.myLooper() == Looper.getMainLooper()) block() else main.post(block)
  }
}

/** `pairProgress {step}` · `pairDone {devId, name, productId, category}` · `pairError {code, message}`. */
class TuyaEventSink : EventChannel.StreamHandler {
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

  fun pairProgress(step: String) = send(mapOf("type" to "pairProgress", "step" to step))
  fun pairDone(devId: String, name: String, productId: String, category: String) =
    send(mapOf("type" to "pairDone", "devId" to devId, "name" to name, "productId" to productId, "category" to category))
  fun pairError(code: String, message: String) = send(mapOf("type" to "pairError", "code" to code, "message" to message))

  // Bluetooth (2026-10-22): `bleFound {uuid, productId, mac, combo, rssi?}` · `bleScanEnd` · `bleState {poweredOn}`.
  fun bleFound(uuid: String, productId: String, mac: String, combo: Boolean, rssi: Int?) {
    val payload = mutableMapOf<String, Any?>("type" to "bleFound", "uuid" to uuid, "productId" to productId, "mac" to mac, "combo" to combo)
    if (rssi != null && rssi < 0) payload["rssi"] = rssi
    send(payload)
  }
  fun bleScanEnd() = send(mapOf("type" to "bleScanEnd"))
  fun bleState(poweredOn: Boolean) = send(mapOf("type" to "bleState", "poweredOn" to poweredOn))
}
