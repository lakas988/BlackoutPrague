import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/emergency_message.dart';
import '../services/demo_mode_service.dart';
import '../services/message_service.dart';
import '../services/real_ble_mesh_service.dart';

enum _MessageSection {
  outgoing,
  incoming,
  all,
}

enum _MeshMode {
  simulation,
  realBluetooth,
}

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  final _messageService = MessageService.instance;
  final _realBleMeshService = RealBleMeshService.instance;
  final _demoModeService = DemoModeService.instance;
  final _random = math.Random();

  Timer? _incomingTimer;
  bool _isSimulationActive = false;
  bool _isDemoModeEnabled = false;
  int _nearbyNodeCount = 0;
  _MessageSection _selectedSection = _MessageSection.outgoing;
  _MeshMode _selectedMeshMode = _MeshMode.simulation;

  @override
  void initState() {
    super.initState();
    _messageService.addListener(_refreshMessages);
    _realBleMeshService.addListener(_refreshMessages);
    _demoModeService.addListener(_syncDemoMode);
    _loadMeshState();
  }

  @override
  void dispose() {
    _incomingTimer?.cancel();
    _messageService.removeListener(_refreshMessages);
    _realBleMeshService.removeListener(_refreshMessages);
    _demoModeService.removeListener(_syncDemoMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoingCount = _messageService.outgoingMessages.length;
    final incomingCount = _messageService.incomingMessages.length;
    final messages = _messagesForSelectedSection();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Mesh komunikace', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Toto je lokální simulace. Produkční verze by využívala Bluetooth mesh / relay komunikaci mezi telefony.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD6D9DE)),
          ),
          const SizedBox(height: 18),
          if (_isDemoModeEnabled) ...[
            const _DemoMeshBanner(),
            const SizedBox(height: 12),
          ],
          SegmentedButton<_MeshMode>(
            segments: const [
              ButtonSegment(value: _MeshMode.simulation, label: Text('Simulace'), icon: Icon(Icons.science_outlined)),
              ButtonSegment(value: _MeshMode.realBluetooth, label: Text('Reálné Bluetooth'), icon: Icon(Icons.bluetooth_connected_outlined)),
            ],
            selected: {_selectedMeshMode},
            onSelectionChanged: (selection) => setState(() => _selectedMeshMode = selection.first),
          ),
          const SizedBox(height: 14),
          if (_selectedMeshMode == _MeshMode.simulation) ...[
            _MeshStatusCard(
              isSimulationActive: _isSimulationActive,
              nearbyNodeCount: _nearbyNodeCount,
              outgoingCount: outgoingCount,
              incomingCount: incomingCount,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _toggleSimulation,
                icon: Icon(_isSimulationActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                label: Text(_isSimulationActive ? 'Vypnout simulaci mesh' : 'Zapnout simulaci mesh'),
              ),
            ),
          ] else ...[
            _RealBleStatusCard(
              permissionStatus: _realBleMeshService.permissionStatus,
              isScanning: _realBleMeshService.isScanning,
              isAdvertising: _realBleMeshService.isAdvertising,
              receivedCount: _realBleMeshService.receivedCount,
              lastError: _realBleMeshService.lastError,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _toggleRealBle,
                icon: Icon(_realBleMeshService.isEnabled ? Icons.bluetooth_disabled_outlined : Icons.bluetooth_searching_outlined),
                label: Text(_realBleMeshService.isEnabled ? 'Vypnout reálné Bluetooth' : 'Zapnout reálné Bluetooth'),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SegmentedButton<_MessageSection>(
            segments: const [
              ButtonSegment(value: _MessageSection.outgoing, label: Text('Odeslané'), icon: Icon(Icons.north_east_outlined)),
              ButtonSegment(value: _MessageSection.incoming, label: Text('Přijaté'), icon: Icon(Icons.south_west_outlined)),
              ButtonSegment(value: _MessageSection.all, label: Text('Všechny zprávy'), icon: Icon(Icons.forum_outlined)),
            ],
            selected: {_selectedSection},
            onSelectionChanged: (selection) => setState(() => _selectedSection = selection.first),
          ),
          const SizedBox(height: 18),
          if (messages.isEmpty)
            const _EmptyMessagesCard()
          else
            for (final message in messages) ...[
              _MessageCard(
                message: message,
                onConfirm: () => _confirmMessage(message),
                onRelay: () => _relayMessage(message),
                onMarkOutdated: () => _markMessageOutdated(message),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }


  Future<void> _loadMeshState() async {
    await _messageService.loadMessages();
    await _demoModeService.load();
    if (_demoModeService.isEnabled) {
      await _messageService.addDemoMessagesIfNeeded();
    }
    if (!mounted) {
      return;
    }
    setState(() => _isDemoModeEnabled = _demoModeService.isEnabled);
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
  List<EmergencyMessage> _messagesForSelectedSection() {
    return switch (_selectedSection) {
      _MessageSection.outgoing => _messageService.outgoingMessages,
      _MessageSection.incoming => _messageService.incomingMessages,
      _MessageSection.all => _messageService.messages,
    };
  }

  void _refreshMessages() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleSimulation() {
    setState(() {
      _isSimulationActive = !_isSimulationActive;
      _nearbyNodeCount = _isSimulationActive ? 2 + _random.nextInt(7) : 0;
    });

    if (_isSimulationActive) {
      _scheduleIncomingSample();
    } else {
      _incomingTimer?.cancel();
      _incomingTimer = null;
    }
  }

  Future<void> _toggleRealBle() async {
    if (_realBleMeshService.isEnabled) {
      await _realBleMeshService.stopRealBle();
    } else {
      await _realBleMeshService.startRealBle();
    }
  }

  void _scheduleIncomingSample() {
    _incomingTimer?.cancel();
    final seconds = 30 + _random.nextInt(31);
    _incomingTimer = Timer(Duration(seconds: seconds), () async {
      if (!_isSimulationActive) {
        return;
      }

      await _messageService.addIncomingSample(
        type: _sampleType(),
        text: _sampleText(),
        priority: _samplePriority(),
        senderAlias: 'Uzel ${100 + _random.nextInt(900)}',
        approximateArea: _sampleArea(),
        ttlMinutes: 120,
        hopCount: 1 + _random.nextInt(3),
        verifiedCount: _random.nextInt(2),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearbyNodeCount = 2 + _random.nextInt(7);
      });
      _scheduleIncomingSample();
    });
  }

  EmergencyMessageType _sampleType() {
    final types = [
      EmergencyMessageType.water,
      EmergencyMessageType.danger,
      EmergencyMessageType.info,
      EmergencyMessageType.medication,
    ];
    return types[_random.nextInt(types.length)];
  }

  EmergencyMessagePriority _samplePriority() {
    final priorities = [
      EmergencyMessagePriority.medium,
      EmergencyMessagePriority.high,
      EmergencyMessagePriority.medium,
      EmergencyMessagePriority.high,
    ];
    return priorities[_random.nextInt(priorities.length)];
  }

  String _sampleText() {
    final texts = [
      'Výdej vody hlášen u školy.',
      'Nefunkční křižovatka.',
      'Dobíjecí místo dostupné.',
      'Osoba potřebuje léky.',
    ];
    return texts[_random.nextInt(texts.length)];
  }

  String _sampleArea() {
    final areas = ['Praha 1', 'Praha 3', 'Praha 6', 'Praha 8', 'Praha 10', 'Praha 11'];
    return areas[_random.nextInt(areas.length)];
  }

  Future<void> _confirmMessage(EmergencyMessage message) async {
    await _messageService.confirmMessage(message.id);
    _showSnackBar('Hlášení bylo potvrzeno.');
  }

  Future<void> _relayMessage(EmergencyMessage message) async {
    final relayedMessage = await _messageService.relayMessageAndReturn(message.id);
    if (relayedMessage == null) {
      _showSnackBar('Zprávu se nepodařilo předat dál.');
      return;
    }

    if (_realBleMeshService.isEnabled) {
      final wasBroadcast = await _realBleMeshService.broadcastMessage(relayedMessage);
      _showSnackBar(wasBroadcast ? 'Zpráva byla předána dál přes BLE mesh.' : (_realBleMeshService.lastError ?? 'Toto zařízení nepodporuje BLE vysílání.'));
    } else {
      _showSnackBar('Zpráva byla předána dál v simulaci.');
    }
  }

  Future<void> _markMessageOutdated(EmergencyMessage message) async {
    await _messageService.markMessageOutdated(message.id);
    _showSnackBar('Zpráva byla označena jako neaktuální.');
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DemoMeshBanner extends StatelessWidget {
  const _DemoMeshBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Demo režim: přijaté zprávy jsou ukázková data pro prezentaci porotě.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
class _MeshStatusCard extends StatelessWidget {
  const _MeshStatusCard({
    required this.isSimulationActive,
    required this.nearbyNodeCount,
    required this.outgoingCount,
    required this.incomingCount,
  });

  final bool isSimulationActive;
  final int nearbyNodeCount;
  final int outgoingCount;
  final int incomingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stav mesh sítě', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _StatusLine(label: 'Stav', value: isSimulationActive ? 'Simulace aktivní' : 'Simulace neaktivní'),
            _StatusLine(label: 'Okolní uzly', value: '$nearbyNodeCount'),
            _StatusLine(label: 'Odeslané zprávy', value: '$outgoingCount'),
            _StatusLine(label: 'Přijaté zprávy', value: '$incomingCount'),
          ],
        ),
      ),
    );
  }
}

class _RealBleStatusCard extends StatelessWidget {
  const _RealBleStatusCard({
    required this.permissionStatus,
    required this.isScanning,
    required this.isAdvertising,
    required this.receivedCount,
    required this.lastError,
  });

  final String permissionStatus;
  final bool isScanning;
  final bool isAdvertising;
  final int receivedCount;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reálné Bluetooth mesh', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Store-and-forward BLE prototyp bez internetu. Nejde o produkční Bluetooth Mesh standard.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD6D9DE)),
            ),
            const SizedBox(height: 14),
            _StatusLine(label: 'Oprávnění', value: permissionStatus),
            _StatusLine(label: 'Skenování', value: isScanning ? 'aktivní' : 'neaktivní'),
            _StatusLine(label: 'Vysílání', value: isAdvertising ? 'aktivní' : 'neaktivní'),
            _StatusLine(label: 'Přijaté BLE zprávy', value: '$receivedCount'),
            if (lastError != null) ...[
              const SizedBox(height: 8),
              Text(lastError!, style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFD6D9DE)))),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _EmptyMessagesCard extends StatelessWidget {
  const _EmptyMessagesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('Zatím zde nejsou žádné zprávy.', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.onConfirm,
    required this.onRelay,
    required this.onMarkOutdated,
  });

  final EmergencyMessage message;
  final VoidCallback onConfirm;
  final VoidCallback onRelay;
  final VoidCallback onMarkOutdated;

  @override
  Widget build(BuildContext context) {
    final inactive = message.isExpired || message.isOutdated;

    return Opacity(
      opacity: inactive ? 0.58 : 1,
      child: Card(
        color: inactive ? const Color(0xFF111318) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_typeIcon(message.type), color: const Color(0xFFFFD166), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.type.czechLabel, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(message.text, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(text: 'Priorita: ${message.priority.czechLabel}', color: _priorityColor(message.priority)),
                  _Badge(text: message.isOutgoing ? 'Odeslaná' : 'Přijatá'),
                  if (message.isDemo) const _Badge(text: 'Demo / ukázková zpráva', color: Color(0xFF7F1D1D)),
                  if (message.isExpired) const _Badge(text: 'Vypršelo', color: Color(0xFF7F1D1D)),
                  if (message.isOutdated) const _Badge(text: 'Neaktuální', color: Color(0xFF7F1D1D)),
                ],
              ),
              const SizedBox(height: 14),
              _InfoLine(icon: Icons.location_city_outlined, text: 'Oblast: ${message.approximateArea}'),
              _InfoLine(icon: Icons.schedule_outlined, text: 'Vytvořeno: ${_createdAtText(message.createdAt)}'),
              _InfoLine(icon: Icons.route_outlined, text: 'Počet předání: ${message.hopCount}'),
              _InfoLine(icon: Icons.verified_outlined, text: 'Počet potvrzení: ${message.verifiedCount}'),
              _InfoLine(icon: Icons.timer_outlined, text: _ttlText(message)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: inactive ? null : onConfirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Potvrdit hlášení'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: inactive ? null : onRelay,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Předat dál'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: message.isOutdated ? null : onMarkOutdated,
                  icon: const Icon(Icons.history_toggle_off_outlined),
                  label: const Text('Označit jako neaktuální'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(EmergencyMessageType type) {
    return switch (type) {
      EmergencyMessageType.ok => Icons.check_circle_outline,
      EmergencyMessageType.sos => Icons.warning_amber_outlined,
      EmergencyMessageType.medical => Icons.medical_services_outlined,
      EmergencyMessageType.water => Icons.water_drop_outlined,
      EmergencyMessageType.medication => Icons.medication_outlined,
      EmergencyMessageType.danger => Icons.report_problem_outlined,
      EmergencyMessageType.info => Icons.info_outline,
    };
  }

  Color _priorityColor(EmergencyMessagePriority priority) {
    return switch (priority) {
      EmergencyMessagePriority.low => const Color(0xFF166534),
      EmergencyMessagePriority.medium => const Color(0xFF1D4ED8),
      EmergencyMessagePriority.high => const Color(0xFFB45309),
      EmergencyMessagePriority.critical => const Color(0xFF991B1B),
    };
  }

  String _createdAtText(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'právě teď';
    }
    if (difference.inHours < 1) {
      return 'před ${difference.inMinutes} min';
    }
    if (difference.inDays < 1) {
      return 'před ${difference.inHours} h';
    }
    return 'před ${difference.inDays} dny';
  }

  String _ttlText(EmergencyMessage message) {
    final elapsedMinutes = DateTime.now().difference(message.createdAt).inMinutes;
    final remainingMinutes = message.ttlMinutes - elapsedMinutes;
    if (remainingMinutes <= 0) {
      return 'TTL: zpráva vypršela';
    }
    return 'TTL: zbývá $remainingMinutes min';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color = const Color(0xFF263241)});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFFD166)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}