import Flutter
import NetworkExtension
import UIKit
import os.log

#if canImport(ThingSmartHomeKit)
  import ThingSmartHomeKit
#endif
#if canImport(ThingSmartBLEKit)
  import ThingSmartBLEKit
#endif

/// Puente con el Smart Life App SDK de Tuya para la app de instaladores (2026-10-17).
///
/// Versión RECORTADA del `TuyaIpcPlugin.swift` de la app del cliente: sólo `configure` y el
/// emparejamiento Wi‑Fi (EZ / AP) con un **token de nube** que da el backend. Esta app NUNCA inicia
/// sesión en Tuya (cada app tiene su propio schema de usuarios; la cuenta de la casa vive en el de
/// GO): el SDK sólo transmite la red y el token al equipo, y el equipo queda en la cuenta de la casa.
///
/// Promesas: nunca se registran el AppSecret, el token ni la contraseña de la Wi‑Fi; se contesta una
/// vez por llamada y con plazo. Sin el pod (`ThingSmartCryption` fuera del repo) todo contesta
/// `TUYA_NOT_LINKED`.
private let tuyaLogger = OSLog(subsystem: "com.ohmsafe.instalador", category: "tuya")
func tuyaLog(_ message: String) {
  os_log("%{public}@", log: tuyaLogger, type: .default, message)
}

public class TuyaPlugin: NSObject, FlutterPlugin {
  public static let channelName = "ohmsafe/tuya"
  public static let eventChannelName = "ohmsafe/tuya/events"

  private let events = TuyaEventSink()
  private lazy var bridge: TuyaBridge = makeTuyaBridge(events: events)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TuyaPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance.events)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Modo punto de acceso (2026-10-22): iOS no deja abrir Ajustes › Wi‑Fi directo; se abren los ajustes
    // de la app y la pantalla le dice al instalador que vaya a Wi‑Fi.
    if call.method == "openWifiSettings" {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
      } else {
        result(false)
      }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let safe = TuyaSafeResult(method: call.method, inner: result)
    bridge.handle(method: call.method, args: args, result: safe.callback)
  }
}

/// Una sola respuesta, en el hilo principal y con plazo.
final class TuyaSafeResult {
  private let inner: FlutterResult
  private let lock = NSLock()
  private var done = false
  private var timeoutItem: DispatchWorkItem?

  init(method: String, inner: @escaping FlutterResult) {
    self.inner = inner
    let item = DispatchWorkItem { [self] in
      finish(FlutterError(code: "TUYA_TIMEOUT", message: "El SDK de Tuya no respondió (\(method)).", details: nil))
    }
    timeoutItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + (method == "pairStart" || method == "pairStartBle" ? 30 : 15), execute: item)
  }

  var callback: FlutterResult { return { value in self.finish(value) } }

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
}

/// `pairProgress {step}` · `pairDone {devId, name, productId, category}` · `pairError {code, message}`.
/// Mismos nombres que la app del cliente.
final class TuyaEventSink: NSObject, FlutterStreamHandler {
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

  func pairProgress(_ step: String) { send(["type": "pairProgress", "step": step]) }
  func pairDone(devId: String, name: String, productId: String, category: String) {
    send(["type": "pairDone", "devId": devId, "name": name, "productId": productId, "category": category])
  }
  func pairError(code: String, message: String) { send(["type": "pairError", "code": code, "message": message]) }

  // Bluetooth (2026-10-22): `bleFound {uuid, productId, mac, combo, rssi?}` · `bleScanEnd` · `bleState {poweredOn}`.
  func bleFound(uuid: String, productId: String, mac: String, combo: Bool, rssi: Int?) {
    var payload: [String: Any] = ["type": "bleFound", "uuid": uuid, "productId": productId, "mac": mac, "combo": combo]
    if let rssi = rssi, rssi < 0 { payload["rssi"] = rssi }
    send(payload)
  }
  func bleScanEnd() { send(["type": "bleScanEnd"]) }
  func bleState(poweredOn: Bool) { send(["type": "bleState", "poweredOn": poweredOn]) }
}

protocol TuyaBridge: AnyObject {
  func handle(method: String, args: [String: Any], result: @escaping FlutterResult)
}

func tuyaCurrentSsid(_ done: @escaping (String?) -> Void) {
  NEHotspotNetwork.fetchCurrent { network in
    DispatchQueue.main.async { done(network?.ssid) }
  }
}

#if !canImport(ThingSmartHomeKit)

  func makeTuyaBridge(events: TuyaEventSink) -> TuyaBridge { return TuyaBridgeUnavailable() }

  final class TuyaBridgeUnavailable: TuyaBridge {
    func handle(method: String, args: [String: Any], result: @escaping FlutterResult) {
      if method == "currentSsid" {
        tuyaCurrentSsid { result($0) }
        return
      }
      result(FlutterError(code: "TUYA_NOT_LINKED", message: "El SDK de Tuya no está enlazado en esta compilación (\(method)).", details: nil))
    }
  }

#else

  func makeTuyaBridge(events: TuyaEventSink) -> TuyaBridge { return TuyaBridgeImpl(events: events) }

  /// Delegado del activador. Vive aparte para poder soltarlo entero en `pairCancel`.
  final class TuyaPairing: NSObject, ThingSmartActivatorDelegate {
    let activator = ThingSmartActivator()
    private weak var events: TuyaEventSink?
    private var finished = false

    init(events: TuyaEventSink) {
      self.events = events
      super.init()
      activator.delegate = self
    }

    func stop() {
      activator.stopConfigWiFi()
      activator.delegate = nil
    }

    func activator(_ activator: ThingSmartActivator, didReceiveDevice deviceModel: ThingSmartDeviceModel?, error: Error?) {
      if let error = error {
        let ns = error as NSError
        // Sin sesión el SDK puede quejarse aunque el equipo sí haya entrado: el lado Dart lo
        // confirma con el backend, así que esto es un aviso, no un veredicto.
        tuyaLog("[OhmSafe][Tuya] pairing error · código \(ns.code)")
        events?.pairError(code: "TUYA_PAIR_FAILED", message: "\(error.localizedDescription) · código \(ns.code)")
        return
      }
      guard let device = deviceModel, !finished else { return }
      finished = true
      tuyaLog("[OhmSafe][Tuya] pairing done · producto \(device.productId ?? "?")")
      events?.pairDone(devId: device.devId ?? "", name: device.name ?? "", productId: device.productId ?? "", category: device.category ?? "")
    }

    func activator(_ activator: ThingSmartActivator, didReceiveDevice deviceModel: ThingSmartDeviceModel?, step: ThingActivatorStep, error: Error?) {
      switch step {
      case .found: events?.pairProgress("found")
      case .registed: events?.pairProgress("registered")
      case .intialized: events?.pairProgress("initialized")
      case .timeOut: events?.pairError(code: "TUYA_PAIR_TIMEOUT", message: "El SDK de Tuya agotó el plazo sin ver el equipo en la nube")
      default: events?.pairProgress("step_\(step.rawValue)")
      }
    }
  }

  /// Búsqueda por Bluetooth (2026-10-22, igual que la app del cliente). El delegado del
  /// `ThingSmartBLEManager` es `weak`: este objeto lo sostiene mientras dura la búsqueda.
  final class TuyaBleScanner: NSObject, ThingSmartBLEManagerDelegate {
    private weak var events: TuyaEventSink?
    private var seen: Set<String> = []
    private var timeoutItem: DispatchWorkItem?
    private var listening = false

    /// `bleType` de los equipos Bluetooth + Wi‑Fi (los únicos que reciben la red así): BLEWifi = 4,
    /// BLEWifiSecurity = 6, BLEWifiPlugPlay = 7, BLEWifiPriorBLE = 11 (ThingBLEAdvModel.h).
    private static let comboBleTypes: Set<UInt> = [4, 6, 7, 11]

    init(events: TuyaEventSink) {
      self.events = events
      super.init()
    }

    func start(timeoutS: Int) {
      stop()
      seen.removeAll()
      let manager = ThingSmartBLEManager.sharedInstance()
      manager.delegate = self
      manager.startListening(true)
      listening = true
      tuyaLog("[OhmSafe][Tuya] Bluetooth: buscando \(timeoutS) s")
      let item = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        self.stop()
        self.events?.bleScanEnd()
      }
      timeoutItem = item
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(max(1, timeoutS)), execute: item)
    }

    /// Idempotente. `false` = conservar la caché de anuncios: la activación busca el equipo ahí.
    func stop() {
      timeoutItem?.cancel()
      timeoutItem = nil
      guard listening else { return }
      listening = false
      let manager = ThingSmartBLEManager.sharedInstance()
      manager.stopListening(false)
      if manager.delegate === self { manager.delegate = nil }
    }

    func bluetoothDidUpdateState(_ isPoweredOn: Bool) {
      events?.bleState(poweredOn: isPoweredOn)
    }

    func didDiscoveryDevice(withDeviceInfo deviceInfo: ThingBLEAdvModel) {
      let uuid = deviceInfo.uuid ?? ""
      guard !uuid.isEmpty, listening, seen.insert(uuid).inserted else { return }
      let combo = Self.comboBleTypes.contains(UInt(deviceInfo.bleType.rawValue))
      tuyaLog("[OhmSafe][Tuya] Bluetooth encontrado · producto \(deviceInfo.productId ?? "?") · combo=\(combo)")
      events?.bleFound(uuid: uuid, productId: deviceInfo.productId ?? "", mac: deviceInfo.mac ?? "", combo: combo, rssi: deviceInfo.peripheral?.rssi)
    }
  }

  /// Activación Bluetooth + Wi‑Fi con el TOKEN de la casa (`pairDeviceWithUUID:token:…`): sin sesión
  /// en Tuya. El resultado llega por el delegado (también `weak`); `finished` evita dobles avisos.
  final class TuyaBlePairing: NSObject, ThingSmartBLEWifiActivatorDelegate {
    private weak var events: TuyaEventSink?
    private var finished = false

    init(events: TuyaEventSink) {
      self.events = events
      super.init()
    }

    func start(uuid: String, token: String, ssid: String, password: String, timeoutS: Int) {
      let activator = ThingSmartBLEWifiActivator.sharedInstance()
      activator.bleWifiDelegate = self
      // Sin secretos: longitudes, nunca la contraseña ni el token.
      tuyaLog("[OhmSafe][Tuya] Bluetooth: activando · ssid \(ssid.count) car. · plazo \(timeoutS) s")
      activator.pairDevice(withUUID: uuid, token: token, ssid: ssid, pwd: password, timeout: timeoutS)
      events?.pairProgress("ble_connecting")
    }

    func stop() {
      finished = true
      let activator = ThingSmartBLEWifiActivator.sharedInstance()
      activator.stopDiscover()
      if activator.bleWifiDelegate === self { activator.bleWifiDelegate = nil }
    }

    func bleWifiActivator(_ activator: ThingSmartBLEWifiActivator, didReceiveBLEWifiConfigDevice deviceModel: ThingSmartDeviceModel?, error: Error?) {
      DispatchQueue.main.async { [weak self] in
        guard let self = self, !self.finished else { return }
        if let error = error {
          let ns = error as NSError
          tuyaLog("[OhmSafe][Tuya] Bluetooth error · código \(ns.code)")
          self.events?.pairError(code: "TUYA_PAIR_FAILED", message: "\(error.localizedDescription) · código \(ns.code)")
          return
        }
        guard let device = deviceModel else { return }
        self.finished = true
        self.events?.pairDone(devId: device.devId ?? "", name: device.name ?? "", productId: device.productId ?? "", category: device.category ?? "")
      }
    }

    func bleWifiActivator(_ activator: ThingSmartBLEWifiActivator, notConfigStateWithError error: Error) {
      let ns = error as NSError
      DispatchQueue.main.async { [weak self] in
        self?.events?.pairError(code: "TUYA_PAIR_FAILED", message: "El equipo no está en modo de emparejamiento · código \(ns.code)")
      }
    }
  }

  final class TuyaBridgeImpl: TuyaBridge {
    private let events: TuyaEventSink
    private var configured = false
    private var pairing: TuyaPairing?
    private var bleScanner: TuyaBleScanner?
    private var blePairing: TuyaBlePairing?

    init(events: TuyaEventSink) { self.events = events }

    func handle(method: String, args: [String: Any], result: @escaping FlutterResult) {
      switch method {
      case "configure": configure(args, result)
      case "pairStart": pairStart(args, result)
      case "pairCancel":
        pairing?.stop()
        pairing = nil
        bleScanner?.stop()
        bleScanner = nil
        blePairing?.stop()
        blePairing = nil
        result(true)
      case "bleScanStart": bleScanStart(args, result)
      case "bleScanStop":
        bleScanner?.stop()
        result(true)
      case "pairStartBle": pairStartBle(args, result)
      case "currentSsid": tuyaCurrentSsid { result($0) }
      default: result(FlutterMethodNotImplemented)
      }
    }

    /// `configure {appKey, appSecret}` → `ThingSmartSDK.start`. Las llaves llegan por dart-define.
    private func configure(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard let appKey = args["appKey"] as? String, !appKey.isEmpty, let appSecret = args["appSecret"] as? String, !appSecret.isEmpty else {
        result(FlutterError(code: "TUYA_NO_KEYS", message: "Faltan las llaves de Tuya en esta compilación.", details: nil))
        return
      }
      if !configured {
        ThingSmartSDK.sharedInstance().start(withAppKey: appKey, secretKey: appSecret)
        configured = true
        tuyaLog("[OhmSafe][Tuya] SDK iniciado")
      }
      result(true)
    }

    /// `pairStart {mode:'EZ'|'AP', ssid, password, token, timeoutS}`: el token (región+token+secreto)
    /// lo dio el backend para la cuenta de la casa; aquí NO se pide a Tuya ni se inicia sesión.
    private func pairStart(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard configured else {
        result(FlutterError(code: "TUYA_NOT_CONFIGURED", message: "El SDK de Tuya no está configurado (pairStart).", details: nil))
        return
      }
      let ssid = args["ssid"] as? String ?? ""
      let password = args["password"] as? String ?? ""
      let token = args["token"] as? String ?? ""
      let modeText = (args["mode"] as? String ?? "EZ").uppercased()
      let timeoutS = (args["timeoutS"] as? NSNumber)?.doubleValue ?? 120
      guard !ssid.isEmpty, !token.isEmpty else {
        result(FlutterError(code: "TUYA_PAIR_BAD_ARGS", message: "Falta el nombre de la red Wi‑Fi o el permiso de la casa.", details: nil))
        return
      }
      let mode: ThingActivatorMode = modeText == "AP" ? .AP : .EZ
      pairing?.stop()
      let session = TuyaPairing(events: events)
      pairing = session
      tuyaLog("[OhmSafe][Tuya] emparejamiento \(modeText): ssid \(ssid.count) car., plazo \(Int(timeoutS)) s")
      session.activator.startConfigWiFi(mode, ssid: ssid, password: password, token: token, timeout: timeoutS)
      events.pairProgress(mode == .AP ? "ap_waiting" : "ez_waiting")
      result(true)
    }

    /// `bleScanStart {timeoutS}`: el sistema pregunta por el Bluetooth la primera vez (Info.plist).
    private func bleScanStart(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard configured else {
        result(FlutterError(code: "TUYA_NOT_CONFIGURED", message: "El SDK de Tuya no está configurado (bleScanStart).", details: nil))
        return
      }
      let timeoutS = min(60, max(5, (args["timeoutS"] as? NSNumber)?.intValue ?? 20))
      let scanner = bleScanner ?? TuyaBleScanner(events: events)
      bleScanner = scanner
      scanner.start(timeoutS: timeoutS)
      result(true)
    }

    /// `pairStartBle {uuid, ssid, password, token, timeoutS}` (homeId/productId no hacen falta aquí).
    private func pairStartBle(_ args: [String: Any], _ result: @escaping FlutterResult) {
      guard configured else {
        result(FlutterError(code: "TUYA_NOT_CONFIGURED", message: "El SDK de Tuya no está configurado (pairStartBle).", details: nil))
        return
      }
      let uuid = args["uuid"] as? String ?? ""
      let ssid = args["ssid"] as? String ?? ""
      let password = args["password"] as? String ?? ""
      let token = args["token"] as? String ?? ""
      let timeoutS = min(300, max(30, (args["timeoutS"] as? NSNumber)?.intValue ?? 120))
      guard !uuid.isEmpty, !ssid.isEmpty, !token.isEmpty else {
        result(FlutterError(code: "TUYA_PAIR_BAD_ARGS", message: "Falta el equipo, la red o el permiso de la casa.", details: nil))
        return
      }
      bleScanner?.stop()
      pairing?.stop()
      pairing = nil
      blePairing?.stop()
      let session = TuyaBlePairing(events: events)
      blePairing = session
      session.start(uuid: uuid, token: token, ssid: ssid, password: password, timeoutS: timeoutS)
      result(true)
    }
  }

#endif
