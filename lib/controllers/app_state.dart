import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/hubspot_service.dart';

class AppState extends ChangeNotifier {
  final HubspotService _hubspotService = HubspotService();

  final String installerName = "Juan Mora";
  final String installerId = "65243";
  final String installerRole = "Instalador";
  final String installerAvatar = "avatar.png";

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
