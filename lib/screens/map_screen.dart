import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/prague_areas.dart';
import '../data/prague_help_points.dart';
import '../models/app_location.dart';
import '../models/help_point.dart';
import '../models/map_mode.dart';
import '../models/prague_area.dart';
import '../services/location_service.dart';
import '../services/map_mode_service.dart';
import '../services/selected_area_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.selectedHelpPointId, this.focusNonce = 0});

  final String? selectedHelpPointId;
  final int focusNonce;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _defaultPragueCenter = LatLng(50.0755, 14.4378);

  final _locationService = LocationService();
  final _selectedAreaService = SelectedAreaService();
  final _mapModeService = MapModeService();
  final _mapController = MapController();

  PragueArea _selectedArea = getDefaultPragueArea();
  AppLocation? _lastKnownLocation;
  HelpPointType? _selectedType;
  MapMode _mapMode = MapMode.onlineTiles;
  bool _isUpdatingLocation = false;
  String? _locationMessage;
  String? _selectedHelpPointId;
  String? _navigationHelpPointId;
  int _handledFocusNonce = -1;
  String? _lastMissingHelpPointId;

  @override
  void initState() {
    super.initState();
    _selectedHelpPointId = widget.selectedHelpPointId;
    _loadInitialState();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNonce != oldWidget.focusNonce || widget.selectedHelpPointId != oldWidget.selectedHelpPointId) {
      _selectedHelpPointId = widget.selectedHelpPointId;
      if (widget.selectedHelpPointId != null && _mapMode == MapMode.offlineMap) {
        _mapMode = MapMode.onlineTiles;
        _mapModeService.saveMode(MapMode.onlineTiles);
      }
      _focusSelectedHelpPointFromWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _mapCenter;
    final visiblePoints = _visibleHelpPoints;
    final selectedPoint = _selectedHelpPoint;
    final navigationPoint = _navigationHelpPoint;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Mapa pomoci', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Poloha se používá jen jednorázově kvůli úspoře baterie.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD6D9DE)),
          ),

          const SizedBox(height: 12),
          _LocationControlCard(
            selectedArea: _selectedArea,
            lastKnownLocation: _lastKnownLocation,
            isUpdatingLocation: _isUpdatingLocation,
            locationMessage: _locationMessage,
            onAreaChanged: _selectArea,
            onUpdateLocation: _updateLocationOnce,
            onClearLocation: _clearLastKnownLocation,
          ),
          const SizedBox(height: 12),
          _MapFilters(selectedType: _selectedType, onSelected: (type) => setState(() => _selectedType = type)),
          const SizedBox(height: 12),
          _MapModeSelector(mode: _mapMode, onChanged: _setMapMode),
          const SizedBox(height: 8),
          _MapModeNotice(mode: _mapMode),
          const SizedBox(height: 10),
          SizedBox(
            height: 430,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _mapMode == MapMode.onlineTiles
                  ? _OnlineHelpMap(
                      key: ValueKey('${center.latitude}-${center.longitude}-${_selectedType?.name ?? 'all'}-${_selectedHelpPointId ?? 'none'}'),
                      controller: _mapController,
                      center: center,
                      selectedPoint: selectedPoint,
                      navigationPoint: navigationPoint,
                      lastKnownLocation: _lastKnownLocation,
                      selectedArea: _selectedArea,
                      points: visiblePoints,
                      typeIcon: _typeIcon,
                      typeColor: _typeColor,
                      onOpenPoint: _selectAndShowHelpPoint,
                    )
                  : const _OfflineMapUnavailable(),
            ),
          ),
          const SizedBox(height: 8),
          if (_mapMode == MapMode.onlineTiles)
            Text('© OpenStreetMap contributors', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFD6D9DE))),
          if (selectedPoint != null) ...[
            const SizedBox(height: 12),
            _SelectedPointCard(
              point: selectedPoint,
              distanceKm: _distanceFromOrigin(selectedPoint),
              walkingMinutes: estimateWalkingMinutes(_distanceFromOrigin(selectedPoint)),
              hasGps: _lastKnownLocation != null,
              isNavigating: selectedPoint.id == _navigationHelpPointId,
              onOpen: () => _showHelpPointSheet(selectedPoint),
              onNavigate: () => _startNavigation(selectedPoint),
            ),
          ],
          const SizedBox(height: 18),
          Text('Body pomoci', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Seznam zůstává dostupný i bez mapových podkladů.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD6D9DE))),
          const SizedBox(height: 10),
          for (final point in visiblePoints.take(8)) ...[
            _FallbackHelpPointCard(
              point: point,
              isSelected: point.id == _selectedHelpPointId,
              distanceKm: _distanceFromOrigin(point),
              onOpen: () => _selectAndShowHelpPoint(point),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  _Coordinate get _distanceOrigin {
    final location = _lastKnownLocation;
    if (location != null) {
      return _Coordinate(location.latitude, location.longitude);
    }
    return _Coordinate(_selectedArea.latitude, _selectedArea.longitude);
  }

  LatLng get _mapCenter {
    final selectedPoint = _selectedHelpPoint;
    if (selectedPoint != null) {
      return LatLng(selectedPoint.latitude, selectedPoint.longitude);
    }
    final location = _lastKnownLocation;
    if (location != null) {
      return LatLng(location.latitude, location.longitude);
    }
    return _defaultPragueCenter;
  }

  HelpPoint? get _selectedHelpPoint => _helpPointById(_selectedHelpPointId);

  HelpPoint? get _navigationHelpPoint => _helpPointById(_navigationHelpPointId);

  HelpPoint? _helpPointById(String? id) {
    if (id == null) {
      return null;
    }
    for (final point in getAllHelpPoints()) {
      if (point.id == id) {
        return point;
      }
    }
    return null;
  }

  List<HelpPoint> get _visibleHelpPoints {
    final points = _selectedType == null ? getAllHelpPoints() : getHelpPointsByType(_selectedType!);
    final sorted = [...points]..sort((a, b) => _distanceFromOrigin(a).compareTo(_distanceFromOrigin(b)));
    final selectedPoint = _selectedHelpPoint;
    if (selectedPoint != null && !sorted.any((point) => point.id == selectedPoint.id)) {
      sorted.insert(0, selectedPoint);
    }
    return sorted;
  }

  Future<void> _loadInitialState() async {
    final selectedAreaId = await _selectedAreaService.loadSelectedAreaId();
    final location = await _locationService.getLastKnownLocation();
    final mode = await _mapModeService.loadMode();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedArea = getPragueAreaById(selectedAreaId);
      _lastKnownLocation = location;
      _mapMode = widget.selectedHelpPointId == null ? mode : MapMode.onlineTiles;
      _locationMessage = location == null ? null : 'Používáme poslední známou polohu.';
    });

    _focusSelectedHelpPointFromWidget();
  }

  Future<void> _setMapMode(MapMode mode) async {
    setState(() => _mapMode = mode);
    await _mapModeService.saveMode(mode);
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
      _navigationHelpPointId = null;
      _locationMessage = 'GPS není dostupná, vyberte oblast ručně.';
    });
  }

  double _distanceFromOrigin(HelpPoint point) {
    final origin = _distanceOrigin;
    return calculateDistanceKm(origin.latitude, origin.longitude, point.latitude, point.longitude);
  }

  void _focusSelectedHelpPointFromWidget({bool force = false}) {
    if (!force && _handledFocusNonce == widget.focusNonce) {
      return;
    }
    _handledFocusNonce = widget.focusNonce;

    final selectedId = widget.selectedHelpPointId;
    if (selectedId == null) {
      return;
    }

    final point = _selectedHelpPoint;
    if (point == null) {
      if (_lastMissingHelpPointId == selectedId) {
        return;
      }
      _lastMissingHelpPointId = selectedId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bod se nepodařilo najít na mapě.')),
        );
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _moveMapToPoint(point);
      _showHelpPointSheet(point);
    });
  }

  void _selectAndShowHelpPoint(HelpPoint point) {
    setState(() {
      _selectedHelpPointId = point.id;
      if (_mapMode == MapMode.offlineMap) {
        _mapMode = MapMode.onlineTiles;
      }
    });
    _moveMapToPoint(point);
    _showHelpPointSheet(point);
  }

  void _moveMapToPoint(HelpPoint point) {
    try {
      _mapController.move(LatLng(point.latitude, point.longitude), 14.8);
    } catch (_) {
      // MapController nemusí být připravený při prvním vykreslení obrazovky.
    }
  }

  void _startNavigation(HelpPoint point) {
    if (_lastKnownLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro navigaci aktualizujte polohu nebo vyberte oblast ručně.')),
      );
      return;
    }
    setState(() {
      _selectedHelpPointId = point.id;
      _navigationHelpPointId = point.id;
      _mapMode = MapMode.onlineTiles;
    });
    _moveMapToPoint(point);
  }

  void _showHelpPointSheet(HelpPoint point) {
    final distanceKm = _distanceFromOrigin(point);
    final walkingMinutes = estimateWalkingMinutes(distanceKm);
    final hasGps = _lastKnownLocation != null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Text(point.name, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${point.type.czechLabel} · ${point.areaName}'),
              const SizedBox(height: 10),
              Text(point.address),
              const SizedBox(height: 10),
              Text('Ověření: ${point.verifiedStatus.czechLabel}'),
              const SizedBox(height: 10),
              Text('Vzdálenost: ${distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(height: 10),
              Text('Odhad chůze: $walkingMinutes min'),
              const SizedBox(height: 10),
              Text('Služby: ${point.availableServices.join(', ')}'),
              const SizedBox(height: 10),
              Text('Otevírací poznámka: ${point.openingNote}'),
              const SizedBox(height: 12),
              if (hasGps)
                const Text('Zjednodušená offline navigace ukazuje přímý směr. Produkční verze by používala offline routing.')
              else
                const Text('Pro navigaci aktualizujte polohu nebo vyberte oblast ručně.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startNavigation(point);
                },
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigovat'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showSheetSnackBar(sheetContext, 'Funkce Najít nejbližší pomoc je dostupná v záložce Pomoc.'),
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Najít nejbližší pomoc'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showSheetSnackBar(sheetContext, 'Pro sdílení otevřete Reálný Bluetooth mesh v obrazovce Mesh.'),
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Sdílet přes mesh'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSheetSnackBar(BuildContext sheetContext, String message) {
    Navigator.of(sheetContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _typeIcon(HelpPointType type) {
    return switch (type) {
      HelpPointType.hospital => Icons.local_hospital,
      HelpPointType.pharmacy => Icons.medication,
      HelpPointType.police => Icons.local_police,
      HelpPointType.fireStation => Icons.fire_truck,
      HelpPointType.crisisCenter => Icons.support_agent,
      HelpPointType.waterPoint => Icons.water_drop,
      HelpPointType.chargingPoint => Icons.battery_charging_full,
      HelpPointType.shelter => Icons.night_shelter,
      HelpPointType.cityOffice => Icons.account_balance,
    };
  }

  Color _typeColor(HelpPointType type) {
    return switch (type) {
      HelpPointType.hospital => const Color(0xFFEF4444),
      HelpPointType.pharmacy => const Color(0xFF22C55E),
      HelpPointType.police => const Color(0xFF38BDF8),
      HelpPointType.fireStation => const Color(0xFFF97316),
      HelpPointType.crisisCenter => const Color(0xFFA78BFA),
      HelpPointType.waterPoint => const Color(0xFF06B6D4),
      HelpPointType.chargingPoint => const Color(0xFFFACC15),
      HelpPointType.shelter => const Color(0xFF94A3B8),
      HelpPointType.cityOffice => const Color(0xFFE5E7EB),
    };
  }
}

class _LocationUnavailableException implements Exception {
  const _LocationUnavailableException();
}

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _OnlineHelpMap extends StatelessWidget {
  const _OnlineHelpMap({
    super.key,
    required this.controller,
    required this.center,
    required this.selectedPoint,
    required this.navigationPoint,
    required this.lastKnownLocation,
    required this.selectedArea,
    required this.points,
    required this.typeIcon,
    required this.typeColor,
    required this.onOpenPoint,
  });

  final MapController controller;
  final LatLng center;
  final HelpPoint? selectedPoint;
  final HelpPoint? navigationPoint;
  final AppLocation? lastKnownLocation;
  final PragueArea selectedArea;
  final List<HelpPoint> points;
  final IconData Function(HelpPointType type) typeIcon;
  final Color Function(HelpPointType type) typeColor;
  final ValueChanged<HelpPoint> onOpenPoint;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: selectedPoint == null ? (lastKnownLocation == null ? 12 : 14) : 14.8,
        minZoom: 10,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'cz.blackout_prague.app',
        ),
        if (lastKnownLocation != null && navigationPoint != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [LatLng(lastKnownLocation!.latitude, lastKnownLocation!.longitude), LatLng(navigationPoint!.latitude, navigationPoint!.longitude)],
                color: const Color(0xFFFFD166),
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final origin = lastKnownLocation == null
        ? LatLng(selectedArea.latitude, selectedArea.longitude)
        : LatLng(lastKnownLocation!.latitude, lastKnownLocation!.longitude);

    final markers = <Marker>[
      Marker(
        point: origin,
        width: 48,
        height: 48,
        child: Icon(
          lastKnownLocation == null ? Icons.location_city : Icons.my_location,
          color: lastKnownLocation == null ? const Color(0xFFFFD166) : const Color(0xFF38BDF8),
          size: 38,
        ),
      ),
    ];

    markers.addAll(points.map((point) {
      final isSelected = point.id == selectedPoint?.id;
      return Marker(
        point: LatLng(point.latitude, point.longitude),
        width: isSelected ? 58 : 44,
        height: isSelected ? 58 : 44,
        child: _MapMarkerButton(
          point: point,
          icon: typeIcon(point.type),
          color: typeColor(point.type),
          isSelected: isSelected,
          onPressed: () => onOpenPoint(point),
        ),
      );
    }));

    return markers;
  }
}

class _OfflineMapUnavailable extends StatelessWidget {
  const _OfflineMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101820),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.offline_bolt_outlined, color: Color(0xFFFFD166), size: 44),
              const SizedBox(height: 12),
              Text('Offline mapa zatím není připravena.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Použijte online mapu. Body pomoci a návody zůstávají dostupné.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapModeSelector extends StatelessWidget {
  const _MapModeSelector({required this.mode, required this.onChanged});

  final MapMode mode;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MapMode>(
      segments: const [
        ButtonSegment(value: MapMode.onlineTiles, icon: Icon(Icons.public_outlined), label: Text('Online')),
        ButtonSegment(value: MapMode.offlineMap, icon: Icon(Icons.offline_bolt_outlined), label: Text('Offline')),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _MapModeNotice extends StatelessWidget {
  const _MapModeNotice({required this.mode});

  final MapMode mode;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: mode == MapMode.offlineMap ? const Color(0xFF3A2E12) : const Color(0xFF101820),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(mode.czechDescription, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _LocationControlCard extends StatelessWidget {
  const _LocationControlCard({
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
    final updatedAt = lastKnownLocation == null ? null : _updatedAtText(lastKnownLocation!.updatedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Poloha', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(locationMessage ?? 'GPS není dostupná, vyberte oblast ručně.'),
            if (updatedAt != null) ...[
              const SizedBox(height: 6),
              Text('Naposledy aktualizováno: $updatedAt'),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<PragueArea>(
              key: ValueKey(selectedArea.id),
              initialValue: selectedArea,
              decoration: const InputDecoration(labelText: 'Vybrat oblast ručně'),
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
                if (lastKnownLocation != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Vymazat GPS polohu',
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

class _MapFilters extends StatelessWidget {
  const _MapFilters({required this.selectedType, required this.onSelected});

  final HelpPointType? selectedType;
  final ValueChanged<HelpPointType?> onSelected;

  static const _filters = <_MapFilter>[
    _MapFilter('Nemocnice', HelpPointType.hospital, Icons.local_hospital_outlined),
    _MapFilter('Policie', HelpPointType.police, Icons.local_police_outlined),
    _MapFilter('Hasiči', HelpPointType.fireStation, Icons.fire_truck_outlined),
    _MapFilter('Voda', HelpPointType.waterPoint, Icons.water_drop_outlined),
    _MapFilter('Nabíjení', HelpPointType.chargingPoint, Icons.battery_charging_full_outlined),
    _MapFilter('Přístřeší', HelpPointType.shelter, Icons.night_shelter_outlined),
    _MapFilter('Krizové centrum', HelpPointType.crisisCenter, Icons.support_agent_outlined),
    _MapFilter('Lékárna', HelpPointType.pharmacy, Icons.medication_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(selected: selectedType == null, label: const Text('Vše'), onSelected: (_) => onSelected(null)),
        for (final filter in _filters)
          FilterChip(
            selected: selectedType == filter.type,
            avatar: Icon(filter.icon, size: 18),
            label: Text(filter.label),
            onSelected: (_) => onSelected(filter.type),
          ),
      ],
    );
  }
}

class _MapFilter {
  const _MapFilter(this.label, this.type, this.icon);

  final String label;
  final HelpPointType type;
  final IconData icon;
}

class _MapMarkerButton extends StatelessWidget {
  const _MapMarkerButton({
    required this.point,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final HelpPoint point;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      tooltip: point.name,
      onPressed: onPressed,
      icon: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFFFFD166) : const Color(0xEE111318),
          border: Border.all(color: isSelected ? Colors.white : color, width: isSelected ? 3 : 2),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: isSelected ? const Color(0xFF111318) : color, size: isSelected ? 28 : 23),
        ),
      ),
    );
  }
}

class _SelectedPointCard extends StatelessWidget {
  const _SelectedPointCard({
    required this.point,
    required this.distanceKm,
    required this.walkingMinutes,
    required this.hasGps,
    required this.isNavigating,
    required this.onOpen,
    required this.onNavigate,
  });

  final HelpPoint point;
  final double distanceKm;
  final int walkingMinutes;
  final bool hasGps;
  final bool isNavigating;
  final VoidCallback onOpen;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A2E12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onOpen,
              leading: const Icon(Icons.place, color: Color(0xFFFFD166)),
              title: Text('Vybraný bod: ${point.name}'),
              subtitle: Text('${point.type.czechLabel} · ${point.areaName} · ${distanceKm.toStringAsFixed(1)} km · $walkingMinutes min pěšky'),
              trailing: const Icon(Icons.expand_less),
            ),
            const SizedBox(height: 8),
            Text(
              hasGps
                  ? 'Zjednodušená offline navigace ukazuje přímý směr. Produkční verze by používala offline routing.'
                  : 'Pro navigaci aktualizujte polohu nebo vyberte oblast ručně.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onNavigate,
              icon: Icon(isNavigating ? Icons.near_me : Icons.navigation_outlined),
              label: const Text('Navigovat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackHelpPointCard extends StatelessWidget {
  const _FallbackHelpPointCard({required this.point, required this.isSelected, required this.distanceKm, required this.onOpen});

  final HelpPoint point;
  final bool isSelected;
  final double distanceKm;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? const Color(0xFF3A2E12) : null,
      child: ListTile(
        onTap: onOpen,
        leading: Icon(isSelected ? Icons.place : Icons.place_outlined, color: const Color(0xFFFFD166)),
        title: Text(point.name),
        subtitle: Text('${point.type.czechLabel} · ${point.areaName} · ${distanceKm.toStringAsFixed(1)} km'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}