import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'services/mesh_foreground_service.dart';
import 'services/mesh_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await MeshNotificationService.instance.initialize();
  await MeshForegroundService.instance.initialize();
  runApp(const BlackoutPragueApp());
}
