import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/hubspot_service.dart';

class AppState extends ChangeNotifier {
  final HubspotService _hubspotService = HubspotService();

  String _installerName = "Juan Mora";
  String get installerName => _installerName;

  final String installerId = "65243";
  final String installerRole = "Instalador";
  final String installerAvatar = "avatar.png";

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

  int _instalacionesCount = 3;
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
