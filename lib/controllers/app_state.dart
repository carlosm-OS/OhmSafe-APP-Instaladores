import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/hubspot_service.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';

class AppState extends ChangeNotifier {
  final HubspotService _hubspotService = HubspotService();

  String _installerName = "Juan Mora";
  String get installerName => _installerName;

  final String installerId = "65243"; // legado (fallback si aún no llega el real)
  final String installerRole = "Instalador";

  // Número de instalador real (Odoo x_numero_instalador). Se carga con
  // refreshBadges(); mientras tanto se usa el fallback de arriba.
  String _numeroInstalador = '';
  String get numeroInstalador => _numeroInstalador;
  String get numeroVisible => _numeroInstalador.isNotEmpty ? _numeroInstalador : installerId;

  // Código de venta / descuento (Odoo x_codigo_venta) para el bono por referidos.
  String _codigoVenta = '';
  String get codigoVenta => _codigoVenta;
  final String installerAvatar = "avatar.png";

  // Foto de perfil real (Odoo image_256, base64). Se carga con refreshBadges();
  // vacío mientras no llegue o si el instalador no tiene foto.
  String _fotoBase64 = '';
  String get fotoBase64 => _fotoBase64;

  String _installerPhone = "55 5266 7879";
  String get installerPhone => _installerPhone;

  String _installerEmail = "juan@ohmsafe.com";
  String get installerEmail => _installerEmail;

  String _installerCurp = "JMY790428HDFM01";
  String get installerCurp => _installerCurp;

  void updateInstallerInfo({
    required String name,
    required String phone,
    required String email,
    required String curp,
  }) {
    _installerName = name;
    _installerPhone = phone;
    _installerEmail = email;
    _installerCurp = curp;
    notifyListeners();
  }

  String _bankHolder = "Juan Mora";
  String get bankHolder => _bankHolder;

  String _bankClabe = "5552667879000";
  String get bankClabe => _bankClabe;

  String _bankName = "BBVA";
  String get bankName => _bankName;

  String _bankAccount = "876283712";
  String get bankAccount => _bankAccount;

  void updateBankInfo({
    required String holder,
    required String clabe,
    required String name,
    required String account,
  }) {
    _bankHolder = holder;
    _bankClabe = clabe;
    _bankName = name;
    _bankAccount = account;
    notifyListeners();
  }

  String? _customAvatarPath;
  String? get customAvatarPath => _customAvatarPath;

  void updateAvatarPath(String path) {
    _customAvatarPath = path;
    notifyListeners();
  }

  String? _taxCertificatePath;
  String? get taxCertificatePath => _taxCertificatePath;

  String? _taxCertificateName;
  String? get taxCertificateName => _taxCertificateName;

  void updateTaxCertificate(String? path, String? name) {
    _taxCertificatePath = path;
    _taxCertificateName = name;
    notifyListeners();
  }

  // Los badges reflejan las asignaciones reales del backend (Odoo passthrough
  // vía OrdenesRepository), no un valor fijo. Arrancan en 0 y se actualizan con
  // refreshBadges() al abrir el home.
  int _instalacionesCount = 0;
  int _reparacionesCount = 0;
  int _mantenimientosCount = 0;
  int _reemplazoCount = 0;
  int _incidenciasCount = 0;

  bool _isSyncing = false;
  String _syncStatusMessage = "Presiona sincronizar para consultar HubSpot";

  List<Ticket> _activeTickets = [];

  AppState() {
    _activeTickets = _hubspotService.getTicketsForCount(_instalacionesCount);
  }

  int get instalacionesCount => _instalacionesCount;
  int get reparacionesCount => _reparacionesCount;

  /// Actualiza los badges de instalaciones/reparaciones con el conteo real de
  /// órdenes asignadas al instalador (mismo repositorio que usan las listas, así
  /// el badge y la lista nunca se desincronizan). Silencioso ante fallos de red:
  /// deja el último valor conocido.
  Future<void> refreshBadges() async {
    final repo = sl.get<OrdenesRepository>();
    final inst = await repo.getOrdenes(tipo: 'instalacion');
    inst.fold((list) => _instalacionesCount = list.length, (_) {});
    final rep = await repo.getOrdenes(tipo: 'reparacion');
    rep.fold((list) => _reparacionesCount = list.length, (_) {});
    // Número de instalador, código de venta, nombre y foto reales desde el
    // perfil (Odoo). El nombre se refresca aquí para que un cambio en Datos
    // Generales se refleje tras recargar el home.
    final perfil = await sl.get<PerfilRepository>().getPerfil();
    perfil.fold((p) {
      _numeroInstalador = p.numeroInstalador;
      _codigoVenta = p.codigoVenta;
      if (p.nombre.isNotEmpty) _installerName = p.nombre;
      _fotoBase64 = p.fotoBase64;
    }, (_) {});
    notifyListeners();
  }
  int get mantenimientosCount => _mantenimientosCount;
  int get reemplazoCount => _reemplazoCount;
  int get incidenciasCount => _incidenciasCount;

  bool get isSyncing => _isSyncing;
  String get syncStatusMessage => _syncStatusMessage;
  List<Ticket> get activeTickets => _activeTickets;

  // Historial de tickets completados (instalaciones y reparaciones).
  // En memoria durante la sesión; en producción vendría del backend.
  final List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  // Registra un ticket como completado, sellando la fecha de cierre.
  void addCompletedTicket(Map<String, dynamic> ticket) {
    final entry = Map<String, dynamic>.from(ticket);
    entry['status'] = 'Completo';
    entry['completedAt'] = DateTime.now();
    _history.insert(0, entry); // el más reciente primero
    notifyListeners();
  }

  void adjustCount(String itemId, int delta) {
    switch (itemId) {
      case 'instalaciones':
        _instalacionesCount = (_instalacionesCount + delta).clamp(0, 99);
        _activeTickets = _hubspotService.getTicketsForCount(_instalacionesCount);
        break;
      case 'reparaciones':
        _reparacionesCount = (_reparacionesCount + delta).clamp(0, 99);
        break;
      case 'mantenimientos':
        _mantenimientosCount = (_mantenimientosCount + delta).clamp(0, 99);
        break;
      case 'reemplazo':
        _reemplazoCount = (_reemplazoCount + delta).clamp(0, 99);
        break;
      case 'incidencias':
        _incidenciasCount = (_incidenciasCount + delta).clamp(0, 99);
        break;
    }
    notifyListeners();
  }

  Future<void> syncWithHubspot() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncStatusMessage = "Conectando con la API de HubSpot...";
    notifyListeners();

    try {
      final results = await _hubspotService.simulateSync();
      
      _instalacionesCount = results['instalaciones'] ?? 0;
      _reparacionesCount = results['reparaciones'] ?? 0;
      _mantenimientosCount = results['mantenimientos'] ?? 0;
      _reemplazoCount = results['reemplazo'] ?? 0;
      _incidenciasCount = results['incidencias'] ?? 0;

      _activeTickets = _hubspotService.getTicketsForCount(_instalacionesCount);

      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _syncStatusMessage = "Sincronizado a las $timeStr";
    } catch (e) {
      _syncStatusMessage = "Error al sincronizar: ${e.toString()}";
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
