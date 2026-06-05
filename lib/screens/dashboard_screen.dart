import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/prague_areas.dart';
import '../models/app_power_mode.dart';
import '../models/emergency_message.dart';
import '../services/demo_mode_service.dart';
import '../services/location_service.dart';
import '../services/message_service.dart';
import '../services/power_mode_service.dart';
import '../services/selected_area_service.dart';

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
  final _powerModeService = PowerModeService();
  final _battery = Battery();
  final _connectivity = Connectivity();
  final _messageService = MessageService.instance;
  final _demoModeService = DemoModeService.instance;
  final _locationService = LocationService();
  final _selectedAreaService = SelectedAreaService();

  AppPowerMode _powerMode = AppPowerMode.normal;
  String _batteryText = 'Baterie: nelze zjistit';
  String _connectionText = 'Stav sítě není dostupný';
  bool _isLoadingMode = true;
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
    if (_powerMode == AppPowerMode.ultra) {
      return _UltraDashboard(
        batteryText: _batteryText,
        mode: _powerMode,
        isLoadingMode: _isLoadingMode,
        onModeChanged: _setPowerMode,
        onCreateMessage: _createMessage,
        onCreateSos: _confirmAndCreateSos,
        onOpenFindHelp: widget.onOpenFindHelp,
        onOpenGuides: widget.onOpenGuides,
      );
    }

    final isBatterySaver = _powerMode == AppPowerMode.batterySaver;
    final connectionText = _isDemoModeEnabled ? 'Síť: přetížená / omezená' : _connectionText;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Blackout Prague',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(height: 8),
          Text(
            'Offline krizová příprava pro Prahu',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD6D9DE)),
          ),
          const SizedBox(height: 12),
          if (_isDemoModeEnabled) ...[
            const _DemoBanner(),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          _PowerModeSelector(selectedMode: _powerMode, isEnabled: !_isLoadingMode, onChanged: _setPowerMode),
          const SizedBox(height: 16),
          _ModeMessage(mode: _powerMode),
          const SizedBox(height: 16),
          _StatusCard(icon: Icons.battery_5_bar_outlined, title: _batteryText),
          const SizedBox(height: 12),
          _StatusCard(icon: Icons.power_settings_new_outlined, title: 'Režim baterie: ${_powerMode.czechLabel}'),
          const SizedBox(height: 12),
          _StatusCard(icon: Icons.signal_cellular_alt_outlined, title: connectionText),
          if (_isDemoModeEnabled) ...[
            const SizedBox(height: 12),
            const _StatusCard(icon: Icons.power_off_outlined, title: 'Stav: výpadek elektřiny simulován'),
            const SizedBox(height: 12),
            const _StatusCard(icon: Icons.tips_and_updates_outlined, title: 'Doporučení: přepnout do úsporného režimu'),
          ],
          const SizedBox(height: 12),
          _StatusCard(icon: Icons.location_on_outlined, title: _locationStatus),
          const SizedBox(height: 6),
          Text(
            'Poloha se používá jen jednorázově kvůli úspoře baterie.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD6D9DE)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenFindHelp,
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Aktualizovat polohu'),
            ),
          ),
          if (!isBatterySaver) ...[
            const SizedBox(height: 12),
            const _StatusCard(icon: Icons.offline_bolt_outlined, title: 'Offline režim připraven'),
          ],
          const SizedBox(height: 28),
          _SosButton(onPressed: _confirmAndCreateSos),
          const SizedBox(height: 16),
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
    final mode = await _powerModeService.loadMode();
    final batteryText = await _loadBatteryText();
    final connectionText = await _loadConnectionText();

    if (!mounted) {
      return;
    }

    setState(() {
      _powerMode = mode;
      _batteryText = batteryText;
      _connectionText = connectionText;
      _isLoadingMode = false;
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

  Future<void> _setPowerMode(AppPowerMode mode) async {
    setState(() => _powerMode = mode);
    await _powerModeService.saveMode(mode);
  }

  Future<void> _createMessage(_QuickAction action) async {
    if (action.messageType == null || action.priority == null) {
      return;
    }

    await _messageService.createOutgoingMessage(
      type: action.messageType!,
      text: action.messageText ?? action.label,
      priority: action.priority!,
      ttlMinutes: action.ttlMinutes,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zpráva byla připravena pro mesh síť.')),
    );
  }

  Future<void> _confirmAndCreateSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SOS zpráva'),
          content: const Text('Opravdu chcete vytvořit SOS zprávu?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Zrušit')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vytvořit SOS')),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _messageService.createOutgoingMessage(
      type: EmergencyMessageType.sos,
      text: 'SOS: potřebuji okamžitou pomoc.',
      priority: EmergencyMessagePriority.critical,
      ttlMinutes: 60,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS zpráva byla vytvořena.')),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();
@override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text('Demo režim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
class _PowerModeSelector extends StatelessWidget {
  const _PowerModeSelector({required this.selectedMode, required this.isEnabled, required this.onChanged});

  final AppPowerMode selectedMode;
  final bool isEnabled;
  final ValueChanged<AppPowerMode> onChanged;
@override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouzový režim baterie', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<AppPowerMode>(
              segments: const [
                ButtonSegment(value: AppPowerMode.normal, label: Text('Normální'), icon: Icon(Icons.dashboard_outlined)),
                ButtonSegment(value: AppPowerMode.batterySaver, label: Text('Úsporný'), icon: Icon(Icons.battery_saver_outlined)),
                ButtonSegment(value: AppPowerMode.ultra, label: Text('Ultra'), icon: Icon(Icons.flash_off_outlined)),
              ],
              selected: {selectedMode},
              onSelectionChanged: isEnabled ? (selection) => onChanged(selection.first) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeMessage extends StatelessWidget {
  const _ModeMessage({required this.mode});

  final AppPowerMode mode;
@override
  Widget build(BuildContext context) {
    final isUltra = mode == AppPowerMode.ultra;
    return Card(
      color: isUltra ? const Color(0xFF3A1B1B) : const Color(0xFF101820),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isUltra ? Icons.warning_amber_outlined : Icons.info_outline, color: const Color(0xFFFFD166)),
            const SizedBox(width: 12),
            Expanded(child: Text(mode.description, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title});

  final IconData icon;
  final String title;
@override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFFD166), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFFFFFFFF)),
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
    return SizedBox(
      height: 96,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB91C1C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: const Text(
          'SOS',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
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
        const SizedBox(height: 12),
        for (final action in _actions) ...[
          SizedBox(
            height: 54,
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
          const SizedBox(height: 10),
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
class _UltraDashboard extends StatelessWidget {
  const _UltraDashboard({
    required this.batteryText,
    required this.mode,
    required this.isLoadingMode,
    required this.onModeChanged,
    required this.onCreateMessage,
    required this.onCreateSos,
    required this.onOpenFindHelp,
    required this.onOpenGuides,
  });

  final String batteryText;
  final AppPowerMode mode;
  final bool isLoadingMode;
  final ValueChanged<AppPowerMode> onModeChanged;
  final ValueChanged<_QuickAction> onCreateMessage;
  final VoidCallback onCreateSos;
  final VoidCallback onOpenFindHelp;
  final VoidCallback onOpenGuides;
@override
  Widget build(BuildContext context) {
    const okAction = _QuickAction(
      Icons.check_circle_outline,
      'Jsem v pořádku',
      messageType: EmergencyMessageType.ok,
      priority: EmergencyMessagePriority.low,
      messageText: 'Jsem v pořádku.',
      ttlMinutes: 240,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Blackout Prague',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(height: 18),
          _PowerModeSelector(selectedMode: mode, isEnabled: !isLoadingMode, onChanged: onModeChanged),
          const SizedBox(height: 16),
          const _ModeMessage(mode: AppPowerMode.ultra),
          const SizedBox(height: 16),
          Text(batteryText, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _SosButton(onPressed: onCreateSos),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => onCreateMessage(okAction),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Jsem v pořádku'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onOpenFindHelp,
              icon: const Icon(Icons.place_outlined),
              label: const Text('Najít nejbližší pomoc'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onOpenGuides,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Návody'),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Mesh: připravena lokální simulace komunikace'),
        ],
      ),
    );
  }
}