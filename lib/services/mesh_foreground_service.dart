import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MeshForegroundService extends ChangeNotifier {
  MeshForegroundService._();

  static final MeshForegroundService instance = MeshForegroundService._();

  bool _isInitialized = false;
  bool _isRunning = false;
  String? _lastError;

  bool get isRunning => _isRunning;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'blackout_prague_mesh_service',
        channelName: 'Blackout Prague mesh',
        channelDescription: 'Trvalé oznámení pro krizovou Bluetooth mesh komunikaci.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _isInitialized = true;
    await refreshStatus();
  }

  Future<bool> start() async {
    try {
      await initialize();
      final result = await FlutterForegroundTask.startService(
        serviceId: 4247,
        serviceTypes: const [ForegroundServiceTypes.connectedDevice],
        notificationTitle: 'Blackout Prague mesh je aktivní',
        notificationText: 'Aplikace přijímá krizové Bluetooth zprávy v okolí.',
        callback: _meshForegroundTaskCallback,
      );
      _lastError = result is ServiceRequestFailure ? 'Běh na pozadí se nepodařilo spustit.' : null;
      await refreshStatus();
      return _lastError == null;
    } catch (_) {
      _isRunning = false;
      _lastError = 'Běh na pozadí se nepodařilo spustit.';
      notifyListeners();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Service may already be stopped.
    }
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      _isRunning = await FlutterForegroundTask.isRunningService;
      if (!_isRunning) {
        _lastError = null;
      }
    } catch (_) {
      _isRunning = false;
    }
    notifyListeners();
  }
}

@pragma('vm:entry-point')
void _meshForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_MeshForegroundTaskHandler());
}

class _MeshForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService(
      notificationTitle: 'Blackout Prague mesh je aktivní',
      notificationText: 'Aplikace přijímá krizové Bluetooth zprávy v okolí.',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
