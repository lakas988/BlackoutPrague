import 'dart:math' as math;

import '../models/help_point.dart';

const pragueHelpPoints = <HelpPoint>[
  HelpPoint(
    id: 'fn-motol',
    name: 'Fakultní nemocnice v Motole',
    type: HelpPointType.hospital,
    latitude: 50.0755,
    longitude: 14.3418,
    address: 'V Úvalu 84, Praha 5',
    areaName: 'Praha 5',
    description: 'Velká veřejně známá nemocnice s urgentní péčí.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['urgentní příjem', 'dětská péče', 'léky', 'zdravotní informace'],
    openingNote: 'Ve skutečné krizi ověřte provoz podle pokynů IZS.',
  ),
  HelpPoint(
    id: 'vfn',
    name: 'Všeobecná fakultní nemocnice v Praze',
    type: HelpPointType.hospital,
    latitude: 50.0750,
    longitude: 14.4214,
    address: 'U Nemocnice 499/2, Praha 2',
    areaName: 'Praha 2',
    description: 'Veřejně známá nemocnice v centru Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['urgentní péče', 'zdravotní informace', 'lékařská pomoc'],
    openingNote: 'Provoz v blackoutu se může měnit podle krizového řízení.',
  ),
  HelpPoint(
    id: 'fn-kralovske-vinohrady',
    name: 'FN Královské Vinohrady',
    type: HelpPointType.hospital,
    latitude: 50.0753,
    longitude: 14.4740,
    address: 'Šrobárova 1150/50, Praha 10',
    areaName: 'Praha 10',
    description: 'Veřejně známá fakultní nemocnice.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['urgentní péče', 'popáleninová péče', 'zdravotní pomoc'],
    openingNote: 'V krizi sledujte místní pokyny a značení v areálu.',
  ),
  HelpPoint(
    id: 'thomayerova-nemocnice',
    name: 'Thomayerova nemocnice',
    type: HelpPointType.hospital,
    latitude: 50.0304,
    longitude: 14.4567,
    address: 'Vídeňská 800, Praha 4',
    areaName: 'Praha 4',
    description: 'Veřejně známá nemocnice v Praze 4.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['zdravotní pomoc', 'urgentní péče', 'lékárenské informace'],
    openingNote: 'Dostupnost oddělení se v krizi může lišit.',
  ),
  HelpPoint(
    id: 'uvn-stresovice',
    name: 'Ústřední vojenská nemocnice',
    type: HelpPointType.hospital,
    latitude: 50.0910,
    longitude: 14.3594,
    address: 'U Vojenské nemocnice 1200, Praha 6',
    areaName: 'Praha 6',
    description: 'Veřejně známá nemocnice ve Střešovicích.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['zdravotní pomoc', 'urgentní péče', 'léky'],
    openingNote: 'Vždy respektujte pokyny personálu a IZS.',
  ),
  HelpPoint(
    id: 'nemocnice-na-bulovce',
    name: 'Nemocnice Na Bulovce',
    type: HelpPointType.hospital,
    latitude: 50.1155,
    longitude: 14.4648,
    address: 'Budínova 67/2, Praha 8',
    areaName: 'Praha 8',
    description: 'Veřejně známá nemocnice v severní části Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['zdravotní pomoc', 'infekční péče', 'urgentní péče'],
    openingNote: 'Krizový provoz ověřte na místě nebo přes složky IZS.',
  ),
  HelpPoint(
    id: 'policie-bartolomejska',
    name: 'Policie ČR - Bartolomějská',
    type: HelpPointType.police,
    latitude: 50.0830,
    longitude: 14.4171,
    address: 'Bartolomějská 7, Praha 1',
    areaName: 'Praha 1',
    description: 'Veřejně známé policejní pracoviště v centru města.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['bezpečnost', 'nahlášení nebezpečí', 'základní orientace'],
    openingNote: 'V ohrožení volejte tísňovou linku, pokud je dostupná.',
  ),
  HelpPoint(
    id: 'policie-kongresova',
    name: 'Policie ČR - Kongresová',
    type: HelpPointType.police,
    latitude: 50.0623,
    longitude: 14.4300,
    address: 'Kongresová 1666/2, Praha 4',
    areaName: 'Praha 4',
    description: 'Veřejně známé policejní pracoviště.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['bezpečnost', 'nahlášení nebezpečí', 'pomoc v ohrožení'],
    openingNote: 'Při bezprostředním nebezpečí použijte tísňové volání, pokud funguje.',
  ),
  HelpPoint(
    id: 'mestska-policie-korunni',
    name: 'Městská policie Praha - Korunní',
    type: HelpPointType.police,
    latitude: 50.0759,
    longitude: 14.4527,
    address: 'Korunní 98, Praha 10',
    areaName: 'Praha 10',
    description: 'Veřejně známé pracoviště městské policie.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['městská bezpečnost', 'orientace', 'pomoc v terénu'],
    openingNote: 'Dostupnost hlídek závisí na aktuální krizové situaci.',
  ),
  HelpPoint(
    id: 'hasici-sokolovska',
    name: 'Hasičská stanice Sokolská',
    type: HelpPointType.fireStation,
    latitude: 50.0748,
    longitude: 14.4299,
    address: 'Sokolská, Praha 2',
    areaName: 'Praha 2',
    description: 'Veřejně známá hasičská stanice v širším centru.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['požár', 'technická pomoc', 'záchrana osob'],
    openingNote: 'Stanice nemusí sloužit jako veřejné výdejní místo.',
  ),  HelpPoint(
    id: 'hasici-holesovice',
    name: 'Hasičská stanice Holešovice',
    type: HelpPointType.fireStation,
    latitude: 50.1055,
    longitude: 14.4434,
    address: 'Argentinská, Praha 7',
    areaName: 'Praha 7',
    description: 'Veřejně známá hasičská stanice v Holešovicích.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['požár', 'technická pomoc', 'záchrana osob'],
    openingNote: 'V krizi respektujte uzávěry a pokyny hasičů.',
  ),
  HelpPoint(
    id: 'hasici-strasnice',
    name: 'Hasičská stanice Strašnice',
    type: HelpPointType.fireStation,
    latitude: 50.0746,
    longitude: 14.4924,
    address: 'Průběžná, Praha 10',
    areaName: 'Praha 10',
    description: 'Veřejně známá hasičská stanice ve východní části Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['požár', 'technická pomoc', 'záchrana osob'],
    openingNote: 'Stanice není automaticky veřejné kontaktní centrum.',
  ),
  HelpPoint(
    id: 'urad-praha-1',
    name: 'Úřad městské části Praha 1',
    type: HelpPointType.cityOffice,
    latitude: 50.0867,
    longitude: 14.4193,
    address: 'Vodičkova 18, Praha 1',
    areaName: 'Praha 1',
    description: 'Veřejně známý úřad městské části.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['informace městské části', 'krizové pokyny', 'orientace'],
    openingNote: 'Krizový provoz může být přesunut nebo omezen.',
  ),
  HelpPoint(
    id: 'urad-praha-2',
    name: 'Úřad městské části Praha 2',
    type: HelpPointType.cityOffice,
    latitude: 50.0755,
    longitude: 14.4378,
    address: 'náměstí Míru 20, Praha 2',
    areaName: 'Praha 2',
    description: 'Veřejně známý úřad městské části.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['informace městské části', 'krizové pokyny', 'orientace'],
    openingNote: 'Sledujte místní značení a hlášení krizového štábu.',
  ),
  HelpPoint(
    id: 'urad-praha-3',
    name: 'Úřad městské části Praha 3',
    type: HelpPointType.cityOffice,
    latitude: 50.0832,
    longitude: 14.4557,
    address: 'Havlíčkovo náměstí 9, Praha 3',
    areaName: 'Praha 3',
    description: 'Veřejně známý úřad městské části.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['informace městské části', 'krizové pokyny', 'orientace'],
    openingNote: 'Krizový režim může změnit místo poskytování služeb.',
  ),
  HelpPoint(
    id: 'urad-praha-4',
    name: 'Úřad městské části Praha 4',
    type: HelpPointType.cityOffice,
    latitude: 50.0446,
    longitude: 14.4499,
    address: 'Antala Staška 2059/80b, Praha 4',
    areaName: 'Praha 4',
    description: 'Veřejně známý úřad městské části.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['informace městské části', 'krizové pokyny', 'orientace'],
    openingNote: 'Informace berte jako offline orientační podklad.',
  ),
  HelpPoint(
    id: 'urad-praha-6',
    name: 'Úřad městské části Praha 6',
    type: HelpPointType.cityOffice,
    latitude: 50.0985,
    longitude: 14.3956,
    address: 'Čs. armády 23, Praha 6',
    areaName: 'Praha 6',
    description: 'Veřejně známý úřad městské části.',
    verifiedStatus: HelpPointVerifiedStatus.official,
    lastUpdatedMinutesAgo: 43200,
    availableServices: ['informace městské části', 'krizové pokyny', 'orientace'],
    openingNote: 'V krizi ověřte, zda je místo otevřené pro veřejnost.',
  ),
  HelpPoint(
    id: 'lekarna-palackeho',
    name: 'Lékárna Palackého',
    type: HelpPointType.pharmacy,
    latitude: 50.0811,
    longitude: 14.4206,
    address: 'Palackého, Praha 1',
    areaName: 'Praha 1',
    description: 'Ukázkový bod pro orientaci k lékárenské pomoci v centru.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['léky', 'základní zdravotní potřeby', 'informace'],
    openingNote: 'Ukázková data, neověřují aktuální pohotovost ani zásoby.',
  ),
  HelpPoint(
    id: 'lekarna-vinohrady',
    name: 'Lékárna Vinohrady',
    type: HelpPointType.pharmacy,
    latitude: 50.0752,
    longitude: 14.4508,
    address: 'Vinohrady, Praha 2',
    areaName: 'Praha 2',
    description: 'Ukázkový bod pro lékárenskou pomoc.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['léky', 'obvazy', 'základní zdravotní potřeby'],
    openingNote: 'Ukázková data, provoz a dostupnost nejsou ověřené.',
  ),
  HelpPoint(
    id: 'lekarna-dejvice',
    name: 'Lékárna Dejvice',
    type: HelpPointType.pharmacy,
    latitude: 50.1005,
    longitude: 14.3952,
    address: 'Dejvice, Praha 6',
    areaName: 'Praha 6',
    description: 'Ukázkový bod pro léky v severozápadní Praze.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['léky', 'zdravotní potřeby', 'konzultace'],
    openingNote: 'Ukázková data, nejedná se o živý seznam služeb.',
  ),  HelpPoint(
    id: 'water-old-town-square',
    name: 'Ukázkový výdej vody - Staroměstské náměstí',
    type: HelpPointType.waterPoint,
    latitude: 50.0875,
    longitude: 14.4213,
    address: 'Staroměstské náměstí, Praha 1',
    areaName: 'Praha 1',
    description: 'Ukázková data pro budoucí krizový výdej vody.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['pitná voda', 'orientace', 'čekací zóna'],
    openingNote: 'Ukázková data, nejedná se o oficiální živý výdej vody.',
  ),
  HelpPoint(
    id: 'water-andel',
    name: 'Ukázkový výdej vody - Anděl',
    type: HelpPointType.waterPoint,
    latitude: 50.0713,
    longitude: 14.4031,
    address: 'Anděl, Praha 5',
    areaName: 'Praha 5',
    description: 'Ukázková data pro vodní bod v hustě obydlené oblasti.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['pitná voda', 'nádoby na vodu', 'základní informace'],
    openingNote: 'Ukázková data, aktuální provoz musí potvrdit město.',
  ),
  HelpPoint(
    id: 'water-dejvicka',
    name: 'Ukázkový výdej vody - Dejvická',
    type: HelpPointType.waterPoint,
    latitude: 50.1009,
    longitude: 14.3959,
    address: 'Vítězné náměstí, Praha 6',
    areaName: 'Praha 6',
    description: 'Ukázková data pro budoucí krizový výdej vody.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['pitná voda', 'orientace', 'informace městské části'],
    openingNote: 'Ukázková data, nejde o živý krizový údaj.',
  ),
  HelpPoint(
    id: 'water-pankrac',
    name: 'Ukázkový výdej vody - Pankrác',
    type: HelpPointType.waterPoint,
    latitude: 50.0514,
    longitude: 14.4390,
    address: 'Pankrác, Praha 4',
    areaName: 'Praha 4',
    description: 'Ukázková data pro výdej vody v jižní části centra.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['pitná voda', 'základní pomoc', 'orientace'],
    openingNote: 'Ukázková data, výdej musí být potvrzen krizovým štábem.',
  ),
  HelpPoint(
    id: 'charging-main-station',
    name: 'Ukázkové nabíjení - Hlavní nádraží',
    type: HelpPointType.chargingPoint,
    latitude: 50.0830,
    longitude: 14.4353,
    address: 'Wilsonova, Praha 1',
    areaName: 'Praha 1',
    description: 'Ukázková data pro budoucí místo nabíjení telefonu.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['nabíjení telefonu', 'krátký odpočinek', 'orientace'],
    openingNote: 'Ukázková data, dostupnost elektřiny není živě ověřená.',
  ),
  HelpPoint(
    id: 'charging-florenc',
    name: 'Ukázkové nabíjení - Florenc',
    type: HelpPointType.chargingPoint,
    latitude: 50.0904,
    longitude: 14.4392,
    address: 'Florenc, Praha 8',
    areaName: 'Praha 8',
    description: 'Ukázková data pro nabíjecí bod u dopravního uzlu.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['nabíjení telefonu', 'informace', 'čekací zóna'],
    openingNote: 'Ukázková data, nejedná se o potvrzené krizové místo.',
  ),
  HelpPoint(
    id: 'charging-chodov',
    name: 'Ukázkové nabíjení - Chodov',
    type: HelpPointType.chargingPoint,
    latitude: 50.0317,
    longitude: 14.4906,
    address: 'Chodov, Praha 11',
    areaName: 'Praha 11',
    description: 'Ukázková data pro nabíjení ve východní části města.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['nabíjení telefonu', 'základní informace'],
    openingNote: 'Ukázková data, dostupnost není oficiálně potvrzená.',
  ),
  HelpPoint(
    id: 'shelter-vystaviste',
    name: 'Ukázkové přístřeší - Výstaviště',
    type: HelpPointType.shelter,
    latitude: 50.1061,
    longitude: 14.4305,
    address: 'Výstaviště, Praha 7',
    areaName: 'Praha 7',
    description: 'Ukázková data pro dočasné přístřeší.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['přístřeší', 'teplo', 'základní informace'],
    openingNote: 'Ukázková data, kapacita a provoz nejsou živě ověřené.',
  ),
  HelpPoint(
    id: 'shelter-karlovo-namesti',
    name: 'Ukázkové přístřeší - Karlovo náměstí',
    type: HelpPointType.shelter,
    latitude: 50.0756,
    longitude: 14.4180,
    address: 'Karlovo náměstí, Praha 2',
    areaName: 'Praha 2',
    description: 'Ukázková data pro dočasné bezpečné místo.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['přístřeší', 'odpočinek', 'orientace'],
    openingNote: 'Ukázková data, nejedná se o potvrzený evakuační bod.',
  ),
  HelpPoint(
    id: 'shelter-opatov',
    name: 'Ukázkové přístřeší - Opatov',
    type: HelpPointType.shelter,
    latitude: 50.0270,
    longitude: 14.5085,
    address: 'Opatov, Praha 11',
    areaName: 'Praha 11',
    description: 'Ukázková data pro přístřeší na jihovýchodě Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['přístřeší', 'teplo', 'základní pomoc'],
    openingNote: 'Ukázková data, provoz musí potvrdit krizový štáb.',
  ),  HelpPoint(
    id: 'crisis-center-marianske',
    name: 'Ukázkové krizové centrum - Mariánské náměstí',
    type: HelpPointType.crisisCenter,
    latitude: 50.0870,
    longitude: 14.4178,
    address: 'Mariánské náměstí, Praha 1',
    areaName: 'Praha 1',
    description: 'Ukázková data pro kontaktní krizové centrum.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['krizové informace', 'orientace', 'žádost o pomoc'],
    openingNote: 'Ukázková data, oficiální centrum musí potvrdit město.',
  ),
  HelpPoint(
    id: 'crisis-center-palmovka',
    name: 'Ukázkové krizové centrum - Palmovka',
    type: HelpPointType.crisisCenter,
    latitude: 50.1042,
    longitude: 14.4757,
    address: 'Palmovka, Praha 8',
    areaName: 'Praha 8',
    description: 'Ukázková data pro krizové informace v severovýchodní Praze.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['krizové informace', 'koordinace pomoci', 'orientace'],
    openingNote: 'Ukázková data, nejde o živý krizový provoz.',
  ),
  HelpPoint(
    id: 'crisis-center-smichov',
    name: 'Ukázkové krizové centrum - Smíchov',
    type: HelpPointType.crisisCenter,
    latitude: 50.0711,
    longitude: 14.4037,
    address: 'Smíchov, Praha 5',
    areaName: 'Praha 5',
    description: 'Ukázková data pro lokální kontaktní místo.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['krizové informace', 'žádost o pomoc', 'orientace'],
    openingNote: 'Ukázková data, potvrzení musí přijít od města nebo IZS.',
  ),
  HelpPoint(
    id: 'water-zlicin',
    name: 'Ukázkový výdej vody - Zličín',
    type: HelpPointType.waterPoint,
    latitude: 50.0538,
    longitude: 14.2902,
    address: 'Zličín, Praha 17',
    areaName: 'Praha 17',
    description: 'Ukázková data pro výdej vody na západě Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['pitná voda', 'základní informace'],
    openingNote: 'Ukázková data, neoficiální živý krizový bod.',
  ),
  HelpPoint(
    id: 'charging-cerny-most',
    name: 'Ukázkové nabíjení - Černý Most',
    type: HelpPointType.chargingPoint,
    latitude: 50.1097,
    longitude: 14.5774,
    address: 'Černý Most, Praha 14',
    areaName: 'Praha 14',
    description: 'Ukázková data pro nabíjecí bod na východě Prahy.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['nabíjení telefonu', 'orientace'],
    openingNote: 'Ukázková data, dostupnost elektřiny není ověřená.',
  ),
  HelpPoint(
    id: 'shelter-ladvi',
    name: 'Ukázkové přístřeší - Ládví',
    type: HelpPointType.shelter,
    latitude: 50.1266,
    longitude: 14.4696,
    address: 'Ládví, Praha 8',
    areaName: 'Praha 8',
    description: 'Ukázková data pro přístřeší v severní Praze.',
    verifiedStatus: HelpPointVerifiedStatus.sample,
    lastUpdatedMinutesAgo: 10080,
    availableServices: ['přístřeší', 'teplo', 'orientace'],
    openingNote: 'Ukázková data, kapacita není potvrzená.',
  ),
];

List<HelpPoint> getAllHelpPoints() {
  return List.unmodifiable(pragueHelpPoints);
}

List<HelpPoint> getHelpPointsByType(HelpPointType type) {
  return pragueHelpPoints.where((point) => point.type == type).toList(growable: false);
}


List<HelpPoint> getHelpPointsForArea(String areaName) {
  return pragueHelpPoints.where((point) => point.areaName == areaName).toList(growable: false);
}

List<HelpPoint> getHelpPointsForAreaAndNeed(String areaName, String need) {
  return getHelpPointsForNeed(need).where((point) => point.areaName == areaName).toList(growable: false);
}

List<HelpPoint> getNearbyHelpPointsOutsideArea(String areaName, String need) {
  return getHelpPointsForNeed(need).where((point) => point.areaName != areaName).toList(growable: false);
}
List<HelpPoint> getHelpPointsForNeed(String need) {
  final normalizedNeed = need.toLowerCase();

  if (normalizedNeed.contains('zdrav') || normalizedNeed.contains('nemoc')) {
    return _pointsForTypes({HelpPointType.hospital, HelpPointType.pharmacy});
  }
  if (normalizedNeed.contains('polic') || normalizedNeed.contains('bezpe')) {
    return _pointsForTypes({HelpPointType.police});
  }
  if (normalizedNeed.contains('hasi') || normalizedNeed.contains('pož')) {
    return _pointsForTypes({HelpPointType.fireStation});
  }
  if (normalizedNeed.contains('vod')) {
    return _pointsForTypes({HelpPointType.waterPoint});
  }
  if (normalizedNeed.contains('nab') || normalizedNeed.contains('telefon')) {
    return _pointsForTypes({HelpPointType.chargingPoint});
  }
  if (normalizedNeed.contains('příst') || normalizedNeed.contains('teplo')) {
    return _pointsForTypes({HelpPointType.shelter});
  }
  if (normalizedNeed.contains('kriz')) {
    return _pointsForTypes({HelpPointType.crisisCenter, HelpPointType.cityOffice});
  }
  if (normalizedNeed.contains('lék')) {
    return _pointsForTypes({HelpPointType.pharmacy, HelpPointType.hospital});
  }

  return getAllHelpPoints();
}

List<HelpPoint> _pointsForTypes(Set<HelpPointType> types) {
  return pragueHelpPoints.where((point) => types.contains(point.type)).toList(growable: false);
}

double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);
  final startLat = _degreesToRadians(lat1);
  final endLat = _degreesToRadians(lat2);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(startLat) * math.cos(endLat) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

int estimateWalkingMinutes(double distanceKm) {
  const walkingSpeedKmPerHour = 4.5;
  return math.max(1, (distanceKm / walkingSpeedKmPerHour * 60).round());
}

double _degreesToRadians(double degrees) {
  return degrees * math.pi / 180;
}