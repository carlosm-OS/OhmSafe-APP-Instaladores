package com.ohmsafe.instalador

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.PatternMatcher
import android.util.Log
import com.lc.opensdk.api.InitParams
import com.lc.opensdk.api.LCOpenSDK_Api
import com.lc.opensdk.configwifi.LCOpenSDK_ConfigWifi
import com.lc.opensdk.device.LCOpenSDK_SearchDevices
import com.lc.opensdk.media.DeviceInitInfo
import com.lc.opensdk.softap.LCOpenSDK_SoftAPConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.util.concurrent.Executors

// Variante CON el SDK de Imou (LCOpenSDK.aar fuera del repo, ver docs/camaras-imou.md).
object ImouBridgeFactory {
  fun create(context: Context, events: ImouEventSink): ImouBridge = ImouBridgeReal(context, events)
}

/**
 * Lo que hace el SDK, en el orden del demo oficial de Imou (DeviceAddModule):
 *
 *  - `configure {host, port, accessToken}` → `LCOpenSDK_Api.initOpenApi(InitParams(ctx, "host:port", token))`.
 *  - `wifiConfigStart {mode: smart|ap, serial, verifyCode, ssid, password, hotspotPrefix, timeoutS}`:
 *     · `smart`: `LCOpenSDK_ConfigWifi.configWifiStart(ctx, sn, ssid, pwd, "", 11000, 0)` (multicast +
 *       onda) y a la vez `LCOpenSDK_SearchDevices.startSearchDevices(ctx, sn, timeout, listener)`; cuando
 *       `onDeviceSearched` ve la serie, la red ya llego a la camara (evento `found_on_lan` / done).
 *     · `ap`: el telefono se une al hotspot `DAP-…` de la camara (WifiNetworkSpecifier, Android 10+),
 *       se ata el proceso a esa red, se toma la puerta de enlace (la camara) y se llama
 *       `LCOpenSDK_SoftAPConfig.startSoftAPConfig(ssid, pwd, ipCamara, SC, true, handler, timeoutMs)`;
 *       `msg.arg1 == 0` es exito. Al terminar se suelta la red para volver a la Wi-Fi de la casa.
 *  - El exito final (camara en la nube) lo decide el backend por `deviceOnline`; aqui solo se entrega la red.
 */
class ImouBridgeReal(private val context: Context, private val events: ImouEventSink) : ImouBridge {

  private val sdkThread = Executors.newSingleThreadExecutor { r -> Thread(r, "ohmsafe-imou").apply { isDaemon = true } }
  private val main = Handler(Looper.getMainLooper())

  @Volatile private var configured = false
  private var configuredToken: String? = null
  @Volatile private var wifiRunning = false
  private var wifiTimer: Runnable? = null
  private var multicastLock: WifiManager.MulticastLock? = null
  private var networkCallback: ConnectivityManager.NetworkCallback? = null

  override fun handle(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "configure" -> work { configure(call, result) }
      "wifiConfigStart" -> work { wifiConfigStart(call, result) }
      "wifiConfigStop" -> work { stopWifiConfig(); result.success(true) }
      "currentSsid" -> result.success(currentWifiSsid(context))
      else -> result.notImplemented()
    }
  }

  override fun dispose() {
    work { stopWifiConfig() }
    sdkThread.shutdown()
  }

  private fun work(block: () -> Unit) {
    try {
      sdkThread.execute {
        try {
          block()
        } catch (t: Throwable) {
          Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} fallo no previsto: ${t.javaClass.simpleName}")
        }
      }
    } catch (e: java.util.concurrent.RejectedExecutionException) {
      Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} el puente ya estaba cerrado")
    }
  }

  private fun MethodCall.intArg(key: String, fallback: Int): Int = when (val raw = argument<Any>(key)) {
    is Number -> raw.toInt()
    is String -> raw.toIntOrNull() ?: fallback
    else -> fallback
  }

  // ---------------------------------------------------------------------------
  // Sesion
  // ---------------------------------------------------------------------------

  /** `configure {host, port, accessToken}`. El host va sin protocolo; el SDK pone https por el :443. */
  private fun configure(call: MethodCall, result: MethodChannel.Result) {
    val host = call.argument<String>("host").orEmpty().trim().removePrefix("https://").removePrefix("http://").trimEnd('/')
    val port = call.intArg("port", 443)
    val token = call.argument<String>("accessToken").orEmpty()
    if (host.isEmpty()) {
      result.error(ImouError.NOT_CONFIGURED, "Falta el host de Imou.", null)
      return
    }
    if (token.isEmpty()) {
      result.error(ImouError.NO_SESSION, "La sesion de Imou llego vacia.", null)
      return
    }
    if (configured && configuredToken == token) {
      result.success(true)
      return
    }
    try {
      if (configured) runCatching { LCOpenSDK_Api.uninitOpenApi() }
      val hostPort = if (host.contains(':')) host else "$host:$port"
      val code = LCOpenSDK_Api.initOpenApi(InitParams(context.applicationContext, hostPort, token))
      if (code != 0) {
        Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} initOpenApi devolvio $code")
        result.error(ImouError.NOT_CONFIGURED, "El SDK de Imou no pudo inicializarse ($code).", mapOf("providerCode" to code))
        return
      }
      configured = true
      configuredToken = token
      Log.i(ImouPlugin.TAG, "${ImouPlugin.LOG} SDK listo · $hostPort")
      result.success(true)
    } catch (t: Throwable) {
      // El AAR solo trae armeabi-v7a y arm64-v8a: en un emulador x86_64 el init revienta.
      Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} initOpenApi fallo: ${t.javaClass.simpleName}")
      result.error(ImouError.UNSUPPORTED, "Este telefono no puede cargar el SDK de Imou (${t.javaClass.simpleName}).", null)
    }
  }

  // ---------------------------------------------------------------------------
  // Wi-Fi
  // ---------------------------------------------------------------------------

  private fun wifiConfigStart(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error(ImouError.NOT_CONFIGURED, "El SDK de Imou no esta configurado en esta app (wifiConfigStart).", null)
      return
    }
    val serial = call.argument<String>("serial").orEmpty().trim().uppercase()
    val verifyCode = call.argument<String>("verifyCode").orEmpty().trim()
    val ssid = call.argument<String>("ssid").orEmpty()
    val password = call.argument<String>("password").orEmpty()
    val mode = call.argument<String>("mode") ?: "smart"
    val prefix = call.argument<String>("hotspotPrefix")?.takeIf { it.isNotBlank() } ?: "DAP-"
    val timeoutS = call.intArg("timeoutS", 90).coerceIn(30, 300)
    if (serial.isEmpty() || ssid.isEmpty()) {
      result.error(ImouError.WIFI_FAILED, "Falta la serie de la camara o la red Wi-Fi.", mapOf("providerCode" to -1))
      return
    }
    if (mode == "ap" && verifyCode.isEmpty()) {
      result.error(ImouError.WIFI_FAILED, "Falta el codigo SC de la camara.", mapOf("providerCode" to -1))
      return
    }
    if (wifiRunning) stopWifiConfig()
    wifiRunning = true
    Log.i(ImouPlugin.TAG, "${ImouPlugin.LOG} wifiConfig($mode) arranca · ${timeoutS}s")
    events.wifiConfig(serial, "start", "progress")

    val armed = try {
      when (mode) {
        "ap" -> startSoftAp(serial, verifyCode, ssid, password, prefix, timeoutS)
        else -> startSmartConfig(serial, ssid, password, timeoutS)
      }
      true
    } catch (t: Throwable) {
      Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} wifiConfig no arranco: ${t.javaClass.simpleName}")
      false
    }
    if (!armed) {
      stopWifiConfig()
      result.error(ImouError.WIFI_FAILED, "No se pudo iniciar la configuracion de la camara.", mapOf("providerCode" to -1))
      return
    }
    val timer = Runnable {
      if (!wifiRunning) return@Runnable
      work { stopWifiConfig() }
      events.wifiConfig(serial, "timeout", "error", code = -4, message = null, error = ImouError.WIFI_TIMEOUT)
    }
    wifiTimer = timer
    main.postDelayed(timer, timeoutS * 1000L)
    result.success(true)
  }

  /** Modo rapido: SmartConfig (multicast + onda) y busqueda de la camara en la red local. */
  private fun startSmartConfig(serial: String, ssid: String, password: String, timeoutS: Int) {
    val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    multicastLock = wm?.createMulticastLock("ohmsafe-imou")?.apply {
      setReferenceCounted(false)
      runCatching { acquire() }
    }
    events.wifiConfig(serial, "sending_config", "progress")
    // Mismos argumentos que el demo oficial: capacidades "" (el SDK las deduce), 11000 Hz, FSK nuevo.
    LCOpenSDK_ConfigWifi.configWifiStart(context.applicationContext, serial, ssid, password, "", 11000, 0)
    LCOpenSDK_SearchDevices.getInstance().startSearchDevices(
      context.applicationContext, serial, timeoutS,
      object : LCOpenSDK_SearchDevices.ISearchDeviceListener {
        override fun onDeviceSearched(sn: String?, info: DeviceInitInfo?) {
          if (!wifiRunning) return
          val visto = sn?.trim()?.uppercase().orEmpty()
          val serieInfo = info?.mSerialNo?.trim()?.uppercase().orEmpty()
          if (visto != serial && serieInfo != serial) return
          Log.i(ImouPlugin.TAG, "${ImouPlugin.LOG} camara vista en la red local")
          work { stopWifiConfig() }
          events.wifiConfig(serial, "found_on_lan", "done", code = 0)
        }
      },
    )
  }

  /** Modo AP (Android 10+): unirse al hotspot de la camara y pasarle la red por ahi. */
  private fun startSoftAp(serial: String, sc: String, ssid: String, password: String, prefix: String, timeoutS: Int) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      throw UnsupportedOperationException("ap mode needs Android 10")
    }
    val cm = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    events.wifiConfig(serial, "joining_hotspot", "progress")
    val specifier = WifiNetworkSpecifier.Builder()
      .setSsidPattern(PatternMatcher(prefix, PatternMatcher.PATTERN_PREFIX))
      .build()
    val request = NetworkRequest.Builder()
      .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
      .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
      .setNetworkSpecifier(specifier)
      .build()
    val callback = object : ConnectivityManager.NetworkCallback() {
      override fun onAvailable(network: Network) {
        if (!wifiRunning) return
        cm.bindProcessToNetwork(network)
        val gateway = gatewayOf(cm, network) ?: "192.168.1.108"
        Log.i(ImouPlugin.TAG, "${ImouPlugin.LOG} unido al hotspot de la camara")
        events.wifiConfig(serial, "joined_hotspot", "progress")
        work { sendOverSoftAp(serial, sc, ssid, password, gateway, timeoutS) }
      }

      override fun onUnavailable() {
        if (!wifiRunning) return
        Log.w(ImouPlugin.TAG, "${ImouPlugin.LOG} no se pudo unir al hotspot")
        work { stopWifiConfig() }
        events.wifiConfig(serial, "failed", "error", code = -2, message = "No se encontro la red «$prefix…» de la camara. Manten RESET 10 s, espera a que la luz parpadee y vuelve a intentarlo.", error = ImouError.WIFI_FAILED)
      }
    }
    networkCallback = callback
    cm.requestNetwork(request, callback, (timeoutS * 1000L).toInt().coerceAtMost(120_000))
  }

  private fun sendOverSoftAp(serial: String, sc: String, ssid: String, password: String, gateway: String, timeoutS: Int) {
    if (!wifiRunning) return
    events.wifiConfig(serial, "sending_config", "progress")
    val handler = object : Handler(Looper.getMainLooper()) {
      override fun handleMessage(msg: Message) {
        if (!wifiRunning) return
        val code = msg.arg1
        Log.i(ImouPlugin.TAG, "${ImouPlugin.LOG} softAP respondio $code")
        work { stopWifiConfig() }
        if (code == 0) {
          events.wifiConfig(serial, "sent_over_hotspot", "done", code = 0)
        } else {
          events.wifiConfig(serial, "failed", "error", code = code, message = softApCopy(code), error = ImouError.WIFI_FAILED)
        }
      }
    }
    // (wifiName, wifiPwd, ipCamara, devicePwd = SC, isSC, handler, timeoutMs): la variante sin cifrado explicito.
    LCOpenSDK_SoftAPConfig.startSoftAPConfig(ssid, password, gateway, sc, true, handler, (timeoutS.coerceAtMost(60)) * 1000)
  }

  private fun softApCopy(code: Int): String = when (code) {
    -1 -> "Faltan datos para pasarle la red a la camara."
    -2 -> "El telefono se unio al hotspot pero la camara no respondio. Vuelve a intentarlo."
    -3 -> "La camara no encuentra la red Wi-Fi «de la casa». Revisa el nombre y que sea de 2.4 GHz."
    else -> "La camara no acepto la red (codigo $code)."
  }

  private fun gatewayOf(cm: ConnectivityManager, network: Network): String? = try {
    cm.getLinkProperties(network)?.routes
      ?.firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }
      ?.gateway?.hostAddress
  } catch (t: Throwable) {
    null
  }

  private fun stopWifiConfig() {
    wifiTimer?.let { main.removeCallbacks(it) }
    wifiTimer = null
    if (!wifiRunning) return
    wifiRunning = false
    runCatching { LCOpenSDK_ConfigWifi.configWifiStop() }
    runCatching { LCOpenSDK_SearchDevices.getInstance().stopSearchDevices() }
    runCatching { LCOpenSDK_SoftAPConfig.cancel() }
    multicastLock?.let { runCatching { if (it.isHeld) it.release() } }
    multicastLock = null
    networkCallback?.let { cb ->
      val cm = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
      runCatching { cm?.bindProcessToNetwork(null) }
      runCatching { cm?.unregisterNetworkCallback(cb) }
    }
    networkCallback = null
  }
}
