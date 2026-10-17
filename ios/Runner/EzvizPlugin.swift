import Flutter
import NetworkExtension
import UIKit
import os.log

#if canImport(EZOpenSDKFramework)
  import EZOpenSDKFramework
#endif

/// Puente con el SDK de EZVIZ para la app de instaladores (2026-10-17).
///
/// Es la versión RECORTADA del `EzvizPlugin.swift` de la app del cliente (CONTRACTS §11.15 C):
/// sólo sesión, sondeo y aprovisionamiento de Wi‑Fi (modo AP u onda de sonido); nada de vídeo,
/// audio ni PTZ. Los nombres de métodos, eventos y códigos `EZVIZ_*` son los mismos para que un
/// arreglo en una app se pueda llevar a la otra.
///
/// Tres promesas que no son opcionales:
///  1. NUNCA se registra ni el token, ni el código de la etiqueta, ni la contraseña de la Wi‑Fi.
///  2. Se contesta UNA sola vez por llamada, en el hilo principal y con plazo (el SDK contesta
///     desde hilos de red y hay rutas en las que no contesta).
///  3. Al parar siempre se devuelve el teléfono a su red (se quita la configuración del hotspot).
private let ezvizLogger = OSLog(subsystem: "com.ohmsafe.instalador", category: "ezviz")
func ezvizLog(_ message: String) {
  os_log("%{public}@", log: ezvizLogger, type: .default, message)
}

enum EzvizErrors {
  static let notLinked = "EZVIZ_NOT_LINKED"
  static let notConfigured = "EZVIZ_NOT_CONFIGURED"
  static let noSession = "EZVIZ_NO_SESSION"
  static let tokenExpired = "EZVIZ_TOKEN_EXPIRED"
  static let wifiTimeout = "EZVIZ_WIFI_TIMEOUT"
  static let wifiFailed = "EZVIZ_WIFI_FAILED"
  static let unsupported = "EZVIZ_UNSUPPORTED"
  static let timeout = "EZVIZ_TIMEOUT"
}

public class EzvizPlugin: NSObject, FlutterPlugin {
  public static let channelName = "ohmsafe/ezviz"
  public static let eventChannelName = "ohmsafe/ezviz/events"

  private var channel: FlutterMethodChannel?
  private let events = EzvizEventSink()
  private lazy var bridge: EzvizBridge = makeEzvizBridge(events: events)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = EzvizPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance.events)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let safe = EzvizSafeResult(method: call.method, serial: args["serial"] as? String, inner: result)
    bridge.handle(method: call.method, args: args, result: safe.callback)
  }
}

// MARK: - Respuesta con plazo

final class EzvizSafeResult {
  private let inner: FlutterResult
  private let lock = NSLock()
  private var done = false
  private var timeoutItem: DispatchWorkItem?

  init(method: String, serial: String?, inner: @escaping FlutterResult) {
    self.inner = inner
    let code = Self.timeoutCodeFor(method)
    let item = DispatchWorkItem { [self] in
      finish(FlutterError(code: code, message: "La cámara no respondió. Revisa que tenga corriente.", details: EzvizDetails.of(serial: serial)))
    }
    timeoutItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutFor(method), execute: item)
  }

  var callback: FlutterResult {
    return { value in self.finish(value) }
  }

  private func finish(_ value: Any?) {
    lock.lock()
    if done {
      lock.unlock()
      return
    }
    done = true
    let item = timeoutItem
    timeoutItem = nil
    lock.unlock()
    item?.cancel()
    if Thread.isMainThread { inner(value) } else { DispatchQueue.main.async { self.inner(value) } }
  }

  private static func timeoutCodeFor(_ method: String) -> String {
    switch method {
    case "wifiConfigStart", "wifiConfigStop": return EzvizErrors.wifiTimeout
    default: return EzvizErrors.timeout
    }
  }

  private static func timeoutFor(_ method: String) -> TimeInterval {
    switch method {
    case "setSession", "probe": return 25
    // Sólo arranca el proceso (el progreso va por eventos): unirse al hotspot es lo que tarda.
    case "wifiConfigStart": return 40
    default: return 15
    }
  }
}

enum EzvizDetails {
  static func of(serial: String?, providerCode: Int? = nil) -> [String: Any] {
    var out: [String: Any] = [:]
    if let serial = serial, !serial.isEmpty { out["serial"] = serial }
    if let providerCode = providerCode { out["providerCode"] = providerCode }
    return out
  }
}

// MARK: - Canal de eventos

final class EzvizEventSink: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func send(_ payload: [String: Any]) {
    if Thread.isMainThread { sink?(payload) } else { DispatchQueue.main.async { [weak self] in self?.sink?(payload) } }
  }

  /// `wifiConfig {serial, step, status:'progress'|'done'|'error', code?, message?, error?}`.
  /// Mismos nombres de paso que Android (`start`, `joining_hotspot`, `joined_hotspot`,
  /// `sending_config`, `connecting_to_wifi`, `connected_to_wifi`, `registered`, `failed`, `timeout`).
  func wifiConfig(serial: String, step: String, status: String, code: Int? = nil, message: String? = nil, error: String? = nil) {
    var payload: [String: Any] = ["type": "wifiConfig", "serial": serial, "step": step, "status": status]
    if let code = code { payload["code"] = code }
    if let message = message { payload["message"] = message }
    if let error = error { payload["error"] = error }
    send(payload)
  }

  func deviceOnline(serial: String, online: Bool) {
    send(["type": "deviceOnline", "serial": serial, "online": online])
  }
}

protocol EzvizBridge: AnyObject {
  func handle(method: String, args: [String: Any], result: @escaping FlutterResult)
}

func ezvizOnMain(_ block: @escaping () -> Void) {
  if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
}

func ezvizIntArg(_ value: Any?, _ fallback: Int = 0) -> Int {
  if let number = value as? NSNumber { return number.intValue }
  if let text = value as? String { return Int(text) ?? fallback }
  return fallback
}

func ezvizStringArg(_ value: Any?) -> String? {
  guard let value = value, !(value is NSNull) else { return nil }
  if let text = value as? String { return text.isEmpty ? nil : text }
  return "\(value)"
}

/// Red Wi‑Fi actual del teléfono (iOS 14+, con «Access WiFi Information» y ubicación concedida).
func ezvizCurrentSsid(_ done: @escaping (String?) -> Void) {
  NEHotspotNetwork.fetchCurrent { network in
    ezvizOnMain { done(network?.ssid) }
  }
}

// MARK: - Sin SDK (compilación con OHMSAFE_EZVIZ=0, p. ej. simulador de Apple silicon)

#if !canImport(EZOpenSDKFramework)

  func makeEzvizBridge(events: EzvizEventSink) -> EzvizBridge {
    return EzvizBridgeUnavailable()
  }

  final class EzvizBridgeUnavailable: EzvizBridge {
    func handle(method: String, args: [String: Any], result: @escaping FlutterResult) {
      if method == "currentSsid" {
        ezvizCurrentSsid { result($0) }
        return
      }
      result(FlutterError(code: EzvizErrors.notLinked, message: "El SDK de EZVIZ no está enlazado en esta compilación (\(method)).", details: EzvizDetails.of(serial: args["serial"] as? String)))
    }
  }

#endif

// MARK: - Con SDK

#if canImport(EZOpenSDKFramework)

  func makeEzvizBridge(events: EzvizEventSink) -> EzvizBridge {
    return EzvizBridgeImpl(events: events)
  }

  final class EzvizBridgeImpl: EzvizBridge {
    private let events: EzvizEventSink
    private var configured = false
    private var configuredAppKey: String?
    private var hasSession = false
    /// Aprovisionamiento en curso (sólo uno a la vez, como el SDK).
    private var wifiSerial: String?
    private var wifiMode: String?
    private var wifiHotspotSsid: String?
    private var wifiDeadline: DispatchWorkItem?

    init(events: EzvizEventSink) {
      self.events = events
    }

    func handle(method: String, args: [String: Any], result: @escaping FlutterResult) {
      let serial = ezvizStringArg(args["serial"]) ?? ""
      switch method {
      case "configure": configure(args, result)
      case "setSession": setSession(args, result)
      case "logout": logout(result)
      case "probe": probe(serial: serial, result)
      case "wifiConfigStart": wifiConfigStart(args, result)
      case "wifiConfigStop": wifiConfigStop(result)
      case "currentSsid": ezvizCurrentSsid { result($0) }
      default: result(FlutterMethodNotImplemented)
      }
    }

    // MARK: Sesión

    /// `configure {appKey, areaDomain, region}`. Siempre la forma de tres argumentos: la de uno
    /// apunta a la plataforma de China.
    private func configure(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard let appKey = ezvizStringArg(args["appKey"]) else {
        result(FlutterError(code: EzvizErrors.notConfigured, message: "Falta la llave pública de EZVIZ.", details: nil))
        return
      }
      let areaDomain = ezvizStringArg(args["areaDomain"]) ?? Self.defaultAreaDomain
      let authUrl = ezvizStringArg(args["authUrl"]) ?? Self.authUrl(for: areaDomain)
      let region = ezvizStringArg(args["region"]) ?? "na"
      if configured, configuredAppKey == appKey {
        result(true)
        return
      }
      if configured { hasSession = false }
      EZGlobalSDK.setDebugLogEnable(false)
      EZGlobalSDK.setDebugStreamEnable(false)
      let ok = EZGlobalSDK.initLib(withAppKey: appKey, url: areaDomain, authUrl: authUrl)
      ezvizLog("[OhmSafe][EZVIZ] configure región \(region) · api \(areaDomain) · initLib \(ok ? "ok" : "falló") · SDK \(EZGlobalSDK.getVersion())")
      guard ok else {
        result(FlutterError(code: EzvizErrors.notConfigured, message: "El SDK de EZVIZ no arrancó con esta llave.", details: nil))
        return
      }
      configured = true
      configuredAppKey = appKey
      result(true)
    }

    /// `setSession {accessToken, expiresAt}`: se valida con `getDeviceList(0, 1)`, la prueba que
    /// documenta el fabricante.
    private func setSession(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard configured else {
        result(notConfigured("setSession"))
        return
      }
      guard let token = ezvizStringArg(args["accessToken"]) else {
        result(FlutterError(code: EzvizErrors.noSession, message: "No llegó la sesión del proveedor de cámaras.", details: nil))
        return
      }
      EZGlobalSDK.setAccessToken(token)
      EZGlobalSDK.getDeviceList(0, pageSize: 1) { [weak self] _, total, error in
        guard let self = self else { return }
        if let ns = error as NSError? {
          self.hasSession = false
          ezvizLog("[OhmSafe][EZVIZ] setSession rechazado · código \(ns.code)")
          let expired = ns.code == 110002 || ns.code == 110003
          result(FlutterError(
            code: expired ? EzvizErrors.tokenExpired : EzvizErrors.noSession,
            message: expired ? "La sesión con el proveedor de cámaras caducó." : "El proveedor de cámaras no aceptó la sesión (código \(ns.code)).",
            details: EzvizDetails.of(serial: nil, providerCode: ns.code)))
          return
        }
        self.hasSession = true
        ezvizLog("[OhmSafe][EZVIZ] setSession ok · \(total) cámara(s) en la cuenta de la casa")
        result(true)
      }
    }

    private func logout(_ result: @escaping FlutterResult) {
      guard configured else {
        result(true)
        return
      }
      stopWifiWork()
      EZGlobalSDK.logout { [weak self] error in
        self?.hasSession = false
        if let ns = error as NSError? { ezvizLog("[OhmSafe][EZVIZ] logout con aviso · código \(ns.code)") }
        result(true)
      }
    }

    // MARK: Sondeo

    /// `probe {serial}` → `{state, code, …}` con el MISMO vocabulario que el backend.
    private func probe(serial: String, _ result: @escaping FlutterResult) {
      guard configured else {
        result(notConfigured("probe"))
        return
      }
      guard !serial.isEmpty else {
        result(FlutterError(code: EzvizErrors.unsupported, message: "Falta el número de serie de la cámara.", details: nil))
        return
      }
      // `deviceType:nil` pasa por el puente de Objective-C de `Runner-Bridging-Header.h`.
      _ = OhmSafeEzvizProbeDeviceInfo(serial) { [weak self] info, error in
        guard let self = self else { return }
        if let ns = error as NSError? {
          let code = ns.code
          if code == 110002 || code == 110003 {
            result(FlutterError(code: EzvizErrors.tokenExpired, message: "La sesión con el proveedor de cámaras caducó.", details: EzvizDetails.of(serial: serial, providerCode: code)))
            return
          }
          let state = Self.probeState(for: code)
          ezvizLog("[OhmSafe][EZVIZ] probe \(serial) → \(state) · código \(code)")
          result(["state": state, "code": code])
          return
        }
        guard let info = info else {
          result(["state": "not_found", "code": 0])
          return
        }
        let online = info.status == 1
        self.events.deviceOnline(serial: serial, online: online)
        var payload: [String: Any] = [
          "state": online ? "online_unbound" : "offline",
          "code": 0,
          "online": online,
          "supportAP": info.supportAP,
          "supportAPType": info.supportAPType,
          "supportWifi": info.supportWifi,
          "supportSoundWave": info.supportSoundWave,
          "support5GWiFi": info.support5GWiFi,
          "deviceHotSpot": info.deviceHotSpot,
        ]
        if let model = info.model, !model.isEmpty { payload["model"] = model }
        ezvizLog("[OhmSafe][EZVIZ] probe \(serial) → \(online ? "en línea" : "fuera de línea") · AP \(info.supportAP) · onda \(info.supportSoundWave) · hotspot \(info.deviceHotSpot)")
        result(payload)
      }
    }

    static func probeState(for code: Int) -> String {
      switch code {
      case 120017, 120020: return "bound_here"
      case 120021: return "online_unbound"
      case 120022, 120024, 120031, 106002: return "bound_elsewhere"
      case 120007, 120023, 120029: return "offline"
      default: return "not_found"
      }
    }

    // MARK: Wi‑Fi

    /// `wifiConfigStart {mode:'ap'|'wave', serial, verifyCode, ssid, password, hotspotPrefix, timeoutS}`.
    /// En modo AP el teléfono se une al punto de acceso de la cámara (`EZVIZ_<serie>`) y le manda
    /// la red de la casa. Nada de esto se registra.
    private func wifiConfigStart(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard configured else {
        result(notConfigured("wifiConfigStart"))
        return
      }
      guard let serial = ezvizStringArg(args["serial"]), let ssid = ezvizStringArg(args["ssid"]), let verifyCode = ezvizStringArg(args["verifyCode"]) else {
        result(FlutterError(code: EzvizErrors.wifiFailed, message: "Faltan datos para configurar la cámara (red, serie o código de la etiqueta).", details: EzvizDetails.of(serial: ezvizStringArg(args["serial"]), providerCode: 105)))
        return
      }
      let password = ezvizStringArg(args["password"]) ?? ""
      let mode = (ezvizStringArg(args["mode"]) ?? "ap").lowercased()
      let timeoutS = max(30, ezvizIntArg(args["timeoutS"], 100))
      let hotspotPrefix = ezvizStringArg(args["hotspotPrefix"]) ?? "EZVIZ"

      if wifiSerial != nil { stopWifiWork() }
      wifiSerial = serial
      wifiMode = mode
      ezvizLog("[OhmSafe][EZVIZ] wifiConfig \(serial): arranca en modo \(mode), tope \(timeoutS) s")
      events.wifiConfig(serial: serial, step: "start", status: "progress")

      let deadline = DispatchWorkItem { [weak self] in
        guard let self = self, self.wifiSerial == serial else { return }
        ezvizLog("[OhmSafe][EZVIZ] wifiConfig \(serial): se agotó el tiempo")
        self.stopWifiWork()
        self.events.wifiConfig(serial: serial, step: "timeout", status: "error", code: 15, message: Self.wifiCopy(15), error: EzvizErrors.wifiTimeout)
      }
      wifiDeadline = deadline
      DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(timeoutS), execute: deadline)

      let statusBlock: (EZWifiConfigStatus, String?) -> Void = { [weak self] status, reported in
        self?.onWifiStatus(status: status.rawValue, serial: reported ?? serial)
      }

      if mode == "wave" {
        let started = EZGlobalSDK.startConfigWifi(ssid, password: password, deviceSerial: serial, mode: 1 | 2, deviceStatus: statusBlock)
        guard started else {
          stopWifiWork()
          result(FlutterError(code: EzvizErrors.wifiFailed, message: "No se pudo empezar la configuración de la cámara.", details: EzvizDetails.of(serial: serial, providerCode: 110)))
          return
        }
        result(true)
        return
      }

      // Modo AP: el SDK NO enlaza NetworkExtension, se une la app.
      let hotspotSsid = "\(hotspotPrefix)_\(serial)"
      let hotspotPassword = "\(hotspotPrefix)_\(verifyCode)"
      wifiHotspotSsid = hotspotSsid
      events.wifiConfig(serial: serial, step: "joining_hotspot", status: "progress")
      joinHotspot(ssid: hotspotSsid, password: hotspotPassword) { [weak self] problem in
        guard let self = self, self.wifiSerial == serial else { return }
        if let problem = problem {
          ezvizLog("[OhmSafe][EZVIZ] wifiConfig \(serial): no se pudo unir al punto de acceso · \(problem)")
          self.stopWifiWork()
          self.events.wifiConfig(serial: serial, step: "failed", status: "error", code: problem, message: Self.wifiCopy(problem), error: EzvizErrors.wifiFailed)
          return
        }
        self.events.wifiConfig(serial: serial, step: "joined_hotspot", status: "progress")
        let started = EZGlobalSDK.startAPConfigWifi(withSsid: ssid, password: password, deviceSerial: serial, verifyCode: verifyCode, deviceStatus: statusBlock)
        guard started else {
          self.stopWifiWork()
          self.events.wifiConfig(serial: serial, step: "failed", status: "error", code: 505, message: Self.wifiCopy(505), error: EzvizErrors.wifiFailed)
          return
        }
        self.events.wifiConfig(serial: serial, step: "sending_config", status: "progress")
      }
      result(true)
    }

    /// Estados de iOS → los mismos nombres de paso que Android.
    private func onWifiStatus(status: Int, serial: String) {
      guard wifiSerial == serial else { return }
      switch status {
      case 1: events.wifiConfig(serial: serial, step: "connecting_to_wifi", status: "progress", code: status)
      case 2: events.wifiConfig(serial: serial, step: "connected_to_wifi", status: "progress", code: status)
      case 5: events.wifiConfig(serial: serial, step: "sending_config", status: "progress", code: status)
      case 3:  // DEVICE_PLATFORM_REGISTED: el único éxito de verdad
        ezvizLog("[OhmSafe][EZVIZ] wifiConfig \(serial): la cámara ya llegó a la nube")
        stopWifiWork()
        events.wifiConfig(serial: serial, step: "registered", status: "done", code: status)
        events.deviceOnline(serial: serial, online: true)
      case 6:  // DEVICE_WIFI_SENT_FAILED
        stopWifiWork()
        events.wifiConfig(serial: serial, step: "failed", status: "error", code: status, message: "La cámara no recibió los datos de la Wi‑Fi. Acércate a ella y vuelve a intentarlo.", error: EzvizErrors.wifiFailed)
      case 7:  // DEVICE_PLATFORM_REGIST_FAILED
        stopWifiWork()
        events.wifiConfig(serial: serial, step: "failed", status: "error", code: status, message: Self.wifiCopy(15), error: EzvizErrors.wifiFailed)
      default: events.wifiConfig(serial: serial, step: "progress", status: "progress", code: status)
      }
    }

    static func wifiCopy(_ code: Int) -> String {
      switch code {
      case 505: return "La cámara no está en modo de configuración: mantén RESET 10–15 s."
      case 120: return "El código de la etiqueta no es correcto."
      case 111, 605: return "El teléfono no está en la red Wi‑Fi de la casa."
      case 501: return "Falta el permiso de ubicación."
      case 15: return "La cámara se conectó pero no llegó a internet: revisa la contraseña de la Wi‑Fi y que sea de 2.4 GHz."
      case 506: return "Se rechazó la conexión a la red de la cámara."
      case 110, 502: return "Ya hay una configuración en marcha."
      default: return "La cámara no terminó de conectarse a la red (código \(code))."
      }
    }

    private func wifiConfigStop(_ result: @escaping FlutterResult) {
      if let serial = wifiSerial { ezvizLog("[OhmSafe][EZVIZ] wifiConfig \(serial): cancelado por la app") }
      stopWifiWork()
      result(true)
    }

    /// Para el SDK, cancela el plazo y devuelve el teléfono a su red.
    private func stopWifiWork() {
      wifiDeadline?.cancel()
      wifiDeadline = nil
      if wifiMode == "wave" { _ = EZGlobalSDK.stopConfigWifi() } else { EZGlobalSDK.stopAPConfigWifi() }
      if let hotspot = wifiHotspotSsid {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: hotspot)
      }
      wifiHotspotSsid = nil
      wifiSerial = nil
      wifiMode = nil
    }

    /// Une el teléfono al punto de acceso de la cámara. Los números son los del catálogo de la
    /// app del cliente (§11.15 D) para que el copy valga en las dos plataformas.
    private func joinHotspot(ssid: String, password: String, _ done: @escaping (Int?) -> Void) {
      let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
      config.joinOnce = true
      NEHotspotConfigurationManager.shared.apply(config) { error in
        ezvizOnMain {
          guard let ns = error as NSError? else {
            // `apply` puede contestar sin error mientras iOS enseña «No se pudo conectar»: se
            // comprueba la red real antes de dar por unido el teléfono.
            self.verifyJoined(ssid: ssid, attemptsLeft: 12, done)
            return
          }
          switch NEHotspotConfigurationError(rawValue: ns.code) {
          case .alreadyAssociated: self.verifyJoined(ssid: ssid, attemptsLeft: 4, done)
          case .userDenied: done(506)
          case .invalidWPAPassphrase, .invalid, .invalidSSID: done(120)
          default: done(505)
          }
        }
      }
    }

    private func verifyJoined(ssid: String, attemptsLeft: Int, _ done: @escaping (Int?) -> Void) {
      NEHotspotNetwork.fetchCurrent { network in
        ezvizOnMain {
          let current = network?.ssid ?? ""
          if current == ssid {
            done(nil)
            return
          }
          if network == nil || current.isEmpty {
            // Sin permiso de ubicación no se puede saber: no se inventa un fallo.
            ezvizLog("[OhmSafe][EZVIZ] wifiConfig: no se pudo leer la SSID actual; se sigue")
            done(nil)
            return
          }
          if attemptsLeft <= 0 {
            ezvizLog("[OhmSafe][EZVIZ] wifiConfig: el teléfono sigue en «\(current)», no en \(ssid)")
            NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
            done(505)
            return
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verifyJoined(ssid: ssid, attemptsLeft: attemptsLeft - 1, done)
          }
        }
      }
    }

    // MARK: Utilidades

    private func notConfigured(_ method: String) -> FlutterError {
      FlutterError(code: EzvizErrors.notConfigured, message: "El SDK de EZVIZ no se ha configurado en esta sesión (\(method)).", details: nil)
    }

    static let defaultAreaDomain = "https://iusopen.ezvizlife.com"

    /// `iusopen.ezvizlife.com` → `iusopenauth.ezvizlife.com` (tabla oficial de áreas).
    static func authUrl(for areaDomain: String) -> String {
      guard let range = areaDomain.range(of: "open") else { return areaDomain }
      return areaDomain.replacingCharacters(in: range, with: "openauth")
    }
  }

#endif
