import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/prague_areas.dart';
import '../models/emergency_message.dart';
import '../services/demo_mode_service.dart';
import '../services/location_service.dart';
import '../services/message_service.dart';
import '../services/real_ble_mesh_service.dart';
import '../services/selected_area_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenFindHelp,
    required this.onOpenGuides,
  });

  final VoidCallback onOpenFindHelp;
  final VoidCallback onOpenGuides;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _battery = Battery();
  final _connectivity = Connectivity();
  final _messageService = MessageService.instance;
  final _realBleMeshService = RealBleMeshService.instance;
  final _demoModeService = DemoModeService.instance;
  final _locationService = LocationService();
  final _selectedAreaService = SelectedAreaService();

  String _batteryText = 'Baterie: nelze zjistit';
  String _connectionText = 'Stav sítě není dostupný';
  bool _isDemoModeEnabled = false;
  String _locationStatus = 'Poloha zatím není nastavena';

  @override
  void initState() {
    super.initState();
    _messageService.loadMessages();
    _demoModeService.addListener(_syncDemoMode);
    _loadDemoMode();
    _loadDashboardState();
    _loadLocationStatus();
  }

  @override
  void dispose() {
    _demoModeService.removeListener(_syncDemoMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionText = _isDemoModeEnabled ? 'Síť: přetížená / omezená' : _connectionText;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
        children: [
          const Text(
            'Blackout Prague',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Offline krizová příprava pro Prahu',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          if (_isDemoModeEnabled) ...[
            const SizedBox(height: 12),
            const _DemoBanner(),
          ],
          const SizedBox(height: 18),
          _StatusCard(icon: Icons.battery_5_bar_outlined, title: _batteryText, color: AppColors.safeGreen),
          const SizedBox(height: 10),
          _StatusCard(icon: Icons.signal_cellular_alt_outlined, title: connectionText, color: _isDemoModeEnabled ? AppColors.warningOrange : AppColors.primaryLight),
          if (_isDemoModeEnabled) ...[
            const SizedBox(height: 10),
            const _StatusCard(icon: Icons.power_off_outlined, title: 'Stav: výpadek elektřiny simulován', color: AppColors.emergencyRed),
          ],
          const SizedBox(height: 10),
          _StatusCard(icon: Icons.location_on_outlined, title: _locationStatus, color: AppColors.primary),
          const SizedBox(height: 10),
          const _StatusCard(icon: Icons.offline_bolt_outlined, title: 'Offline režim připraven', color: AppColors.safeGreen),
          const SizedBox(height: 24),
          _SosButton(onPressed: _confirmAndCreateSos),
          const SizedBox(height: 18),
          _QuickActions(
            onCreateMessage: _createMessage,
            onOpenFindHelp: widget.onOpenFindHelp,
            onOpenGuides: widget.onOpenGuides,
          ),
        ],
      ),
    );
  }

  Future<void> _loadLocationStatus() async {
    final lastKnownLocation = await _locationService.getLastKnownLocation();
    final selectedAreaId = await _selectedAreaService.loadSelectedAreaId();
    final selectedArea = getPragueAreaById(selectedAreaId);

    final status = lastKnownLocation != null
        ? 'Poslední známá GPS poloha uložena'
        : selectedAreaId != null
            ? 'Ruční oblast: ${selectedArea.name}'
            : 'Poloha zatím není nastavena';

    if (!mounted) {
      return;
    }

    setState(() => _locationStatus = status);
  }

  Future<void> _loadDemoMode() async {
    await _demoModeService.load();
    if (!mounted) {
      return;
    }
    setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
    if (_demoModeService.isEnabled) {
      await _messageService.addDemoMessagesIfNeeded();
    }
  }

  void _syncDemoMode() {
    if (!mounted) {
      return;
    }
    setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
    if (_demoModeService.isEnabled) {
      _messageService.addDemoMessagesIfNeeded();
    }
  }

  Future<void> _loadDashboardState() async {
    final batteryText = await _loadBatteryText();
    final connectionText = await _loadConnectionText();

    if (!mounted) {
      return;
    }

    setState(() {
      _batteryText = batteryText;
      _connectionText = connectionText;
    });
  }

  Future<String> _loadBatteryText() async {
    try {
      final level = await _battery.batteryLevel;
      return 'Baterie: $level %';
    } catch (_) {
      return 'Baterie: nelze zjistit';
    }
  }

  Future<String> _loadConnectionText() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _connectionLabel(results);
    } catch (_) {
      return 'Stav sítě není dostupný';
    }
  }

  String _connectionLabel(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'Síť: bez připojení';
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return 'Síť: Wi-Fi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return 'Síť: mobilní síť';
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return 'Síť: ethernet';
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return 'Síť: VPN';
    }
    return 'Stav sítě není dostupný';
  }

  Future<void> _createMessage(_QuickAction action) async {
    if (action.messageType == null || action.priority == null) {
      return;
    }

    final message = await _messageService.createOutgoingMessage(
      type: action.messageType!,
      text: action.messageText ?? action.label,
      priority: action.priority!,
      ttlMinutes: action.ttlMinutes,
    );

    if (!mounted) {
      return;
    }

    await _sendMessageOverBleIfEnabled(message);
  }

  Future<void> _confirmAndCreateSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SOS zpráva'),
          content: const Text('Opravdu chcete vytvořit SOS zprávu?\n\nZpráva bude uložena v telefonu a při zapnutém BLE mesh odeslána okolním zařízením.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Zrušit')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vytvořit SOS zprávu')),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final message = await _messageService.createOutgoingMessage(
      type: EmergencyMessageType.sos,
      text: 'SOS: potřebuji okamžitou pomoc.',
      priority: EmergencyMessagePriority.critical,
      ttlMinutes: 60,
    );

    if (!mounted) {
      return;
    }

    await _sendMessageOverBleIfEnabled(message);
  }

  Future<void> _sendMessageOverBleIfEnabled(EmergencyMessage message) async {
    String snackBarText;
    if (_realBleMeshService.isEnabled) {
      final wasBroadcast = await _realBleMeshService.broadcastMessage(message);
      snackBarText = wasBroadcast
          ? 'Zpráva byla odvysílána přes BLE mesh.'
          : (_realBleMeshService.lastError ?? 'Toto zařízení nepodporuje BLE vysílání.');
    } else {
      snackBarText = 'Zapněte BLE mesh pro odeslání.';
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snackBarText)));
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningOrange),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: AppColors.warningOrange),
            SizedBox(width: 10),
            Text('Demo režim', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.color});

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 176,
          height: 176,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              elevation: 6,
              shadowColor: AppColors.emergencyRed.withValues(alpha: 0.45),
            ),
            onPressed: onPressed,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 46),
                SizedBox(height: 4),
                Text('SOS', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 0)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Vytvořit nouzovou zprávu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCreateMessage, required this.onOpenFindHelp, required this.onOpenGuides});

  final ValueChanged<_QuickAction> onCreateMessage;
  final VoidCallback onOpenFindHelp;
  final VoidCallback onOpenGuides;

  static const _actions = <_QuickAction>[
    _QuickAction(
      Icons.check_circle_outline,
      'Jsem v pořádku',
      messageType: EmergencyMessageType.ok,
      priority: EmergencyMessagePriority.low,
      messageText: 'Jsem v pořádku.',
      ttlMinutes: 240,
    ),
    _QuickAction(
      Icons.medical_services_outlined,
      'Potřebuji zdravotní pomoc',
      messageType: EmergencyMessageType.medical,
      priority: EmergencyMessagePriority.high,
      messageText: 'Potřebuji zdravotní pomoc.',
      ttlMinutes: 120,
    ),
    _QuickAction(
      Icons.water_drop_outlined,
      'Potřebuji vodu',
      messageType: EmergencyMessageType.water,
      priority: EmergencyMessagePriority.medium,
      messageText: 'Potřebuji vodu.',
      ttlMinutes: 180,
    ),
    _QuickAction(
      Icons.medication_outlined,
      'Potřebuji léky',
      messageType: EmergencyMessageType.medication,
      priority: EmergencyMessagePriority.high,
      messageText: 'Potřebuji léky.',
      ttlMinutes: 120,
    ),
    _QuickAction(
      Icons.report_problem_outlined,
      'Nahlásit nebezpečí',
      messageType: EmergencyMessageType.danger,
      priority: EmergencyMessagePriority.high,
      messageText: 'Nahlášeno nebezpečí v okolí.',
      ttlMinutes: 90,
    ),
    _QuickAction(Icons.place_outlined, 'Najít nejbližší pomoc', opensFindHelp: true),
    _QuickAction(Icons.menu_book_outlined, 'Krizové návody', opensGuides: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rychlé akce', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final action in _actions) ...[
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                if (action.opensFindHelp) {
                  onOpenFindHelp();
                } else if (action.opensGuides) {
                  onOpenGuides();
                } else {
                  onCreateMessage(action);
                }
              },
              icon: Icon(action.icon),
              label: Text(action.label),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction(
    this.icon,
    this.label, {
    this.messageType,
    this.priority,
    this.messageText,
    this.ttlMinutes = 180,
    this.opensFindHelp = false,
    this.opensGuides = false,
  });

  final IconData icon;
  final String label;
  final EmergencyMessageType? messageType;
  final EmergencyMessagePriority? priority;
  final String? messageText;
  final int ttlMinutes;
  final bool opensFindHelp;
  final bool opensGuides;
}
