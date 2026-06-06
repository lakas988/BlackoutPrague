import 'package:flutter/material.dart';

import '../data/prague_areas.dart';
import '../data/prague_help_points.dart';
import '../models/app_location.dart';
import '../models/help_point.dart';
import '../models/prague_area.dart';
import '../services/demo_mode_service.dart';
import '../services/location_service.dart';
import '../services/selected_area_service.dart';
import 'map_screen.dart';

class FindHelpScreen extends StatefulWidget {
  const FindHelpScreen({super.key, this.onShowHelpPointOnMap});

  final ValueChanged<String>? onShowHelpPointOnMap;

  @override
  State<FindHelpScreen> createState() => _FindHelpScreenState();
}

class _FindHelpScreenState extends State<FindHelpScreen> {
  static const _maximumResultCount = 5;

  final _selectedAreaService = SelectedAreaService();
  final _demoModeService = DemoModeService.instance;
  final _locationService = LocationService();

  String _selectedNeed = 'Zdravotní pomoc';
  PragueArea _selectedArea = getDefaultPragueArea();
  AppLocation? _lastKnownLocation;
  bool _isDemoModeEnabled = false;
  bool _isUpdatingLocation = false;
  String? _locationMessage;

  static const _categories = <_HelpCategory>[
    _HelpCategory('Zdravotní pomoc', Icons.medical_services_outlined),
    _HelpCategory('Policie', Icons.local_police_outlined),
    _HelpCategory('Hasiči', Icons.fire_truck_outlined),
    _HelpCategory('Voda', Icons.water_drop_outlined),
    _HelpCategory('Nabíjení telefonu', Icons.battery_charging_full_outlined),
    _HelpCategory('Přístřeší', Icons.night_shelter_outlined),
    _HelpCategory('Krizové centrum', Icons.support_agent_outlined),
    _HelpCategory('Lékárna / léky', Icons.medication_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _demoModeService.addListener(_syncDemoMode);
    _loadState();
  }

  @override
  void dispose() {
    _demoModeService.removeListener(_syncDemoMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsResults = _gpsResults();
    final areaResults = _selectedAreaResults();
    final outsideResults = _outsideAreaResults(areaResults.length);
    final usesGps = _lastKnownLocation != null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Najít nejbližší pomoc', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Poloha se používá jen jednorázově kvůli úspoře baterie.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC7D0DC)),
          ),
          const SizedBox(height: 18),
          _LocationSourceCard(
            selectedArea: _selectedArea,
            lastKnownLocation: _lastKnownLocation,
            isUpdatingLocation: _isUpdatingLocation,
            locationMessage: _locationMessage,
            onAreaChanged: _selectArea,
            onUpdateLocation: _updateLocationOnce,
            onClearLocation: _clearLastKnownLocation,
          ),
          const SizedBox(height: 18),
          Text('Co potřebujete?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _CategorySelector(
            categories: _categories,
            selectedNeed: _selectedNeed,
            onSelected: (need) => setState(() => _selectedNeed = need),
          ),
          const SizedBox(height: 18),
          if (_isDemoModeEnabled) ...[
            const _DemoFindHelpNotice(),
            const SizedBox(height: 12),
          ],
          const _SampleDataNotice(),
          const SizedBox(height: 12),
          _ResultBasisNotice(usesGps: usesGps, selectedArea: _selectedArea),
          const SizedBox(height: 18),
          if (usesGps) ...[
            Text('Nejbližší místa podle GPS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final result in gpsResults) ...[
              _HelpPointCard(
                result: result,
                onShowMap: () => _openHelpPointOnMap(result.point.id),
                onShareMesh: () => _showPlaceholder('Pro sdílení otevřete Reálný Bluetooth mesh v obrazovce Mesh.'),
              ),
              const SizedBox(height: 12),
            ],
          ] else ...[
            Text('Výsledky pro oblast: ${_selectedArea.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (areaResults.isEmpty)
              const _EmptyAreaResults()
            else
              for (final result in areaResults) ...[
                _HelpPointCard(
                  result: result,
                  onShowMap: () => _openHelpPointOnMap(result.point.id),
                  onShareMesh: () => _showPlaceholder('Pro sdílení otevřete Reálný Bluetooth mesh v obrazovce Mesh.'),
                ),
                const SizedBox(height: 12),
              ],
            if (outsideResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Další nejbližší místa mimo vybranou oblast', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final result in outsideResults) ...[
                _HelpPointCard(
                  result: result,
                  isOutsideSelectedArea: true,
                  onShowMap: () => _openHelpPointOnMap(result.point.id),
                  onShareMesh: () => _showPlaceholder('Pro sdílení otevřete Reálný Bluetooth mesh v obrazovce Mesh.'),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _loadState() async {
    await _demoModeService.load();
    final selectedAreaId = await _selectedAreaService.loadSelectedAreaId();
    final location = await _locationService.getLastKnownLocation();

    if (!mounted) {
      return;
    }

    setState(() {
      _isDemoModeEnabled = _demoModeService.isEnabled;
      _selectedArea = selectedAreaId == null && _demoModeService.isEnabled
          ? getPragueAreaById('praha-10')
          : getPragueAreaById(selectedAreaId);
      _lastKnownLocation = location;
      _locationMessage = location == null ? null : 'Používáme poslední známou polohu.';
    });
  }

  void _syncDemoMode() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isDemoModeEnabled = _demoModeService.isEnabled;
      if (_demoModeService.isEnabled && _selectedArea == getDefaultPragueArea()) {
        _selectedArea = getPragueAreaById('praha-10');
      }
    });
  }

  Future<void> _selectArea(PragueArea area) async {
    setState(() => _selectedArea = area);
    await _selectedAreaService.saveSelectedAreaId(area.id);
  }

  Future<void> _updateLocationOnce() async {
    setState(() {
      _isUpdatingLocation = true;
      _locationMessage = null;
    });

    final permission = await _locationService.requestLocationPermission();
    if (permission != LocationPermissionResult.granted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdatingLocation = false;
        _locationMessage = permission.czechError;
      });
      return;
    }

    try {
      final location = await _locationService.getCurrentLocationOnce();
      if (location == null) {
        throw const _LocationUnavailableException();
      }
      await _locationService.saveLastKnownLocation(location);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastKnownLocation = location;
        _isUpdatingLocation = false;
        _locationMessage = 'Používáme poslední známou polohu.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdatingLocation = false;
        _locationMessage = 'GPS není dostupná, vyberte oblast ručně.';
      });
    }
  }

  Future<void> _clearLastKnownLocation() async {
    await _locationService.clearLastKnownLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _lastKnownLocation = null;
      _locationMessage = 'GPS není dostupná, vyberte oblast ručně.';
    });
  }

  List<_HelpPointResult> _gpsResults() {
    final location = _lastKnownLocation;
    if (location == null) {
      return const [];
    }

    return _resultsForPoints(
      getHelpPointsForNeed(_selectedNeed),
      latitude: location.latitude,
      longitude: location.longitude,
      isOutsideSelectedArea: false,
    ).take(_maximumResultCount).toList(growable: false);
  }

  List<_HelpPointResult> _selectedAreaResults() {
    return _resultsForPoints(
      getHelpPointsForAreaAndNeed(_selectedArea.name, _selectedNeed),
      latitude: _selectedArea.latitude,
      longitude: _selectedArea.longitude,
      isOutsideSelectedArea: false,
    ).take(_maximumResultCount).toList(growable: false);
  }

  List<_HelpPointResult> _outsideAreaResults(int selectedAreaResultCount) {
    final remainingCount = _maximumResultCount - selectedAreaResultCount;
    if (remainingCount <= 0) {
      return const [];
    }

    return _resultsForPoints(
      getNearbyHelpPointsOutsideArea(_selectedArea.name, _selectedNeed),
      latitude: _selectedArea.latitude,
      longitude: _selectedArea.longitude,
      isOutsideSelectedArea: true,
    ).take(remainingCount).toList(growable: false);
  }

  List<_HelpPointResult> _resultsForPoints(
    List<HelpPoint> points, {
    required double latitude,
    required double longitude,
    required bool isOutsideSelectedArea,
  }) {
    final results = points.map((point) {
      final distanceKm = calculateDistanceKm(latitude, longitude, point.latitude, point.longitude);
      return _HelpPointResult(
        point: point,
        distanceKm: distanceKm,
        walkingMinutes: estimateWalkingMinutes(distanceKm),
        isOutsideSelectedArea: isOutsideSelectedArea,
      );
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return results;
  }

  void _openHelpPointOnMap(String helpPointId) {
    final callback = widget.onShowHelpPointOnMap;
    if (callback != null) {
      callback(helpPointId);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          selectedHelpPointId: helpPointId,
          focusNonce: DateTime.now().microsecondsSinceEpoch,
        ),
      ),
    );
  }
  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LocationUnavailableException implements Exception {
  const _LocationUnavailableException();
}
class _LocationSourceCard extends StatelessWidget {
  const _LocationSourceCard({
    required this.selectedArea,
    required this.lastKnownLocation,
    required this.isUpdatingLocation,
    required this.locationMessage,
    required this.onAreaChanged,
    required this.onUpdateLocation,
    required this.onClearLocation,
  });

  final PragueArea selectedArea;
  final AppLocation? lastKnownLocation;
  final bool isUpdatingLocation;
  final String? locationMessage;
  final ValueChanged<PragueArea> onAreaChanged;
  final VoidCallback onUpdateLocation;
  final VoidCallback onClearLocation;

  @override
  Widget build(BuildContext context) {
    final usesGps = lastKnownLocation != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zdroj polohy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(usesGps ? 'Poslední známá GPS poloha' : 'Ruční oblast'),
            const SizedBox(height: 6),
            Text(locationMessage ?? 'GPS není dostupná, vyberte oblast ručně.'),
            if (usesGps) ...[
              const SizedBox(height: 6),
              Text('Naposledy aktualizováno: ${_updatedAtText(lastKnownLocation!.updatedAt)}'),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<PragueArea>(
              key: ValueKey(selectedArea.id),
              initialValue: selectedArea,
              decoration: const InputDecoration(labelText: 'Vybrat oblast'),
              items: pragueAreas.map((area) => DropdownMenuItem(value: area, child: Text(area.name))).toList(),
              onChanged: (area) {
                if (area != null) {
                  onAreaChanged(area);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isUpdatingLocation ? null : onUpdateLocation,
                    icon: isUpdatingLocation
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_outlined),
                    label: const Text('Aktualizovat polohu'),
                  ),
                ),
                if (usesGps) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Použít ruční oblast',
                    onPressed: onClearLocation,
                    icon: const Icon(Icons.location_off_outlined),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _updatedAtText(DateTime updatedAt) {
    final difference = DateTime.now().difference(updatedAt);
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

class _HelpCategory {
  const _HelpCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.categories, required this.selectedNeed, required this.onSelected});

  final List<_HelpCategory> categories;
  final String selectedNeed;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          FilterChip(
            selected: selectedNeed == category.label,
            avatar: Icon(category.icon, size: 18),
            label: Text(category.label),
            onSelected: (_) => onSelected(category.label),
          ),
      ],
    );
  }
}

class _DemoFindHelpNotice extends StatelessWidget {
  const _DemoFindHelpNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2230),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Demo režim: používáme ukázkovou oblast Praha 10, pokud není ručně vybraná jiná oblast.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _SampleDataNotice extends StatelessWidget {
  const _SampleDataNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF121821),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Některé body jsou označené jako Ukázková data. Nejde o oficiální živá krizová data.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ResultBasisNotice extends StatelessWidget {
  const _ResultBasisNotice({required this.usesGps, required this.selectedArea});

  final bool usesGps;
  final PragueArea selectedArea;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2230),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          usesGps
              ? 'Výsledky jsou seřazené podle: Poslední známá GPS poloha.'
              : 'Výsledky jsou seřazené podle: Ruční oblast ${selectedArea.name}. Nejprve zobrazujeme místa ve vybrané oblasti. Pokud jich není dost, nabídneme další nejbližší možnosti v okolí.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyAreaResults extends StatelessWidget {
  const _EmptyAreaResults();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('Ve vybrané oblasti nejsou pro tuto kategorii žádná uložená místa.', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _HelpPointResult {
  const _HelpPointResult({
    required this.point,
    required this.distanceKm,
    required this.walkingMinutes,
    required this.isOutsideSelectedArea,
  });

  final HelpPoint point;
  final double distanceKm;
  final int walkingMinutes;
  final bool isOutsideSelectedArea;
}
class _HelpPointCard extends StatelessWidget {
  const _HelpPointCard({
    required this.result,
    required this.onShowMap,
    required this.onShareMesh,
    this.isOutsideSelectedArea = false,
  });

  final _HelpPointResult result;
  final VoidCallback onShowMap;
  final VoidCallback onShareMesh;
  final bool isOutsideSelectedArea;

  @override
  Widget build(BuildContext context) {
    final point = result.point;
    final showOutsideBadge = isOutsideSelectedArea || result.isOutsideSelectedArea;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon(point.type), color: const Color(0xFF00D1FF), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('${point.type.czechLabel} · ${point.areaName}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showOutsideBadge) const _WarningBadge(text: 'Mimo vybranou oblast'),
                _InfoBadge(text: '${result.distanceKm.toStringAsFixed(1)} km'),
                _InfoBadge(text: '${result.walkingMinutes} min pěšky'),
                _InfoBadge(text: point.verifiedStatus.czechLabel),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(icon: Icons.place_outlined, text: point.address),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.description_outlined, text: point.description),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.update_outlined, text: _lastUpdatedText(point.lastUpdatedMinutesAgo)),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.schedule_outlined, text: point.openingNote),
            const SizedBox(height: 12),
            Text('Dostupné služby', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: point.availableServices.map((service) => _ServiceChip(text: service)).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShowMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Zobrazit na mapě'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareMesh,
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('Sdílet žádost přes mesh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(HelpPointType type) {
    return switch (type) {
      HelpPointType.hospital => Icons.local_hospital_outlined,
      HelpPointType.pharmacy => Icons.medication_outlined,
      HelpPointType.police => Icons.local_police_outlined,
      HelpPointType.fireStation => Icons.fire_truck_outlined,
      HelpPointType.crisisCenter => Icons.support_agent_outlined,
      HelpPointType.waterPoint => Icons.water_drop_outlined,
      HelpPointType.chargingPoint => Icons.battery_charging_full_outlined,
      HelpPointType.shelter => Icons.night_shelter_outlined,
      HelpPointType.cityOffice => Icons.account_balance_outlined,
    };
  }

  String _lastUpdatedText(int minutesAgo) {
    if (minutesAgo < 60) {
      return 'Aktualizováno před $minutesAgo min';
    }
    final hours = minutesAgo ~/ 60;
    if (hours < 48) {
      return 'Aktualizováno před $hours h';
    }
    final days = hours ~/ 24;
    return 'Aktualizováno před $days dny';
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFF1A2230), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFFF1F1F), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF263445)), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00D1FF)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
