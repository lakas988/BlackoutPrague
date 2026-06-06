import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../data/prague_areas.dart';
import '../data/prague_help_points.dart';
import '../models/app_location.dart';
import '../models/help_point.dart';
import '../models/map_mode.dart';
import '../models/prague_area.dart';
import '../services/location_service.dart';
import '../services/map_file_service.dart';
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
  static final _pragueBounds = LatLngBounds.unsafe(
    west: 14.15,
    south: 49.85,
    east: 14.80,
    north: 50.25,
  );
  static const _defaultMapZoom = 13.0;
  static const _minMapZoom = 10.0;
  static const _maxMapZoom = 19.0;

  final _locationService = LocationService();
  final _selectedAreaService = SelectedAreaService();
  final _mapModeService = MapModeService();
  final _mapFileService = MapFileService();
  final _mapController = MapController();

  PragueArea _selectedArea = getDefaultPragueArea();
  AppLocation? _lastKnownLocation;
  HelpPointType? _selectedType;
  MapMode _mapMode = MapMode.offlineMap;
  OfflineMapBundle? _offlineMapBundle;
  bool _isOfflineMapLoading = false;
  String? _offlineMapError;
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
      _focusSelectedHelpPointFromWidget(force: true);
    }
  }

  @override
  void dispose() {
    _offlineMapBundle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _mapCenter;
    final visiblePoints = _visibleHelpPoints;
    final selectedPoint = _selectedHelpPoint;
    final navigationPoint = _navigationHelpPoint;

    if (_mapMode == MapMode.offlineMap && _offlineMapBundle == null && !_isOfflineMapLoading && _offlineMapError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOfflineMapLoaded());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Mapa pomoci', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Poloha se používá jen jednorázově kvůli úspoře baterie.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC7D0DC)),
          ),

          const SizedBox(height: 12),
          _MapFilters(selectedType: _selectedType, onSelected: (type) => setState(() => _selectedType = type)),
          const SizedBox(height: 12),
          _MapModeSelector(mode: _mapMode, onChanged: _setMapMode),
          const SizedBox(height: 8),
          _MapModeNotice(mode: _mapMode, offlineMapError: _offlineMapError),
          const SizedBox(height: 10),
          SizedBox(
            height: 430,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(
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
                        : _offlineMapWidget(
                            center: center,
                            selectedPoint: selectedPoint,
                            navigationPoint: navigationPoint,
                            visiblePoints: visiblePoints,
                          ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _MapOverlayButton(
                      icon: Icons.fullscreen_outlined,
                      label: 'Celá obrazovka',
                      onPressed: _openFullscreenMap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mapMode == MapMode.onlineTiles ? '© OpenStreetMap contributors' : '© OpenMapTiles · © OpenStreetMap contributors',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFC7D0DC)),
          ),
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
          const SizedBox(height: 18),
          Text('Body pomoci', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Seznam zůstává dostupný i bez mapových podkladů.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFC7D0DC))),
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

  Widget _offlineMapWidget({
    required LatLng center,
    required HelpPoint? selectedPoint,
    required HelpPoint? navigationPoint,
    required List<HelpPoint> visiblePoints,
  }) {
    final offlineMap = _offlineMapBundle;
    if (_isOfflineMapLoading) {
      return const _OfflineMapLoading();
    }
    if (_offlineMapError != null || offlineMap == null) {
      return _OfflineMapError(error: _offlineMapError);
    }

    return _OfflineVectorHelpMap(
      key: ValueKey('offline-${center.latitude}-${center.longitude}-${_selectedType?.name ?? 'all'}-${_selectedHelpPointId ?? 'none'}-${offlineMap.fileSizeBytes}'),
      controller: _mapController,
      center: center,
      offlineMap: offlineMap,
      selectedPoint: selectedPoint,
      navigationPoint: navigationPoint,
      lastKnownLocation: _lastKnownLocation,
      selectedArea: _selectedArea,
      points: visiblePoints,
      typeIcon: _typeIcon,
      typeColor: _typeColor,
      onOpenPoint: _selectAndShowHelpPoint,
    );
  }

  Future<void> _ensureOfflineMapLoaded() async {
    if (_offlineMapBundle != null || _isOfflineMapLoading || !mounted) {
      return;
    }

    setState(() {
      _isOfflineMapLoading = true;
      _offlineMapError = null;
    });

    try {
      final bundle = await _mapFileService.loadOfflineMap();
      if (!mounted) {
        bundle.dispose();
        return;
      }
      setState(() {
        _offlineMapBundle = bundle;
        _isOfflineMapLoading = false;
      });
      final selectedPoint = _selectedHelpPoint;
      if (selectedPoint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _moveMapToPoint(selectedPoint));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOfflineMapLoading = false;
        _offlineMapError = error.toString();
      });
    }
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
      _mapMode = mode;
      _locationMessage = location == null ? null : 'Používáme poslední známou polohu.';
    });

    _focusSelectedHelpPointFromWidget();
  }

  Future<void> _setMapMode(MapMode mode) async {
    setState(() => _mapMode = mode);
    await _mapModeService.saveMode(mode);
    if (mode == MapMode.offlineMap) {
      await _ensureOfflineMapLoaded();
    }
  }

  void _openFullscreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenMapPage(
          initialMode: _mapMode,
          offlineMap: _offlineMapBundle,
          offlineMapError: _offlineMapError,
          center: _mapCenter,
          selectedType: _selectedType,
          selectedPoint: _selectedHelpPoint,
          navigationPoint: _navigationHelpPoint,
          lastKnownLocation: _lastKnownLocation,
          selectedArea: _selectedArea,
          points: _visibleHelpPoints,
          typeIcon: _typeIcon,
          typeColor: _typeColor,
          onModeChanged: _setMapMode,
          onPointSelected: (point) {
            if (mounted) {
              setState(() => _selectedHelpPointId = point.id);
            }
          },
        ),
      ),
    );
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
});
    _moveMapToPoint(point);
    _showHelpPointSheet(point);
  }

  void _moveMapToPoint(HelpPoint point) {
    try {
      _mapController.move(LatLng(point.latitude, point.longitude), 15.5);
    } catch (_) {
      // MapController nemusí být připravený při prvním vykreslení obrazovky.
    }
  }

  void _startNavigation(HelpPoint point) {
    if (_lastKnownLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro spojení bodů aktualizujte polohu nebo vyberte oblast ručně.')),
      );
      return;
    }
    setState(() {
      _selectedHelpPointId = point.id;
      _navigationHelpPointId = point.id;
    });
    _moveMapToPoint(point);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zobrazeno propojení mezi vaší polohou a cílem. Nejde o plnohodnotnou navigaci po cestách.')),
    );
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
                const Text('Zobrazeno propojení mezi vaší polohou a cílem. Nejde o plnohodnotnou navigaci po cestách.')
              else
                const Text('Pro spojení bodů aktualizujte polohu nebo vyberte oblast ručně.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startNavigation(point);
                },
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Spojit body na mapě'),
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
      HelpPointType.hospital => const Color(0xFFFF1F1F),
      HelpPointType.pharmacy => const Color(0xFF2ED573),
      HelpPointType.police => const Color(0xFF00D1FF),
      HelpPointType.fireStation => const Color(0xFFFF9F43),
      HelpPointType.crisisCenter => const Color(0xFF5CE7FF),
      HelpPointType.waterPoint => const Color(0xFF00D1FF),
      HelpPointType.chargingPoint => const Color(0xFFFF9F43),
      HelpPointType.shelter => const Color(0xFFC7D0DC),
      HelpPointType.cityOffice => const Color(0xFFC7D0DC),
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

class _FullscreenMapPage extends StatefulWidget {
  const _FullscreenMapPage({
    required this.initialMode,
    required this.offlineMap,
    required this.offlineMapError,
    required this.center,
    required this.selectedType,
    required this.selectedPoint,
    required this.navigationPoint,
    required this.lastKnownLocation,
    required this.selectedArea,
    required this.points,
    required this.typeIcon,
    required this.typeColor,
    required this.onModeChanged,
    required this.onPointSelected,
  });

  final MapMode initialMode;
  final OfflineMapBundle? offlineMap;
  final String? offlineMapError;
  final LatLng center;
  final HelpPointType? selectedType;
  final HelpPoint? selectedPoint;
  final HelpPoint? navigationPoint;
  final AppLocation? lastKnownLocation;
  final PragueArea selectedArea;
  final List<HelpPoint> points;
  final IconData Function(HelpPointType type) typeIcon;
  final Color Function(HelpPointType type) typeColor;
  final ValueChanged<MapMode> onModeChanged;
  final ValueChanged<HelpPoint> onPointSelected;

  @override
  State<_FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<_FullscreenMapPage> {
  final _controller = MapController();

  late MapMode _mode;
  HelpPointType? _selectedType;
  HelpPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedType = widget.selectedType;
    _selectedPoint = widget.selectedPoint;
  }

  List<HelpPoint> get _visiblePoints {
    if (_selectedType == null) {
      return widget.points;
    }
    return widget.points.where((point) => point.type == _selectedType).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedPoint == null
        ? widget.center
        : LatLng(_selectedPoint!.latitude, _selectedPoint!.longitude);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(center)),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MapOverlayButton(
                      icon: Icons.arrow_back,
                      label: 'Zpět',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FullscreenModeSelector(
                        mode: _mode,
                        onChanged: (mode) {
                          setState(() => _mode = mode);
                          widget.onModeChanged(mode);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FullscreenFilters(
                  selectedType: _selectedType,
                  onSelected: (type) => setState(() => _selectedType = type),
                ),
              ],
            ),
          ),
          if (_selectedPoint != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: _FullscreenSelectedPointCard(
                point: _selectedPoint!,
                onOpen: () => _showPointDetail(_selectedPoint!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng center) {
    if (_mode == MapMode.onlineTiles) {
      return _OnlineHelpMap(
        controller: _controller,
        center: center,
        selectedPoint: _selectedPoint,
        navigationPoint: widget.navigationPoint,
        lastKnownLocation: widget.lastKnownLocation,
        selectedArea: widget.selectedArea,
        points: _visiblePoints,
        typeIcon: widget.typeIcon,
        typeColor: widget.typeColor,
        onOpenPoint: _selectPoint,
      );
    }

    final offlineMap = widget.offlineMap;
    if (offlineMap == null) {
      return _OfflineMapError(error: widget.offlineMapError ?? 'Offline mapa zatím není připravena.');
    }

    return _OfflineVectorHelpMap(
      controller: _controller,
      center: center,
      offlineMap: offlineMap,
      selectedPoint: _selectedPoint,
      navigationPoint: widget.navigationPoint,
      lastKnownLocation: widget.lastKnownLocation,
      selectedArea: widget.selectedArea,
      points: _visiblePoints,
      typeIcon: widget.typeIcon,
      typeColor: widget.typeColor,
      onOpenPoint: _selectPoint,
    );
  }

  void _selectPoint(HelpPoint point) {
    setState(() => _selectedPoint = point);
    widget.onPointSelected(point);
    try {
      _controller.move(LatLng(point.latitude, point.longitude), 15.5);
    } catch (_) {
      // MapController nemusí být připravený během přechodu do fullscreen režimu.
    }
    _showPointDetail(point);
  }

  void _showPointDetail(HelpPoint point) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${point.type.czechLabel} · ${point.areaName}'),
                const SizedBox(height: 8),
                Text(point.address),
                const SizedBox(height: 8),
                Text('Ověření: ${point.verifiedStatus.czechLabel}'),
                const SizedBox(height: 8),
                Text('Služby: ${point.availableServices.join(', ')}'),
                const SizedBox(height: 8),
                Text('Otevírací poznámka: ${point.openingNote}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapOverlayButton extends StatelessWidget {
  const _MapOverlayButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xDD121821),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF5CE7FF)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenModeSelector extends StatelessWidget {
  const _FullscreenModeSelector({required this.mode, required this.onChanged});

  final MapMode mode;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SegmentedButton<MapMode>(
        segments: const [
          ButtonSegment(value: MapMode.onlineTiles, label: Text('Online')),
          ButtonSegment(value: MapMode.offlineMap, label: Text('Offline')),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _FullscreenFilters extends StatelessWidget {
  const _FullscreenFilters({required this.selectedType, required this.onSelected});

  final HelpPointType? selectedType;
  final ValueChanged<HelpPointType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD121821),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              FilterChip(
                selected: selectedType == null,
                label: const Text('Vše'),
                onSelected: (_) => onSelected(null),
              ),
              const SizedBox(width: 6),
              for (final filter in _MapFilters.filters) ...[
                FilterChip(
                  selected: selectedType == filter.type,
                  avatar: Icon(filter.icon, size: 18),
                  label: Text(filter.label),
                  onSelected: (_) => onSelected(filter.type),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenSelectedPointCard extends StatelessWidget {
  const _FullscreenSelectedPointCard({required this.point, required this.onOpen});

  final HelpPoint point;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xEE1A2230),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.place, color: Color(0xFF00D1FF)),
        title: Text(point.name),
        subtitle: Text('${point.type.czechLabel} · ${point.areaName}'),
        trailing: const Icon(Icons.expand_less),
      ),
    );
  }
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
        initialZoom: selectedPoint == null
            ? (lastKnownLocation == null ? _MapScreenState._defaultMapZoom : 14)
            : 15.5,
        minZoom: _MapScreenState._minMapZoom,
        maxZoom: _MapScreenState._maxMapZoom,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: _MapScreenState._pragueBounds,
        ),
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
                color: const Color(0xFF00D1FF),
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
          color: lastKnownLocation == null ? const Color(0xFF00D1FF) : const Color(0xFF00D1FF),
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

class _OfflineVectorHelpMap extends StatelessWidget {
  const _OfflineVectorHelpMap({
    super.key,
    required this.controller,
    required this.center,
    required this.offlineMap,
    required this.selectedPoint,
    required this.navigationPoint,
    required this.lastKnownLocation,
    required this.selectedArea,
    required this.points,
    required this.typeIcon,
    required this.typeColor,
    required this.onOpenPoint,
  });

  static final vtr.Theme _theme = vtr.ProvidedThemes.lightTheme().copyWith(
    types: {
      vtr.ThemeLayerType.background,
      vtr.ThemeLayerType.fill,
      vtr.ThemeLayerType.line,
      vtr.ThemeLayerType.fillExtrusion,
    },
  );

  final MapController controller;
  final LatLng center;
  final OfflineMapBundle offlineMap;
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
    final initialZoom = (selectedPoint == null
            ? _MapScreenState._defaultMapZoom
            : 15.5)
        .clamp(_MapScreenState._minMapZoom, _MapScreenState._maxMapZoom)
        .toDouble();

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        minZoom: _MapScreenState._minMapZoom,
        maxZoom: _MapScreenState._maxMapZoom,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: _MapScreenState._pragueBounds,
        ),
      ),
      children: [
        VectorTileLayer(
          tileProviders: TileProviders({'openmaptiles': offlineMap.provider}),
          theme: _theme,
          layerMode: VectorTileLayerMode.raster,
          maximumZoom: _MapScreenState._maxMapZoom,
          maximumTileSubstitutionDifference: 3,
          showTileDebugInfo: false,
        ),
        if (lastKnownLocation != null && navigationPoint != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [LatLng(lastKnownLocation!.latitude, lastKnownLocation!.longitude), LatLng(navigationPoint!.latitude, navigationPoint!.longitude)],
                color: const Color(0xFF00D1FF),
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
          color: lastKnownLocation == null ? const Color(0xFF00D1FF) : const Color(0xFF00D1FF),
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

class _OfflineMapLoading extends StatelessWidget {
  const _OfflineMapLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEFF1F3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Načítám offline mapu Prahy...'),
          ],
        ),
      ),
    );
  }
}

class _OfflineMapError extends StatelessWidget {
  const _OfflineMapError({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF121821),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF00D1FF), size: 44),
              const SizedBox(height: 12),
              Text(
                'Soubor offline mapy existuje, ale nepodařilo se vykreslit vektorové dlaždice.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Zkontrolujte renderer, styl a TMS/XYZ schéma.', textAlign: TextAlign.center),
              if (error != null && error!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFC7D0DC))),
              ],
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
  const _MapModeNotice({required this.mode, required this.offlineMapError});

  final MapMode mode;
  final String? offlineMapError;

  @override
  Widget build(BuildContext context) {
    final text = mode == MapMode.offlineMap && offlineMapError != null
        ? 'Offline mapa se nepodařila vykreslit. Online mapa zůstává dostupná jako záloha.'
        : mode.czechDescription;

    return Card(
      color: mode == MapMode.offlineMap ? const Color(0xFF1A2230) : const Color(0xFF121821),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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

  static const filters = <_MapFilter>[
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
        for (final filter in filters)
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
          color: isSelected ? const Color(0xFF00D1FF) : const Color(0xEE111318),
          border: Border.all(color: isSelected ? Colors.white : color, width: isSelected ? 3 : 2),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: isSelected ? const Color(0xFF121821) : color, size: isSelected ? 28 : 23),
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
      color: const Color(0xFF1A2230),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onOpen,
              leading: const Icon(Icons.place, color: Color(0xFF00D1FF)),
              title: Text('Vybraný bod: ${point.name}'),
              subtitle: Text('${point.type.czechLabel} · ${point.areaName} · ${distanceKm.toStringAsFixed(1)} km · $walkingMinutes min pěšky'),
              trailing: const Icon(Icons.expand_less),
            ),
            const SizedBox(height: 8),
            Text(
              hasGps
                  ? 'Zobrazeno propojení mezi vaší polohou a cílem. Nejde o plnohodnotnou navigaci po cestách.'
                  : 'Pro spojení bodů aktualizujte polohu nebo vyberte oblast ručně.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onNavigate,
              icon: Icon(isNavigating ? Icons.near_me : Icons.navigation_outlined),
              label: const Text('Spojit body na mapě'),
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
      color: isSelected ? const Color(0xFF1A2230) : null,
      child: ListTile(
        onTap: onOpen,
        leading: Icon(isSelected ? Icons.place : Icons.place_outlined, color: const Color(0xFF00D1FF)),
        title: Text(point.name),
        subtitle: Text('${point.type.czechLabel} · ${point.areaName} · ${distanceKm.toStringAsFixed(1)} km'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
