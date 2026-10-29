package com.ohmsafe.instalador

import android.app.Application
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.thingclips.smart.android.ble.api.BleConfigType
import com.thingclips.smart.android.ble.api.BleScanResponse
import com.thingclips.smart.android.ble.api.ScanDeviceBean
import com.thingclips.smart.android.ble.api.ScanType
import com.thingclips.smart.home.sdk.ThingHomeSdk
import com.thingclips.smart.home.sdk.builder.ActivatorBuilder
import com.thingclips.smart.sdk.api.ActivatorErrorCode
import com.thingclips.smart.sdk.api.IMultiModeActivator
import com.thingclips.smart.sdk.api.IMultiModeActivatorListener
import com.thingclips.smart.sdk.api.IThingActivator
import com.thingclips.smart.sdk.api.IThingSmartActivatorListener
import com.thingclips.smart.sdk.bean.DeviceBean
import com.thingclips.smart.sdk.bean.MultiModeActivatorBean
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
        stopBleScan()
        stopBleActivator()
        result.success(true)
      }
      "bleScanStart" -> bleScanStart(call, result)
      "bleScanStop" -> {
        stopBleScan()
        result.success(true)
      }
      "pairStartBle" -> pairStartBle(call, result)
      else -> result.notImplemented()
    }
  }

  override fun dispose() {
    stopActivator()
    stopBleScan()
    stopBleActivator()
  }

  // ---------------------------------------------------------------------------
  // Bluetooth + Wi-Fi (2026-10-22). Mismo camino que la app del cliente (escaneo y activacion
  // multimodo), pero con el TOKEN de la casa que da el backend: aqui no hay sesion en Tuya.
  // Solo los equipos «combo» (Bluetooth + Wi-Fi) reciben la red por Bluetooth.
  // ---------------------------------------------------------------------------

  private val bleHandler = Handler(Looper.getMainLooper())
  private val bleDevices = mutableMapOf<String, ScanDeviceBean>()
  private val bleReported = mutableSetOf<String>()
  private var bleScanning = false
  private var bleScanEnd: Runnable? = null
  private var bleActivator: IMultiModeActivator? = null
  private var bleLastUuid: String? = null

  private fun bleScanStart(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error("TUYA_NOT_CONFIGURED", "El SDK de Tuya no esta configurado (bleScanStart).", null)
      return
    }
    val timeoutS = (call.argument<Number>("timeoutS")?.toLong() ?: 20L).coerceIn(5L, 60L)
    if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
      result.error("TUYA_BLE_UNSUPPORTED", "Este telefono no tiene Bluetooth.", null)
      return
    }
    val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    val encendido = try {
      adapter?.isEnabled == true
    } catch (e: SecurityException) {
      result.error("TUYA_BLE_DENIED", "Falta el permiso de Bluetooth.", null)
      return
    }
    events.bleState(encendido)
    if (!encendido) {
      result.error("TUYA_BLE_OFF", "Enciende el Bluetooth del telefono.", null)
      return
    }
    stopBleScan()
    bleReported.clear()
    try {
      ThingHomeSdk.getBleOperator().startLeScan((timeoutS * 1000L).toInt(), ScanType.SINGLE, bleScan)
    } catch (e: SecurityException) {
      result.error("TUYA_BLE_DENIED", "Falta el permiso de Bluetooth.", null)
      return
    } catch (t: Throwable) {
      result.error("TUYA_BLE_UNSUPPORTED", "Este telefono no pudo buscar por Bluetooth (${t.javaClass.simpleName}).", null)
      return
    }
    bleScanning = true
    Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] Bluetooth: buscando $timeoutS s")
    val end = Runnable {
      bleScanEnd = null
      stopBleScan()
      events.bleScanEnd()
    }
    bleScanEnd = end
    bleHandler.postDelayed(end, timeoutS * 1000L)
    result.success(true)
  }

  private val bleScan = BleScanResponse { bean -> bleHandler.post { onBleFound(bean) } }

  private fun onBleFound(bean: ScanDeviceBean?) {
    val uuid = bean?.uuid.orEmpty()
    if (bean == null || uuid.isEmpty()) return
    bleDevices[uuid] = bean
    if (!bleReported.add(uuid)) return
    // Combo = cualquier variante Wi-Fi del SDK (config_type_wifi, ..._plus_ble_first).
    val combo = bean.configType.orEmpty().startsWith(BleConfigType.CONFIG_TYPE_WIFI.type)
    Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] Bluetooth encontrado pid=${bean.productId} combo=$combo")
    events.bleFound(uuid, bean.productId.orEmpty(), bean.mac.orEmpty(), combo, runCatching { bean.rssi }.getOrNull())
  }

  /** Idempotente. */
  private fun stopBleScan() {
    bleScanEnd?.let { bleHandler.removeCallbacks(it) }
    bleScanEnd = null
    if (!bleScanning) return
    bleScanning = false
    runCatching { ThingHomeSdk.getBleOperator().stopLeScan() }
  }

  /**
   * `pairStartBle {uuid, productId, ssid, password, token, homeId, timeoutS}`: el telefono le pasa la
   * red y el token de la casa al equipo por Bluetooth y el equipo se conecta a la Wi-Fi. El exito
   * llega por `pairDone` o, de respaldo, por el sondeo del backend.
   */
  private fun pairStartBle(call: MethodCall, result: MethodChannel.Result) {
    if (!configured) {
      result.error("TUYA_NOT_CONFIGURED", "El SDK de Tuya no esta configurado (pairStartBle).", null)
      return
    }
    val uuid = call.argument<String>("uuid").orEmpty()
    val ssid = call.argument<String>("ssid").orEmpty()
    val password = call.argument<String>("password").orEmpty()
    val token = call.argument<String>("token").orEmpty()
    val productId = call.argument<String>("productId").orEmpty()
    val homeId = call.argument<String>("homeId")?.toLongOrNull() ?: 0L
    val timeoutS = (call.argument<Number>("timeoutS")?.toLong() ?: 120L).coerceIn(30L, 300L)
    val scanned = bleDevices[uuid]
    if (uuid.isEmpty() || ssid.isEmpty() || token.isEmpty() || scanned == null) {
      result.error("TUYA_PAIR_BAD_ARGS", "Falta el equipo, la red o el permiso de la casa.", null)
      return
    }
    stopBleScan()
    stopBleActivator()
    stopActivator()
    val bean = MultiModeActivatorBean().apply {
      this.deviceType = scanned.deviceType
      this.uuid = scanned.uuid
      this.address = scanned.address
      this.mac = scanned.mac
      this.ssid = ssid
      this.pwd = password
      this.token = token
      this.homeId = homeId
      this.timeout = timeoutS * 1000L
      this.productId = productId.ifEmpty { scanned.productId.orEmpty() }
    }
    val multiMode = ThingHomeSdk.getActivator().newMultiModeActivator()
    bleActivator = multiMode
    bleLastUuid = scanned.uuid
    // Nunca la contrasena ni el token en el log.
    Log.i(TuyaPlugin.TAG, "[OhmSafe][Tuya] Bluetooth: activando pid=${bean.productId} ssid ${ssid.length} car., plazo $timeoutS s")
    try {
      multiMode.startActivator(
        bean,
        object : IMultiModeActivatorListener {
          override fun onSuccess(devResp: DeviceBean?) {
            events.pairDone(
              devId = devResp?.devId.orEmpty(),
              name = devResp?.name.orEmpty(),
              productId = devResp?.productId.orEmpty(),
              category = devResp?.category.orEmpty(),
            )
          }

          override fun onFailure(code: Int, msg: String?, handle: Any?) {
            Log.w(TuyaPlugin.TAG, "[OhmSafe][Tuya] Bluetooth onFailure codigo $code")
            events.pairError(
              code = if (code == ActivatorErrorCode.CODE_TIME_OUT) "TUYA_PAIR_TIMEOUT" else "TUYA_PAIR_FAILED",
              message = "${msg ?: "El equipo no termino de conectarse a la red."} · codigo $code",
            )
          }
        },
      )
    } catch (e: SecurityException) {
      bleActivator = null
      result.error("TUYA_BLE_DENIED", "Falta el permiso de Bluetooth.", null)
      return
    } catch (t: Throwable) {
      bleActivator = null
      result.error("TUYA_PAIR_FAILED", "No se pudo iniciar el emparejamiento por Bluetooth (${t.javaClass.simpleName}).", null)
      return
    }
    events.pairProgress("ble_connecting")
    result.success(true)
  }

  /** Idempotente. `stopActivator` pide el uuid. */
  private fun stopBleActivator() {
    val running = bleActivator ?: return
    bleActivator = null
    val uuid = bleLastUuid.orEmpty()
    runCatching { running.stopActivator(uuid) }
  }

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
