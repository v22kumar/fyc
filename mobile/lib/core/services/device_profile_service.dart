import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceTier { full, balanced, lite, offline }

class DeviceProfileService {
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();
  
  final _tierController = StreamController<DeviceTier>.broadcast();
  DeviceTier _currentTier = DeviceTier.full;

  DeviceTier get currentTier => _currentTier;
  Stream<DeviceTier> get tierStream => _tierController.stream;

  bool _manualLiteMode = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _manualLiteMode = prefs.getBool('manual_lite_mode') ?? false;

    // Listen to network changes
    _connectivity.onConnectivityChanged.listen((results) {
      _evaluateTier();
    });

    // Listen to battery state
    _battery.onBatteryStateChanged.listen((state) {
      _evaluateTier();
    });

    await _evaluateTier();
  }

  Future<void> setManualLiteMode(bool enabled) async {
    _manualLiteMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manual_lite_mode', enabled);
    await _evaluateTier();
  }

  Future<void> _evaluateTier() async {
    if (_manualLiteMode) {
      _updateTier(DeviceTier.lite);
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _updateTier(DeviceTier.offline);
      return;
    }

    final isMobile = connectivityResult.contains(ConnectivityResult.mobile);
    
    // Check battery safely
    bool isLowBattery = false;
    bool isPowerSave = false;
    try {
      final batteryState = await _battery.batteryState;
      final batteryLevel = await _battery.batteryLevel;
      isLowBattery = batteryLevel <= 15 && batteryState != BatteryState.charging;
      isPowerSave = await _battery.isInBatterySaveMode;
    } catch (_) {
      // Ignore battery plugin errors on unsupported platforms
    }

    if (isPowerSave || isLowBattery) {
      _updateTier(DeviceTier.lite);
      return;
    }

    if (isMobile) {
      _updateTier(DeviceTier.balanced);
      return;
    }

    _updateTier(DeviceTier.full);
  }

  void _updateTier(DeviceTier newTier) {
    if (_currentTier != newTier) {
      _currentTier = newTier;
      _tierController.add(newTier);
    }
  }
}
