enum MapMode {
  onlineTiles,
  offlineMap,
}

extension MapModeLabel on MapMode {
  String get czechLabel => switch (this) {
    MapMode.onlineTiles => 'Online mapa',
    MapMode.offlineMap => 'Offline mapa',
  };

  String get czechDescription => switch (this) {
    MapMode.onlineTiles => 'Online mapa používá internet.',
    MapMode.offlineMap => 'Offline mapa používá mapový balíček uložený přímo v aplikaci. Funguje i bez internetu.',
  };
}