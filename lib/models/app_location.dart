class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory AppLocation.fromJson(Map<String, dynamic> json) {
    return AppLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  servicesDisabled,
}

extension LocationPermissionResultLabel on LocationPermissionResult {
  String get czechError => switch (this) {
    LocationPermissionResult.granted => '',
    LocationPermissionResult.denied => 'Poloha nebyla povolena.',
    LocationPermissionResult.permanentlyDenied => 'Poloha nebyla povolena. Povolte ji v nastavení zařízení.',
    LocationPermissionResult.servicesDisabled => 'GPS není dostupná, vyberte oblast ručně.',
  };
}