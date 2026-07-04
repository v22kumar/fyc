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
  bool get manualLiteMode => _manualLiteMode;

  // Bumped on every evaluation start (and on manual toggles) so an older async
  // evaluation that resolves late cannot overwrite a newer tier decision.
  int _evaluationGeneration = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _manualLiteMode = prefs.getBool('manual_lite_mode') ?? false;

    // Platform channels may be unavailable (e.g. under `flutter test`, or on a
    // stripped-down device). Device profiling is a best-effort optimisation —
    // it must never block or crash app startup.
    try {
      _connectivity.onConnectivityChanged.listen((results) {
        _evaluateTier();
      });
      _battery.onBatteryStateChanged.listen((state) {
        _evaluateTier();
      });
    } catch (_) {
      // No platform channel — skip live listeners, fall back to a one-shot eval.
    }

    // Fire-and-forget: the connectivity platform channel can be slow or (under
    // `flutter test`) never respond, so never block app startup on it. The tier
    // stays at the `full` default until the first evaluation resolves.
    unawaited(_evaluateTier());
  }

  Future<void> setManualLiteMode(bool enabled) async {
    _manualLiteMode = enabled;
    _evaluationGeneration++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manual_lite_mode', enabled);
    await _evaluateTier();
  }

  Future<void> _evaluateTier() async {
    final generation = ++_evaluationGeneration;
    if (_manualLiteMode) {
      _updateTier(DeviceTier.lite);
      return;
    }

    // Guard the platform-channel call: under `flutter test` (or if the plugin
    // is missing) this can throw, which would otherwise crash the evaluation.
    // (This runs unawaited from init(), so a slow call can't block startup.)
    List<ConnectivityResult> connectivityResult;
    try {
      connectivityResult = await _connectivity.checkConnectivity();
    } catch (_) {
      if (generation != _evaluationGeneration) return;
      _updateTier(DeviceTier.full);
      return;
    }
    // A newer evaluation started while we awaited — abandon this stale run.
    if (generation != _evaluationGeneration) return;
    if (_manualLiteMode) {
      _updateTier(DeviceTier.lite);
      return;
    }
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

    // Re-check for a newer evaluation after the battery awaits.
    if (generation != _evaluationGeneration) return;
    if (_manualLiteMode) {
      _updateTier(DeviceTier.lite);
      return;
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
