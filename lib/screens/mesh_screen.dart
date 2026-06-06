import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/emergency_message.dart';
import '../models/user_profile.dart';
import '../services/demo_mode_service.dart';
import '../services/mesh_foreground_service.dart';
import '../services/mesh_settings_service.dart';
import '../services/message_service.dart';
import '../services/profile_storage_service.dart';
import '../services/real_ble_mesh_service.dart';
import 'settings_screen.dart';

enum _MessageSection {
  incoming,
  outgoing,
  all,
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
  final _meshSettingsService = MeshSettingsService.instance;
  final _meshForegroundService = MeshForegroundService.instance;
  final _profileStorageService = ProfileStorageService();
  final _random = math.Random();

  Timer? _incomingTimer;
  static const int _customMessageMaxLength = 40;

  final _customMessageController = TextEditingController();
  bool _isSimulationActive = false;
  bool _isDemoModeEnabled = false;
  bool _backgroundMeshEnabled = false;
  bool _notificationsEnabled = false;
  int _nearbyNodeCount = 0;
  _MessageSection _selectedSection = _MessageSection.incoming;

  @override
  void initState() {
    super.initState();
    _messageService.addListener(_refreshMessages);
    _realBleMeshService.addListener(_refreshMessages);
    _demoModeService.addListener(_syncDemoMode);
    _meshSettingsService.addListener(_syncMeshSettings);
    _meshForegroundService.addListener(_refreshMessages);
    _customMessageController.addListener(_refreshMessages);
    _loadMeshState();
  }

  @override
  void dispose() {
    _incomingTimer?.cancel();
    _messageService.removeListener(_refreshMessages);
    _realBleMeshService.removeListener(_refreshMessages);
    _demoModeService.removeListener(_syncDemoMode);
    _meshSettingsService.removeListener(_syncMeshSettings);
    _meshForegroundService.removeListener(_refreshMessages);
    _customMessageController.removeListener(_refreshMessages);
    _customMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomingMessages = _visibleMessages(_messageService.incomingMessages);
    final outgoingMessages = _visibleMessages(_messageService.outgoingMessages);
    final selectedMessages = _messagesForSelectedSection(incomingMessages, outgoingMessages);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Mesh komunikace', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Reálný Bluetooth mesh přijímá krátké krizové zprávy mezi zařízeními bez internetu.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC7D0DC)),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Stav sítě'),
          const SizedBox(height: 8),
          _RealBleStatusCard(
            isEnabled: _realBleMeshService.isEnabled,
            permissionStatus: _realBleMeshService.permissionStatus,
            isScanning: _realBleMeshService.isScanning,
            isAdvertising: _realBleMeshService.isAdvertising,
            isBackgroundEnabled: _backgroundMeshEnabled,
            isForegroundServiceRunning: _meshForegroundService.isRunning,
            notificationsEnabled: _notificationsEnabled,
            receivedCount: _realBleMeshService.receivedCount,
            lastError: _realBleMeshService.lastError,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _toggleRealBle,
              icon: Icon(_realBleMeshService.isEnabled ? Icons.bluetooth_disabled_outlined : Icons.bluetooth_searching_outlined),
              label: Text(_realBleMeshService.isEnabled ? 'Vypnout Reálný Bluetooth mesh' : 'Zapnout Reálný Bluetooth mesh'),
            ),
          ),
          if (!_realBleMeshService.isEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Zapněte Bluetooth mesh pro příjem zpráv.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFC7D0DC)),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openMeshSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Otevřít nastavení mesh'),
            ),
          ),
          const SizedBox(height: 16),
          _CustomTextMessageCard(
            controller: _customMessageController,
            maxLength: _customMessageMaxLength,
            onSend: _sendCustomTextMessage,
          ),
          const SizedBox(height: 12),
          _ProfileInfoMessageCard(onSend: _confirmAndSendProfileInfo),
          if (_isDemoModeEnabled) ...[
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Simulace mesh'),
            const SizedBox(height: 8),
            _DemoSimulationCard(
              isSimulationActive: _isSimulationActive,
              nearbyNodeCount: _nearbyNodeCount,
              incomingCount: incomingMessages.where((message) => message.isDemo).length,
              onToggle: _toggleSimulation,
            ),
          ],
          const SizedBox(height: 20),
          _MessageSectionHeader(
            selectedSection: _selectedSection,
            onSectionChanged: (section) => setState(() => _selectedSection = section),
            onDeleteAll: _deleteAllActionForSelectedSection(incomingMessages, outgoingMessages),
          ),
          const SizedBox(height: 12),
          if (selectedMessages.isEmpty)
            _EmptyMessagesCard(text: _emptyTextForSelectedSection())
          else
            for (final message in selectedMessages) ...[
              _MessageCard(
                message: message,
                onConfirm: () => _confirmMessage(message),
                onRelay: () => _relayMessage(message),
                onMarkOutdated: () => _markMessageOutdated(message),
                onDelete: () => message.isOutgoing ? _confirmDeleteOutgoingMessage(message) : _confirmDeleteIncomingMessage(message),
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
    await _meshSettingsService.load();
    await _meshForegroundService.refreshStatus();
    if (_demoModeService.isEnabled) {
      await _messageService.addDemoMessagesIfNeeded();
    } else {
      await _messageService.clearDemoMessages();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isDemoModeEnabled = _demoModeService.isEnabled;
      _backgroundMeshEnabled = _meshSettingsService.backgroundMeshEnabled;
      _notificationsEnabled = _meshSettingsService.notificationsEnabled;
    });
  }

  void _syncDemoMode() {
    if (!mounted) {
      return;
    }

    final enabled = _demoModeService.isEnabled;
    setState(() {
      _isDemoModeEnabled = enabled;
      if (!enabled) {
        _isSimulationActive = false;
        _nearbyNodeCount = 0;
      }
    });

    if (enabled) {
      _messageService.addDemoMessagesIfNeeded();
    } else {
      _incomingTimer?.cancel();
      _incomingTimer = null;
      _messageService.clearDemoMessages();
    }
  }

  void _syncMeshSettings() {
    if (!mounted) {
      return;
    }

    setState(() {
      _backgroundMeshEnabled = _meshSettingsService.backgroundMeshEnabled;
      _notificationsEnabled = _meshSettingsService.notificationsEnabled;
    });
  }

  List<EmergencyMessage> _visibleMessages(List<EmergencyMessage> messages) {
    if (_isDemoModeEnabled) {
      return messages;
    }
    return messages.where((message) => !message.isDemo).toList(growable: false);
  }

  List<EmergencyMessage> _messagesForSelectedSection(
    List<EmergencyMessage> incomingMessages,
    List<EmergencyMessage> outgoingMessages,
  ) {
    return switch (_selectedSection) {
      _MessageSection.incoming => incomingMessages,
      _MessageSection.outgoing => outgoingMessages,
      _MessageSection.all => [...incomingMessages, ...outgoingMessages]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    };
  }

  String _emptyTextForSelectedSection() {
    return switch (_selectedSection) {
      _MessageSection.incoming => 'Zatím nejsou žádné přijaté zprávy.',
      _MessageSection.outgoing => 'Zatím nejsou žádné odeslané zprávy.',
      _MessageSection.all => 'Zatím nejsou žádné zprávy.',
    };
  }

  VoidCallback? _deleteAllActionForSelectedSection(
    List<EmergencyMessage> incomingMessages,
    List<EmergencyMessage> outgoingMessages,
  ) {
    return switch (_selectedSection) {
      _MessageSection.incoming => incomingMessages.isEmpty ? null : () => _confirmDeleteAllIncoming(incomingMessages),
      _MessageSection.outgoing => outgoingMessages.isEmpty ? null : () => _confirmDeleteAllOutgoing(outgoingMessages),
      _MessageSection.all => null,
    };
  }

  void _refreshMessages() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleSimulation() {
    if (!_isDemoModeEnabled) {
      _showSnackBar('Simulace mesh je dostupná pouze v Demo režimu.');
      return;
    }

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

  void _openMeshSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  Future<void> _sendCustomTextMessage() async {
    final text = _customMessageController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Zadejte zprávu.');
      return;
    }

    if (text.runes.length > _customMessageMaxLength) {
      _showSnackBar('Zpráva je příliš dlouhá pro BLE mesh. Zkraťte ji na 40 znaků.');
      return;
    }

    final message = await _messageService.createOutgoingMessage(
      type: EmergencyMessageType.info,
      text: text,
      priority: EmergencyMessagePriority.medium,
      ttlMinutes: 60,
      isCustomTextMessage: true,
    );
    _customMessageController.clear();

    if (!mounted) {
      return;
    }

    if (_realBleMeshService.isEnabled) {
      final wasBroadcast = await _realBleMeshService.broadcastMessage(message);
      _showSnackBar(wasBroadcast ? 'Zpráva se vysílá přes BLE mesh.' : (_realBleMeshService.lastError ?? 'Zprávu se nepodařilo odeslat přes BLE mesh.'));
      return;
    }

    _showSnackBar('Zpráva je uložená. Pro odeslání zapněte BLE mesh.');
  }

  Future<void> _confirmAndSendProfileInfo() async {
    final profile = await _profileStorageService.loadProfile();
    if (!mounted) {
      return;
    }

    if (profile == null) {
      _showSnackBar('Nejdříve vyplňte profil.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Poslat základní info z profilu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Následující informace budou odeslány do okolní mesh sítě:'),
              const SizedBox(height: 12),
              Text('Role: ${profile.role.czechLabel}'),
              Text('Oblast: ${profile.district.trim().isEmpty ? 'Praha' : profile.district}'),
              Text('Potřebuji léky: ${_yesNo(profile.needsMedication)}'),
              Text('Mám děti: ${_yesNo(profile.hasChildren)}'),
              Text('Senior v domácnosti: ${_yesNo(profile.hasSeniorAtHome)}'),
              Text('Mazlíček: ${_yesNo(profile.hasPet)}'),
              const SizedBox(height: 12),
              const Text('Telefonní číslo, kontakt ani zdravotní poznámky se neposílají.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Zrušit')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Odeslat')),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final message = await _messageService.createOutgoingProfileInfoMessage(profile);
    if (!mounted) {
      return;
    }

    if (_realBleMeshService.isEnabled) {
      final wasBroadcast = await _realBleMeshService.broadcastMessage(message);
      _showSnackBar(
        wasBroadcast
            ? 'Profilová informace se vysílá přes BLE mesh.'
            : (_realBleMeshService.lastError ?? 'Profilovou informaci se nepodařilo odeslat přes BLE mesh.'),
      );
      return;
    }

    _showSnackBar('Profilová informace je uložená. Pro odeslání zapněte BLE mesh.');
  }

  String _yesNo(bool value) => value ? 'ano' : 'ne';

  void _scheduleIncomingSample() {
    _incomingTimer?.cancel();
    final seconds = 30 + _random.nextInt(31);
    _incomingTimer = Timer(Duration(seconds: seconds), () async {
      if (!_isSimulationActive || !_isDemoModeEnabled) {
        return;
      }

      await _messageService.addIncomingSample(
        type: _sampleType(),
        text: 'Demo: ${_sampleText()}',
        priority: _samplePriority(),
        senderAlias: 'Demo uzel ${100 + _random.nextInt(900)}',
        approximateArea: _sampleArea(),
        ttlMinutes: 120,
        hopCount: 1 + _random.nextInt(3),
        verifiedCount: _random.nextInt(2),
        isDemo: true,
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
    if (message.isExpired) {
      _showSnackBar('Zpráva je po platnosti a nebude předána dál.');
      return;
    }

    if (message.hopCount >= message.maxHops) {
      _showSnackBar('Zpráva dosáhla limitu předání.');
      return;
    }

    final relayedMessage = await _messageService.relayMessageAndReturn(message.id);
    if (relayedMessage == null) {
      _showSnackBar('Zprávu se nepodařilo předat dál.');
      return;
    }

    if (_realBleMeshService.isEnabled) {
      final wasBroadcast = await _realBleMeshService.broadcastMessage(relayedMessage);
      _showSnackBar(wasBroadcast ? 'Zpráva byla předána dál přes BLE mesh.' : (_realBleMeshService.lastError ?? 'Toto zařízení nepodporuje BLE vysílání.'));
      return;
    }

    if (_isDemoModeEnabled && _isSimulationActive) {
      _showSnackBar('Zpráva byla předána dál v Simulaci mesh.');
    } else {
      _showSnackBar('Zapněte Bluetooth mesh pro odeslání.');
    }
  }

  Future<void> _markMessageOutdated(EmergencyMessage message) async {
    await _messageService.markMessageOutdated(message.id);
    _showSnackBar('Zpráva byla označena jako neaktuální.');
  }

  Future<void> _confirmDeleteIncomingMessage(EmergencyMessage message) async {
    await _confirmDeleteMessage(
      message: message,
      title: 'Smazat přijatou zprávu',
      question: 'Opravdu chcete smazat tuto zprávu?',
      successMessage: 'Přijatá zpráva byla smazána.',
    );
  }

  Future<void> _confirmDeleteOutgoingMessage(EmergencyMessage message) async {
    await _confirmDeleteMessage(
      message: message,
      title: 'Smazat odeslanou zprávu',
      question: 'Opravdu chcete smazat tuto odeslanou zprávu?',
      successMessage: 'Odeslaná zpráva byla smazána.',
    );
  }

  Future<void> _confirmDeleteMessage({
    required EmergencyMessage message,
    required String title,
    required String question,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Zrušit')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Smazat')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _messageService.deleteMessage(message.id);
    _showSnackBar(successMessage);
  }

  Future<void> _confirmDeleteAllIncoming(List<EmergencyMessage> incomingMessages) async {
    await _confirmDeleteMessages(
      messages: incomingMessages,
      title: 'Smazat přijaté zprávy',
      question: 'Opravdu chcete smazat všechny přijaté zprávy?',
      successMessage: 'Přijaté zprávy byly smazány.',
    );
  }

  Future<void> _confirmDeleteAllOutgoing(List<EmergencyMessage> outgoingMessages) async {
    await _confirmDeleteMessages(
      messages: outgoingMessages,
      title: 'Smazat odeslané zprávy',
      question: 'Opravdu chcete smazat všechny odeslané zprávy?',
      successMessage: 'Odeslané zprávy byly smazány.',
    );
  }

  Future<void> _confirmDeleteMessages({
    required List<EmergencyMessage> messages,
    required String title,
    required String question,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Zrušit')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Smazat vše')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _messageService.deleteMessagesById(messages.map((message) => message.id).toSet());
    _showSnackBar(successMessage);
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}


class _CustomTextMessageCard extends StatelessWidget {
  const _CustomTextMessageCard({
    required this.controller,
    required this.maxLength,
    required this.onSend,
  });

  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final length = controller.text.trim().runes.length;
    final isTooLong = length > maxLength;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Odeslat textovou zprávu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Krátká zpráva...',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Např. Jsme v pořádku, Potřebuji vodu, Léky nutné.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '$length/$maxLength',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isTooLong ? const Color(0xFFFF1F1F) : const Color(0xFFC7D0DC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (isTooLong) ...[
              const SizedBox(height: 8),
              Text(
                'Zpráva je příliš dlouhá pro BLE mesh. Zkraťte ji na 40 znaků.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFFF1F1F)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Odeslat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoMessageCard extends StatelessWidget {
  const _ProfileInfoMessageCard({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Poslat základní info z profilu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Odešle jen roli, oblast a krátké příznaky pro krizovou pomoc. Telefon, kontakt ani zdravotní poznámky se neposílají.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Poslat základní info z profilu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _MessageSectionHeader extends StatelessWidget {
  const _MessageSectionHeader({
    required this.selectedSection,
    required this.onSectionChanged,
    required this.onDeleteAll,
  });

  final _MessageSection selectedSection;
  final ValueChanged<_MessageSection> onSectionChanged;
  final VoidCallback? onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_MessageSection>(
          segments: const [
            ButtonSegment(value: _MessageSection.incoming, label: Text('Přijaté'), icon: Icon(Icons.south_west_outlined)),
            ButtonSegment(value: _MessageSection.outgoing, label: Text('Odeslané'), icon: Icon(Icons.north_east_outlined)),
            ButtonSegment(value: _MessageSection.all, label: Text('Všechny'), icon: Icon(Icons.forum_outlined)),
          ],
          selected: {selectedSection},
          onSelectionChanged: (selection) => onSectionChanged(selection.first),
        ),
        if (onDeleteAll != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDeleteAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Smazat vše'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RealBleStatusCard extends StatelessWidget {
  const _RealBleStatusCard({
    required this.isEnabled,
    required this.permissionStatus,
    required this.isScanning,
    required this.isAdvertising,
    required this.isBackgroundEnabled,
    required this.isForegroundServiceRunning,
    required this.notificationsEnabled,
    required this.receivedCount,
    required this.lastError,
  });

  final bool isEnabled;
  final String permissionStatus;
  final bool isScanning;
  final bool isAdvertising;
  final bool isBackgroundEnabled;
  final bool isForegroundServiceRunning;
  final bool notificationsEnabled;
  final int receivedCount;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isEnabled ? Icons.bluetooth_connected_outlined : Icons.bluetooth_outlined, color: const Color(0xFF00D1FF), size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(isEnabled ? 'Reálný Bluetooth mesh je zapnutý' : 'Reálný Bluetooth mesh je vypnutý', style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 10),
            _StatusLine(label: 'Oprávnění', value: permissionStatus),
            _StatusLine(label: 'Příjem zpráv', value: isScanning ? 'aktivní' : 'neaktivní'),
            _StatusLine(label: 'Odesílání', value: isAdvertising ? 'aktivní' : 'neaktivní'),
            _StatusLine(label: 'Běh na pozadí', value: isBackgroundEnabled ? (isForegroundServiceRunning ? 'aktivní' : 'povolen') : 'vypnut'),
            _StatusLine(label: 'Oznámení', value: notificationsEnabled ? 'povolena' : 'vypnuta'),
            _StatusLine(label: 'Přijaté zprávy', value: '$receivedCount'),
            if (lastError != null) ...[
              const SizedBox(height: 6),
              Text(lastError!, style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemoSimulationCard extends StatelessWidget {
  const _DemoSimulationCard({
    required this.isSimulationActive,
    required this.nearbyNodeCount,
    required this.incomingCount,
    required this.onToggle,
  });

  final bool isSimulationActive;
  final int nearbyNodeCount;
  final int incomingCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2230),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text('Simulace mesh', style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Demo režim zapíná ukázková data a simulované zprávy pro prezentaci.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            _StatusLine(label: 'Stav', value: isSimulationActive ? 'aktivní' : 'neaktivní'),
            _StatusLine(label: 'Ukázkové okolní uzly', value: '$nearbyNodeCount'),
            _StatusLine(label: 'Demo přijaté zprávy', value: '$incomingCount'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onToggle,
                icon: Icon(isSimulationActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                label: Text(isSimulationActive ? 'Vypnout Simulaci mesh' : 'Zapnout Simulaci mesh'),
              ),
            ),
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
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFC7D0DC)))),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _EmptyMessagesCard extends StatelessWidget {
  const _EmptyMessagesCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
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
    required this.onDelete,
  });

  final EmergencyMessage message;
  final VoidCallback onConfirm;
  final VoidCallback onRelay;
  final VoidCallback onMarkOutdated;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inactive = message.isExpired || message.isOutdated;
    final important = message.priority == EmergencyMessagePriority.high || message.priority == EmergencyMessagePriority.critical;
    final cardColor = inactive
        ? const Color(0xFF121821)
        : important
            ? const Color(0xFF1A2230)
            : null;

    return Opacity(
      opacity: inactive ? 0.58 : 1,
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_typeIcon(message), color: important ? const Color(0xFFFF1F1F) : const Color(0xFF00D1FF), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_messageTitle(message), style: Theme.of(context).textTheme.titleLarge),
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
                  if (message.isDemo) const _Badge(text: 'Demo', color: Color(0xFFFF1F1F)),
                  if (message.isExpired) const _Badge(text: 'Vypršelo', color: Color(0xFFFF1F1F)),
                  if (message.isOutdated) const _Badge(text: 'Neaktuální', color: Color(0xFFFF1F1F)),
                ],
              ),
              const SizedBox(height: 12),
              if (message.isProfileInfoMessage) ...[
                _InfoLine(icon: Icons.badge_outlined, text: 'Role: ${_profileRoleLabel(message.profileRoleCode)}'),
                _InfoLine(icon: Icons.medication_outlined, text: 'Léky: ${_flagYesNo(message.profileFlags, 'M')}'),
                _InfoLine(icon: Icons.child_care_outlined, text: 'Děti: ${_flagYesNo(message.profileFlags, 'C')}'),
                _InfoLine(icon: Icons.elderly_outlined, text: 'Senior: ${_flagYesNo(message.profileFlags, 'S')}'),
                _InfoLine(icon: Icons.pets_outlined, text: 'Mazlíček: ${_flagYesNo(message.profileFlags, 'P')}'),
              ],
              _InfoLine(icon: Icons.tag_outlined, text: 'ID: ${message.shortId}'),
              _InfoLine(icon: Icons.location_city_outlined, text: 'Oblast: ${message.approximateArea}'),
              _InfoLine(icon: Icons.schedule_outlined, text: 'Čas: ${_createdAtText(message.createdAt)}'),
              _InfoLine(icon: Icons.route_outlined, text: 'Předání: ${message.hopCount}/${message.maxHops}'),
              _InfoLine(icon: Icons.verified_outlined, text: 'Ověření: ${message.verifiedCount}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: inactive ? null : onConfirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Potvrdit'),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: message.isOutdated ? null : onMarkOutdated,
                      icon: const Icon(Icons.history_toggle_off_outlined),
                      label: const Text('Neaktuální'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Smazat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _messageTitle(EmergencyMessage message) {
    if (message.isProfileInfoMessage) {
      return 'Profilová informace';
    }
    if (message.isCustomTextMessage) {
      return 'Textová zpráva';
    }
    return message.type.czechLabel;
  }

  IconData _typeIcon(EmergencyMessage message) {
    if (message.isProfileInfoMessage) {
      return Icons.badge_outlined;
    }
    return switch (message.type) {
      EmergencyMessageType.ok => Icons.check_circle_outline,
      EmergencyMessageType.sos => Icons.warning_amber_outlined,
      EmergencyMessageType.medical => Icons.medical_services_outlined,
      EmergencyMessageType.water => Icons.water_drop_outlined,
      EmergencyMessageType.medication => Icons.medication_outlined,
      EmergencyMessageType.danger => Icons.report_problem_outlined,
      EmergencyMessageType.info => Icons.info_outline,
    };
  }

  String _profileRoleLabel(String? roleCode) {
    return switch ((roleCode ?? 'CIT').toUpperCase()) {
      'VOL' => 'Dobrovolník',
      'MED' => 'Zdravotník',
      'FIR' => 'Hasič',
      'POL' => 'Policista',
      'TEC' => 'Technik',
      _ => 'Obyvatel',
    };
  }

  String _flagYesNo(String? flags, String flag) {
    return (flags ?? '').toUpperCase().contains(flag) ? 'ano' : 'ne';
  }

  Color _priorityColor(EmergencyMessagePriority priority) {
    return switch (priority) {
      EmergencyMessagePriority.low => const Color(0xFF2ED573),
      EmergencyMessagePriority.medium => const Color(0xFF00D1FF),
      EmergencyMessagePriority.high => const Color(0xFFFF9F43),
      EmergencyMessagePriority.critical => const Color(0xFFFF1F1F),
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
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color = const Color(0xFF1A2230)});

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
          Icon(icon, size: 20, color: const Color(0xFF00D1FF)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}


