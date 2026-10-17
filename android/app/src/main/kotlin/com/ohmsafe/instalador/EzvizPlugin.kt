package com.ohmsafe.instalador

import android.app.Application
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.videogo.exception.BaseException
import com.videogo.openapi.EZConstants
import com.videogo.openapi.EZGlobalSDK
import com.videogo.openapi.EZOpenSDKListener
import com.videogo.openapi.bean.EZProbeDeviceInfo
import com.videogo.wificonfig.APWifiConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Puente con el SDK de EZVIZ para la app de instaladores (2026-10-17), gemelo de
 * `EzvizPlugin.swift`. Es la version RECORTADA del `EzvizPlugin.kt` de la app del cliente
 * (CONTRACTS 11.15 C): solo sesion, sondeo y aprovisionamiento de Wi-Fi; nada de video ni audio.
 * Misma tabla de metodos, eventos y codigos `EZVIZ_*` en las dos apps y en las dos plataformas.
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
    bridge = EzvizBridge(binding.applicationContext, events)
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

class EzvizBridge(private val context: Context, private val events: EzvizEventSink) {

  /** Un solo hilo para todo el SDK: saca las llamadas bloqueantes del principal y las serializa. */
  private val sdkThread = Executors.newSingleThreadExecutor { r -> Thread(r, "ohmsafe-ezviz").apply { isDaemon = true } }
  private val main = Handler(Looper.getMainLooper())

  @Volatile private var configured = false
  @Volatile private var hasSession = false
  private var wifiTimer: Runnable? = null
  @Volatile private var wifiRunning = false

  fun handle(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "configure" -> work { configure(call, result) }
      "setSession" -> work { setSession(call, result) }
      "logout" -> work { logout(result) }
      "probe" -> work { probe(call, result) }
      "wifiConfigStart" -> work { wifiConfigStart(call, result) }
      "wifiConfigStop" -> work { wifiConfigStop(result) }
      "currentSsid" -> result.success(currentSsid())
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    work { stopWifiConfig() }
    sdkThread.shutdown()
  }

  private fun work(block: () -> Unit) {
    try {
      sdkThread.execute {
        try {
          block()
        } catch (t: Throwable) {
          Log.w(EzvizPlugin.TAG, "${EzvizPlugin.LOG} fallo no previsto: ${t.javaClass.simpleName}")
        }
      }
    } catch (e: java.util.concurrent.RejectedExecutionException) {
      Log.w(EzvizPlugin.TAG, "${EzvizPlugin.LOG} el puente ya estaba cerrado")
    }
  }

  private fun MethodCall.serial(): String = argument<String>("serial").orEmpty()

  private fun MethodCall.intArg(key: String, fallback: Int): Int = when (val raw = argument<Any>(key)) {
    is Number -> raw.toInt()
    is String -> raw.toIntOrNull() ?: fallback
    else -> fallback
  }

  private fun notConfigured(method: String) = "El SDK de EZVIZ no esta configurado en esta app ($method)."

  private fun sdk(): EZGlobalSDK? = try {
    EZGlobalSDK.getInstance()
  } catch (t: Throwable) {
    null
  }

  /** Nombre de la red Wi-Fi actual (pide ACCESS_FINE_LOCATION concedido; si no, `<unknown ssid>` → null). */
  @Suppress("DEPRECATION")
  private fun currentSsid(): String? = try {
    val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    val raw = wm?.connectionInfo?.ssid?.removeSurrounding("\"").orEmpty()
    if (raw.isEmpty() || raw == "<unknown ssid>") null else raw
  } catch (t: Throwable) {
    null
  }

  // ---------------------------------------------------------------------------
  // Sesion
  // ---------------------------------------------------------------------------

  /** `configure {appKey, areaDomain, region}`: banderas → `initLib` con la Application → `setServerUrl` de la region. */
  private fun configure(call: MethodCall, result: MethodChannel.Result) {
    val appKey = call.argument<String>("appKey").orEmpty()
    if (appKey.isEmpty()) {
      result.error(EzvizError.NOT_CONFIGURED, "Falta la AppKey de EZVIZ.", null)
      return
    }
    if (configured) {
      result.success(true)
      return
    }
    val app = context.applicationContext as? Application
    if (app == null) {
      result.error(EzvizError.NOT_CONFIGURED, "El SDK de EZVIZ necesita la Application de la app.", null)
      return
    }
    val areaDomain = call.argument<String>("areaDomain")?.takeIf { it.isNotBlank() } ?: "https://iusopen.ezvizlife.com"
    val authDomain = call.argument<String>("authDomain")?.takeIf { it.isNotBlank() } ?: areaDomain.replace("open.", "openauth.")
    try {
      EZGlobalSDK.showSDKLog(false)
      EZGlobalSDK.setDebugStreamEnable(false)
      val ok = EZGlobalSDK.initLib(app, appKey)
      val instance = EZGlobalSDK.getInstance()
      if (!ok || instance == null) {
        result.error(EzvizError.NOT_CONFIGURED, "El SDK de EZVIZ no pudo inicializarse.", null)
        return
      }
      instance.setServerUrl(areaDomain, authDomain)
      configured = true
      Log.i(EzvizPlugin.TAG, "${EzvizPlugin.LOG} SDK ${EZGlobalSDK.getVersion()} listo · ${call.argument<String>("region") ?: "na"} · $areaDomain")
      result.success(true)
    } catch (t: Throwable) {
      // El AAR solo trae arm64-v8a y armeabi-v7a: en un emulador x86_64 `initLib` revienta.
      Log.w(EzvizPlugin.TAG, "${EzvizPlugin.LOG} initLib fallo: ${t.javaClass.simpleName}")
      result.error(EzvizError.UNSUPPORTED, "Este telefono no puede cargar el SDK de EZVIZ (${t.javaClass.simpleName}).", null)
    }
  }

  private fun setSession(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("setSession"), null)
      return
    }
    val token = call.argument<String>("accessToken").orEmpty()
    if (token.isEmpty()) {
      result.error(EzvizError.NO_SESSION, "La sesion de EZVIZ llego vacia.", null)
      return
    }
    val sdk = sdk() ?: run {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("setSession"), null)
      return
    }
    sdk.setAccessToken(token)
    hasSession = true
    Log.i(EzvizPlugin.TAG, "${EzvizPlugin.LOG} sesion puesta")
    result.success(true)
  }

  private fun logout(result: MethodChannel.Result) {
    stopWifiConfig()
    hasSession = false
    runCatching { sdk()?.logout() }
    result.success(true)
  }

  // ---------------------------------------------------------------------------
  // Sondeo
  // ---------------------------------------------------------------------------

  /** `probe {serial}` → `{state, code, …}` con los mismos estados que el backend. No necesita sesion. */
  private fun probe(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("probe"), null)
      return
    }
    val serial = call.serial()
    if (serial.isEmpty()) {
      result.error(EzvizError.UNSUPPORTED, "Falta el numero de serie de la camara.", null)
      return
    }
    val sdk = sdk() ?: run {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("probe"), null)
      return
    }
    val probe = try {
      sdk.probeDeviceInfo(serial, call.argument<String>("deviceType"))
    } catch (t: Throwable) {
      result.error(EzvizError.UNSUPPORTED, "No se pudo sondear la camara (${t.javaClass.simpleName}).", null)
      return
    }
    val error: BaseException? = probe?.baseException
    val info: EZProbeDeviceInfo? = probe?.ezProbeDeviceInfo
    val code = error?.errorCode ?: 0
    if (code == 10002 || code == 10003 || code == 110002 || code == 110003) {
      result.error(EzvizError.TOKEN_EXPIRED, "La sesion de EZVIZ caduco.", mapOf("providerCode" to code))
      return
    }
    val state = probeState(code, info)
    Log.i(EzvizPlugin.TAG, "${EzvizPlugin.LOG} probe → $state · codigo $code")
    if (state == "bound_here" || state == "online_unbound") events.deviceOnline(serial, true)
    else if (state == "offline") events.deviceOnline(serial, false)
    result.success(
      mapOf(
        "state" to state,
        "code" to code,
        "model" to info?.model,
        "supportAP" to (info?.supportAP ?: 0),
        "supportAPType" to (info?.supportAPType ?: 0),
        "supportSoundWave" to (info?.supportSoundWave ?: 0),
        "supportWifi" to (info?.supportWifi ?: 0),
        "support5GWiFi" to (info?.isSupport5GWiFi ?: false),
        "deviceHotSpot" to (info?.deviceHotSpot ?: 0),
      ),
    )
  }

  private fun probeState(code: Int, info: EZProbeDeviceInfo?): String = when (code) {
    0 -> if (info == null || info.status == 1) "online_unbound" else "offline"
    120017, 120020 -> "bound_here"
    120021 -> "online_unbound"
    120022, 120024, 120031, 106002 -> "bound_elsewhere"
    120007, 120023, 120029 -> "offline"
    else -> "not_found"
  }

  // ---------------------------------------------------------------------------
  // Wi-Fi
  // ---------------------------------------------------------------------------

  /**
   * `wifiConfigStart {mode, serial, verifyCode, ssid, password, hotspotPrefix, timeoutS}`. Contesta
   * `true` en cuanto arranca; lo demas va por el evento `wifiConfig`. El exito es el codigo 60
   * (CONNECTED_TO_PLATFORM) o `DEVICE_PLATFORM_REGISTED`. El plazo lo pone esta clase.
   */
  private fun wifiConfigStart(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("wifiConfigStart"), null)
      return
    }
    val sdk = sdk() ?: run {
      result.error(EzvizError.NOT_CONFIGURED, notConfigured("wifiConfigStart"), null)
      return
    }
    val serial = call.serial()
    val verifyCode = call.argument<String>("verifyCode").orEmpty()
    val ssid = call.argument<String>("ssid").orEmpty()
    val password = call.argument<String>("password").orEmpty()
    val mode = call.argument<String>("mode") ?: "ap"
    val timeoutS = call.intArg("timeoutS", 100).coerceIn(30, 300)
    if (serial.isEmpty() || verifyCode.isEmpty() || ssid.isEmpty()) {
      result.error(EzvizError.WIFI_FAILED, "Falta la serie, el codigo de la etiqueta o la red Wi-Fi.", mapOf("providerCode" to 105))
      return
    }
    if (wifiRunning) stopWifiConfig()
    wifiRunning = true
    Log.i(EzvizPlugin.TAG, "${EzvizPlugin.LOG} wifiConfig($mode) arranca · ${timeoutS}s")
    events.wifiConfig(serial, "start", "progress")

    val armed = try {
      when (mode) {
        "wave" -> startWaveConfig(sdk, serial, ssid, password)
        else -> startApConfig(sdk, call, serial, verifyCode, ssid, password)
      }
      true
    } catch (t: Throwable) {
      Log.w(EzvizPlugin.TAG, "${EzvizPlugin.LOG} wifiConfig no arranco: ${t.javaClass.simpleName}")
      false
    }
    if (!armed) {
      wifiRunning = false
      result.error(EzvizError.WIFI_FAILED, "No se pudo iniciar la configuracion de la camara.", mapOf("providerCode" to 105))
      return
    }
    val timer = Runnable {
      if (!wifiRunning) return@Runnable
      work { stopWifiConfig() }
      events.wifiConfig(serial, "timeout", "error", code = 15, message = wifiCopy(15), error = EzvizError.WIFI_TIMEOUT)
    }
    wifiTimer = timer
    main.postDelayed(timer, timeoutS * 1000L)
    result.success(true)
  }

  /** AP: `autoConnectToDeviceHotSpot = true` hace que el SDK se una solo; en Android 10+ sale el dialogo «¿Conectar?» del sistema. */
  private fun startApConfig(sdk: EZGlobalSDK, call: MethodCall, serial: String, verifyCode: String, ssid: String, password: String) {
    val prefix = call.argument<String>("hotspotPrefix")?.takeIf { it.isNotBlank() } ?: "EZVIZ"
    events.wifiConfig(serial, "joining_hotspot", "progress")
    sdk.startAPConfigWifiWithSsid(
      ssid, password, serial, verifyCode, "${prefix}_$serial", "${prefix}_$verifyCode", true,
      object : APWifiConfig.APConfigCallback() {
        override fun onSuccess() = onWifiDone(serial)
        override fun OnError(code: Int) = onWifiError(serial, code)
        override fun onInfo(code: Int, message: String?) = onWifiInfo(serial, code)
        override fun onError(code: Int, message: String?) = onWifiError(serial, code)
      },
    )
  }

  /** Onda de sonido: secundario, solo si la camara no sabe AP. Exige volumen al maximo (error 705). */
  private fun startWaveConfig(sdk: EZGlobalSDK, serial: String, ssid: String, password: String) {
    sdk.startConfigWifi(
      context, ssid, password, serial, EZConstants.EZWiFiConfigMode.EZWiFiConfigWave,
      object : EZOpenSDKListener.EZStartConfigWifiCallback() {
        override fun onStartConfigWifiCallback(device: String?, status: EZConstants.EZWifiConfigStatus?) {
          when (status) {
            EZConstants.EZWifiConfigStatus.DEVICE_PLATFORM_REGISTED -> onWifiDone(serial)
            EZConstants.EZWifiConfigStatus.TIME_OUT -> onWifiError(serial, status.code)
            else -> events.wifiConfig(serial, status?.name ?: "progress", "progress", code = status?.code)
          }
        }

        override fun onInfo(code: Int, message: String?) = onWifiInfo(serial, code)
        override fun onError(code: Int, message: String?) = onWifiError(serial, code)
      },
    )
  }

  private fun onWifiInfo(serial: String, code: Int) {
    if (code == 60) {
      onWifiDone(serial)
      return
    }
    events.wifiConfig(serial, wifiStep(code), "progress", code = code)
  }

  private fun onWifiDone(serial: String) {
    if (!wifiRunning) return
    Log.i(EzvizPlugin.TAG, "${EzvizPlugin.LOG} wifiConfig: camara registrada en la nube")
    work { stopWifiConfig() }
    events.wifiConfig(serial, "registered", "done", code = 60)
    events.deviceOnline(serial, true)
  }

  private fun onWifiError(serial: String, code: Int) {
    if (!wifiRunning) return
    Log.w(EzvizPlugin.TAG, "${EzvizPlugin.LOG} wifiConfig error $code")
    work { stopWifiConfig() }
    val symbol = if (code == 15) EzvizError.WIFI_TIMEOUT else EzvizError.WIFI_FAILED
    events.wifiConfig(serial, "failed", "error", code = code, message = wifiCopy(code), error = symbol)
  }

  private fun wifiStep(code: Int): String = when (code) {
    53 -> "connecting_to_wifi"
    54 -> "sending_config"
    55 -> "connected_to_wifi"
    60 -> "registered"
    else -> "progress"
  }

  private fun wifiCopy(code: Int): String = when (code) {
    505 -> "La camara no esta en modo de configuracion: manten RESET 10-15 s."
    120 -> "El codigo de la etiqueta no es correcto."
    111, 605 -> "El telefono no esta en la red Wi-Fi de la casa."
    501 -> "Falta el permiso de ubicacion."
    15 -> "La camara se conecto pero no llego a internet: revisa la contrasena del Wi-Fi y que sea de 2.4 GHz."
    506 -> "Se rechazo la conexion a la red de la camara."
    110, 502 -> "Ya hay una configuracion en marcha."
    507 -> "No se pudo encender el Wi-Fi del telefono."
    705 -> "Sube el volumen del telefono al maximo."
    801, 802 -> "No se pudo hablar con la nube de EZVIZ."
    else -> "La camara no termino de conectarse a la red (codigo $code)."
  }

  private fun wifiConfigStop(result: MethodChannel.Result) {
    stopWifiConfig()
    result.success(true)
  }

  private fun stopWifiConfig() {
    wifiTimer?.let { main.removeCallbacks(it) }
    wifiTimer = null
    if (!wifiRunning) return
    wifiRunning = false
    val sdk = sdk() ?: return
    // Se paran los DOS: parar el que no corre no hace nada.
    runCatching { sdk.stopAPConfigWifiWithSsid() }
    runCatching { sdk.stopConfigWiFi() }
  }
}
