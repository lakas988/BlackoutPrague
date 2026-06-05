import 'package:flutter/material.dart';

import '../data/emergency_guides.dart';
import '../models/emergency_guide.dart';
import '../services/demo_mode_service.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _searchController = TextEditingController();
  final _demoModeService = DemoModeService.instance;
  final Map<String, Set<String>> _checkedStepsByGuide = {};

  String _query = '';
  String? _selectedGuideId;
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guides = _filteredGuides;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Krizové návody', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Offline postupy pro nejčastější situace při blackoutu.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD6D9DE)),
          ),
          if (_isDemoModeEnabled) ...[
            const SizedBox(height: 12),
            const _OfflineGuidesBanner(),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Hledat v návodech',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Vymazat hledání',
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    ),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 18),
          Text('Co se děje?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _GuideSelector(
            selectedGuideId: _selectedGuideId,
            onSelected: (guideId) => setState(() => _selectedGuideId = guideId),
          ),
          const SizedBox(height: 18),
          if (guides.isEmpty)
            const _EmptyGuidesMessage()
          else
            for (final guide in guides) ...[
              _GuideCard(
                guide: guide,
                checkedCount: _checkedStepsByGuide[guide.id]?.length ?? 0,
                onOpen: () => _openGuide(guide),
              ),
              const SizedBox(height: 12),
            ],
        ],
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
  List<EmergencyGuide> get _filteredGuides {
    final normalizedQuery = _query.toLowerCase();

    return emergencyGuides.where((guide) {
      final matchesSelected = _selectedGuideId == null || guide.id == _selectedGuideId;
      final matchesQuery = normalizedQuery.isEmpty ||
          guide.title.toLowerCase().contains(normalizedQuery) ||
          guide.description.toLowerCase().contains(normalizedQuery);
      return matchesSelected && matchesQuery;
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _openGuide(EmergencyGuide guide) {
    final checkedSteps = _checkedStepsByGuide.putIfAbsent(guide.id, () => <String>{});

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideDetailScreen(
          guide: guide,
          checkedStepIds: checkedSteps,
          onChecklistChanged: (updatedSteps) {
            setState(() {
              _checkedStepsByGuide[guide.id] = updatedSteps;
            });
          },
        ),
      ),
    );
  }
}


class _OfflineGuidesBanner extends StatelessWidget {
  const _OfflineGuidesBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101820),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.offline_pin_outlined, color: Color(0xFFFFD166)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Návody jsou dostupné offline.', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
class _GuideSelector extends StatelessWidget {
  const _GuideSelector({
    required this.selectedGuideId,
    required this.onSelected,
  });

  final String? selectedGuideId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          selected: selectedGuideId == null,
          label: const Text('Vše'),
          onSelected: (_) => onSelected(null),
        ),
        for (final guide in emergencyGuides)
          FilterChip(
            selected: selectedGuideId == guide.id,
            label: Text(guide.title),
            onSelected: (_) => onSelected(guide.id),
          ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.guide,
    required this.checkedCount,
    required this.onOpen,
  });

  final EmergencyGuide guide;
  final int checkedCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_outlined, color: Color(0xFFFFD166), size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guide.title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(guide.description, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.checklist_outlined, size: 20, color: Color(0xFFFFD166)),
                  const SizedBox(width: 8),
                  Text('$checkedCount / ${guide.steps.length} kroků'),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGuidesMessage extends StatelessWidget {
  const _EmptyGuidesMessage();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('Žádný návod neodpovídá hledání.', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
class GuideDetailScreen extends StatefulWidget {
  const GuideDetailScreen({
    super.key,
    required this.guide,
    required this.checkedStepIds,
    required this.onChecklistChanged,
  });

  final EmergencyGuide guide;
  final Set<String> checkedStepIds;
  final ValueChanged<Set<String>> onChecklistChanged;

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  late final Set<String> _checkedStepIds;

  @override
  void initState() {
    super.initState();
    _checkedStepIds = {...widget.checkedStepIds};
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;

    return Scaffold(
      appBar: AppBar(title: const Text('Krizový návod')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(guide.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(guide.description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            Text('Kontrolní kroky', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final step in guide.steps)
              Card(
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  value: _checkedStepIds.contains(step.id),
                  onChanged: (checked) => _toggleStep(step.id, checked ?? false),
                  title: Text(step.text),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            const SizedBox(height: 18),
            _AdviceSection(
              icon: Icons.block_outlined,
              title: 'Co nedělat',
              items: guide.whatNotToDo,
            ),
            const SizedBox(height: 14),
            _AdviceSection(
              icon: Icons.health_and_safety_outlined,
              title: 'Kdy vyhledat pomoc',
              items: guide.whenToSeekHelp,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStep(String stepId, bool checked) {
    setState(() {
      if (checked) {
        _checkedStepIds.add(stepId);
      } else {
        _checkedStepIds.remove(stepId);
      }
    });

    widget.onChecklistChanged({..._checkedStepIds});
  }
}

class _AdviceSection extends StatelessWidget {
  const _AdviceSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFFD166)),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•'),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}