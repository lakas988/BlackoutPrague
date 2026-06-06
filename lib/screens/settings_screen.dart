import 'package:flutter/material.dart';

import '../services/demo_mode_service.dart';
import '../services/mesh_foreground_service.dart';
import '../services/mesh_notification_service.dart';
import '../services/mesh_settings_service.dart';
import '../services/message_service.dart';
import '../services/real_ble_mesh_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _demoModeService = DemoModeService.instance;
  final _messageService = MessageService.instance;
  final _meshSettingsService = MeshSettingsService.instance;
  final _realBleMeshService = RealBleMeshService.instance;
  final _meshForegroundService = MeshForegroundService.instance;
  final _meshNotificationService = MeshNotificationService.instance;

  bool _isDemoModeEnabled = false;
  bool _autoStartBleMesh = false;
  bool _backgroundMeshEnabled = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _demoModeService.addListener(_syncDemoMode);
    _meshSettingsService.addListener(_syncMeshSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    _demoModeService.removeListener(_syncDemoMode);
    _meshSettingsService.removeListener(_syncMeshSettings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nastavení')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Nastavení', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Volby pro krizový režim, soukromí a Bluetooth komunikaci.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC7D0DC)),
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              icon: Icons.science_outlined,
              title: 'Demo režim',
              description: 'Demo režim zapíná ukázková data a simulované zprávy pro prezentaci.',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Zapnout Demo režim'),
                  value: _isDemoModeEnabled,
                  onChanged: _setDemoMode,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetDemoData,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Resetovat demo data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              icon: Icons.hub_outlined,
              title: 'Krizový mesh režim',
              description: 'Reálný Bluetooth mesh slouží k předávání krátkých krizových zpráv mezi zařízeními.',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Spustit BLE mesh při otevření aplikace'),
                  value: _autoStartBleMesh,
                  onChanged: _setAutoStartBleMesh,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Povolit běh BLE mesh na pozadí'),
                  value: _backgroundMeshEnabled,
                  onChanged: _setBackgroundMeshEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Zobrazovat oznámení o přijatých zprávách'),
                  value: _notificationsEnabled,
                  onChanged: _setNotificationsEnabled,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _requestBluetoothMeshPermission,
                    icon: const Icon(Icons.bluetooth_searching_outlined),
                    label: const Text('Povolit Bluetooth mesh'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Běh na pozadí je experimentální. Pro spolehlivý příjem ponechte aplikaci otevřenou a povolte běh na pozadí v nastavení telefonu.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pro spolehlivý příjem zpráv může být potřeba vypnout optimalizaci baterie pro tuto aplikaci.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _SettingsSection(
              icon: Icons.lock_outline,
              title: 'Soukromí',
              description: 'Citlivé údaje z profilu zůstávají pouze v tomto zařízení.',
            ),
            const SizedBox(height: 14),
            const _SettingsSection(
              icon: Icons.info_outline,
              title: 'O aplikaci',
              description: 'Blackout Prague je offline-first krizová aplikace pro výpadek elektřiny a přetížené mobilní sítě v Praze.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    await _demoModeService.load();
    await _meshSettingsService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDemoModeEnabled = _demoModeService.isEnabled;
      _autoStartBleMesh = _meshSettingsService.autoStartBleMesh;
      _backgroundMeshEnabled = _meshSettingsService.backgroundMeshEnabled;
      _notificationsEnabled = _meshSettingsService.notificationsEnabled;
    });
  }

  void _syncDemoMode() {
    if (mounted) {
      setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
    }
  }

  void _syncMeshSettings() {
    if (mounted) {
      setState(() {
        _autoStartBleMesh = _meshSettingsService.autoStartBleMesh;
        _backgroundMeshEnabled = _meshSettingsService.backgroundMeshEnabled;
        _notificationsEnabled = _meshSettingsService.notificationsEnabled;
      });
    }
  }

  Future<void> _setDemoMode(bool enabled) async {
    await _demoModeService.setEnabled(enabled);
    if (enabled) {
      await _messageService.addDemoMessagesIfNeeded();
    } else {
      await _messageService.clearDemoMessages();
    }

    if (!mounted) {
      return;
    }

    _showSnackBar(enabled ? 'Demo režim je zapnutý.' : 'Demo režim je vypnutý.');
  }

  Future<void> _setAutoStartBleMesh(bool enabled) async {
    await _meshSettingsService.setAutoStartBleMesh(enabled);
    if (enabled) {
      final granted = await _realBleMeshService.requestBluetoothPermissions();
      if (!granted && mounted) {
        _showSnackBar('BLE mesh nelze spustit bez oprávnění Bluetooth.');
      }
    }
  }

  Future<void> _setBackgroundMeshEnabled(bool enabled) async {
    await _meshSettingsService.setBackgroundMeshEnabled(enabled);
    if (enabled && _realBleMeshService.isEnabled) {
      await _realBleMeshService.updateForegroundServiceForSettings();
      if (_meshForegroundService.lastError != null && mounted) {
        _showSnackBar(_meshForegroundService.lastError!);
      }
    } else {
      await _realBleMeshService.updateForegroundServiceForSettings();
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _meshNotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          _showSnackBar('Oznámení nejsou povolena.');
        }
        return;
      }
    }

    await _meshSettingsService.setNotificationsEnabled(enabled);
  }

  Future<void> _requestBluetoothMeshPermission() async {
    final granted = await _realBleMeshService.requestBluetoothPermissions();
    if (!mounted) {
      return;
    }

    _showSnackBar(granted ? 'Bluetooth mesh je povolený.' : 'BLE mesh nelze spustit bez oprávnění Bluetooth.');
  }

  Future<void> _resetDemoData() async {
    await _messageService.clearDemoMessages();

    if (!mounted) {
      return;
    }

    _showSnackBar('Demo data byla resetována. Profil uživatele zůstal beze změny.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30, color: const Color(0xFF00D1FF)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 10),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}
