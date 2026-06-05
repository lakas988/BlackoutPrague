import 'package:flutter/material.dart';

import '../services/demo_mode_service.dart';
import '../services/message_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _demoModeService = DemoModeService.instance;
  final _messageService = MessageService.instance;

  bool _isDemoModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _demoModeService.addListener(_syncDemoMode);
    _loadDemoMode();
  }

  @override
  void dispose() {
    _demoModeService.removeListener(_syncDemoMode);
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
            const _SettingsSection(
              icon: Icons.bluetooth_connected_outlined,
              title: 'Mesh / Bluetooth',
              description: 'Reálný Bluetooth mesh slouží k předávání krátkých krizových zpráv mezi zařízeními. Bluetooth mesh je dostupný jako prototyp pro Android zařízení.',
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

  Future<void> _loadDemoMode() async {
    await _demoModeService.load();
    if (!mounted) {
      return;
    }
    setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
  }

  void _syncDemoMode() {
    if (mounted) {
      setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? 'Demo režim je zapnutý.' : 'Demo režim je vypnutý.')),
    );
  }

  Future<void> _resetDemoData() async {
    await _messageService.clearDemoMessages();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo data byla resetována. Profil uživatele zůstal beze změny.')),
    );
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
