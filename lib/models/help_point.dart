enum HelpPointType {
  hospital,
  pharmacy,
  police,
  fireStation,
  crisisCenter,
  waterPoint,
  chargingPoint,
  shelter,
  cityOffice,
}

enum HelpPointVerifiedStatus {
  official,
  communityVerified,
  unverified,
  sample,
}

extension HelpPointTypeLabel on HelpPointType {
  String get czechLabel => switch (this) {
    HelpPointType.hospital => 'Nemocnice',
    HelpPointType.pharmacy => 'Lékárna',
    HelpPointType.police => 'Policie',
    HelpPointType.fireStation => 'Hasiči',
    HelpPointType.crisisCenter => 'Krizové centrum',
    HelpPointType.waterPoint => 'Výdej vody',
    HelpPointType.chargingPoint => 'Nabíjení telefonu',
    HelpPointType.shelter => 'Přístřeší',
    HelpPointType.cityOffice => 'Úřad městské části',
  };
}

extension HelpPointVerifiedStatusLabel on HelpPointVerifiedStatus {
  String get czechLabel => switch (this) {
    HelpPointVerifiedStatus.official => 'Oficiální veřejná instituce',
    HelpPointVerifiedStatus.communityVerified => 'Ověřeno komunitou',
    HelpPointVerifiedStatus.unverified => 'Neověřeno',
    HelpPointVerifiedStatus.sample => 'Ukázková data',
  };
}

class HelpPoint {
  const HelpPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.areaName,
    required this.description,
    required this.verifiedStatus,
    required this.lastUpdatedMinutesAgo,
    required this.availableServices,
    required this.openingNote,
  });

  final String id;
  final String name;
  final HelpPointType type;
  final double latitude;
  final double longitude;
  final String address;
  final String areaName;
  final String description;
  final HelpPointVerifiedStatus verifiedStatus;
  final int lastUpdatedMinutesAgo;
  final List<String> availableServices;
  final String openingNote;
}