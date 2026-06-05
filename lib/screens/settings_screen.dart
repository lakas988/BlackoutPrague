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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings_outlined, size: 42, color: Color(0xFFFFD166)),
                    const SizedBox(height: 18),
                    Text('Nastavení', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Základní nastavení aplikace pro offline krizový režim.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demo režim', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Demo režim používá ukázková data pro prezentaci porotě. Nejde o živá krizová data.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Zapnout demo režim'),
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
              ),
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