import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

enum DiscoveryState { idle, searching, found, notFound, error, invalidFormat }
enum ConnectionMode { auto, manual }

class NetworkDiscoveryProvider with ChangeNotifier {
  DiscoveryState _state = DiscoveryState.idle;
  DiscoveryState get state => _state;

  String? _serverAddress;
  String? get serverAddress => _serverAddress;

  ConnectionMode _connectionMode = ConnectionMode.auto;
  ConnectionMode get connectionMode => _connectionMode;

  String? _manualIpAddress;
  String? get manualIpAddress => _manualIpAddress;

  Discovery? _discovery;

  NetworkDiscoveryProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('connectionMode') ?? 'auto';
    _connectionMode = modeString == 'manual' ? ConnectionMode.manual : ConnectionMode.auto;
    _manualIpAddress = prefs.getString('manualIpAddress');
    notifyListeners();

    discoverService();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connectionMode', _connectionMode == ConnectionMode.manual ? 'manual' : 'auto');
    if (_manualIpAddress != null) {
      await prefs.setString('manualIpAddress', _manualIpAddress!);
    } else {
      await prefs.remove('manualIpAddress');
    }
  }

  Future<void> setConnectionMode(ConnectionMode mode) async {
    if (_connectionMode == mode) return;

    _connectionMode = mode;
    await _savePreferences();

    discoverService();
  }

  Future<void> setManualIpAddress(String ip) async {
    _manualIpAddress = ip;
    await _savePreferences();
    notifyListeners();
  }

  Future<bool> _testServerConnection(String address) async {
    try {
      final response = await http.get(Uri.parse(address)).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on TimeoutException {
      return false;
    } on Exception catch (e) {
      return false;
    }
  }

  Future<bool> discoverService() async {
    if (_connectionMode == ConnectionMode.manual) {
      if (_manualIpAddress != null && _manualIpAddress!.isNotEmpty) {
        if (!Uri.tryParse(_manualIpAddress!)!.isAbsolute == true) {
          _updateState(DiscoveryState.invalidFormat);
          return false;
        }

        _updateState(DiscoveryState.searching);
        bool isConnected = await _testServerConnection(_manualIpAddress!);
        if (isConnected) {
          _serverAddress = _manualIpAddress;
          _updateState(DiscoveryState.found);
          return true;
        } else {
          _serverAddress = null;
          _updateState(DiscoveryState.notFound);
          return false;
        }
      } else {
        _serverAddress = null;
        _updateState(DiscoveryState.notFound);
        return false;
      }
    }

    if (_state == DiscoveryState.searching) {
      return _serverAddress != null;
    }

    _updateState(DiscoveryState.searching);

    try {
      await _cleanUpDiscovery();
      _discovery = await startDiscovery('_http._tcp');

      final completer = Completer<bool>();

      void serviceListener(Service service, ServiceStatus status) async {
        if (status == ServiceStatus.found) {
          if (service.name == 'My HairFast API') {
            final host = service.host;
            final port = service.port;

            if (host != null && port != null) {
              String potentialServerAddress = 'http://$host:$port';

              bool isConnected = await _testServerConnection(potentialServerAddress);

              if (isConnected) {
                _serverAddress = potentialServerAddress;
                _updateState(DiscoveryState.found);
                _cleanUpDiscovery();
                if (!completer.isCompleted) completer.complete(true);
              }
            }
          }
        }
      }
      _discovery?.addServiceListener(serviceListener);

      await Future.delayed(const Duration(seconds: 12));
      if (!completer.isCompleted) {
        if (_state == DiscoveryState.searching) {
          _updateState(DiscoveryState.notFound);
          _cleanUpDiscovery();
          completer.complete(false);
        } else {
          completer.complete(_state == DiscoveryState.found);
        }
      }

      return completer.future;

    } catch (e) {
      _updateState(DiscoveryState.error);
      return false;
    }
  }

  Future<void> _cleanUpDiscovery() async {
    if (_discovery != null) {
      try {
        await stopDiscovery(_discovery!);
        _discovery = null;
      } catch (e) {
      }
    }
  }

  void _updateState(DiscoveryState newState) {
    _state = newState;
    notifyListeners();
  }

  void setErrorState() {
    _updateState(DiscoveryState.error);
  }

  @override
  void dispose() {
    _cleanUpDiscovery();
    super.dispose();
  }
}