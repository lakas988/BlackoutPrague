import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';

class OfflineMapBundle {
  const OfflineMapBundle({
    required this.localPath,
    required this.fileSizeBytes,
    required this.mbtiles,
    required this.provider,
    required this.metadata,
    required this.scheme,
  });

  final String localPath;
  final int fileSizeBytes;
  final MbTiles mbtiles;
  final MbTilesVectorTileProvider provider;
  final MbTilesMetadata metadata;
  final String scheme;

  int get minZoom => metadata.minZoom?.truncate() ?? 0;
  int get maxZoom => metadata.maxZoom?.truncate() ?? 14;

  void dispose() {
    mbtiles.dispose();
  }
}

class MapFileService {
  static const _assetPath = 'assets/maps/prague.mbtiles';
  static const _localFileName = 'prague.mbtiles';

  Future<OfflineMapBundle> loadOfflineMap() async {
    final assetBytes = await rootBundle.load(_assetPath);
    debugPrint('MBTiles asset loaded: $_assetPath, bytes: ${assetBytes.lengthInBytes}');
    final mapsDirectory = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}blackout_prague_maps');
    if (!await mapsDirectory.exists()) {
      await mapsDirectory.create(recursive: true);
    }

    final localFile = File('${mapsDirectory.path}${Platform.pathSeparator}$_localFileName');
    final shouldCopy = !await localFile.exists() || await localFile.length() != assetBytes.lengthInBytes;
    if (shouldCopy) {
      final bytes = assetBytes.buffer.asUint8List(assetBytes.offsetInBytes, assetBytes.lengthInBytes);
      await localFile.writeAsBytes(bytes, flush: true);
    }

    final localSize = await localFile.length();
    debugPrint('MBTiles copied local file path: ${localFile.path}');
    debugPrint('MBTiles copied local file size: $localSize');

    if (localSize <= 0) {
      throw const OfflineMapLoadException('Zkopírovaný soubor offline mapy je prázdný.');
    }

    final mbtiles = MbTiles(mbtilesPath: localFile.path);
    final metadata = mbtiles.getMetadata();
    const scheme = 'tms';

    debugPrint(
      'MBTiles metadata: format=${metadata.format}, scheme=$scheme, '
      'minzoom=${metadata.minZoom}, maxzoom=${metadata.maxZoom}, '
      'center=${metadata.defaultCenter}, zoom=${metadata.defaultZoom}, bounds=${metadata.bounds}',
    );

    if (metadata.format.toLowerCase() != 'pbf') {
      mbtiles.dispose();
      throw OfflineMapLoadException('Offline mapa má formát ${metadata.format}, očekává se pbf.');
    }

    final provider = MbTilesVectorTileProvider(
      mbtiles: mbtiles,
      minimumZoom: metadata.minZoom?.truncate() ?? 0,
      maximumZoom: metadata.maxZoom?.truncate() ?? 14,
    );

    debugPrint('Vector MBTiles provider initialized. TMS scheme handled by provider via XYZ to TMS tile_row conversion.');

    return OfflineMapBundle(
      localPath: localFile.path,
      fileSizeBytes: localSize,
      mbtiles: mbtiles,
      provider: provider,
      metadata: metadata,
      scheme: scheme,
    );
  }
}

class OfflineMapLoadException implements Exception {
  const OfflineMapLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
