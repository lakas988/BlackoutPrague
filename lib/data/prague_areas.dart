import '../models/prague_area.dart';

const pragueAreas = <PragueArea>[
  PragueArea(id: 'praha-1', name: 'Praha 1', latitude: 50.0875, longitude: 14.4213, description: 'Historické centrum města.'),
  PragueArea(id: 'praha-2', name: 'Praha 2', latitude: 50.0755, longitude: 14.4378, description: 'Vinohrady, Nové Město a okolí.'),
  PragueArea(id: 'praha-3', name: 'Praha 3', latitude: 50.0832, longitude: 14.4557, description: 'Žižkov a okolní čtvrti.'),
  PragueArea(id: 'praha-4', name: 'Praha 4', latitude: 50.0446, longitude: 14.4499, description: 'Nusle, Pankrác, Krč a okolí.'),
  PragueArea(id: 'praha-5', name: 'Praha 5', latitude: 50.0713, longitude: 14.4031, description: 'Smíchov, Košíře a jihozápadní část centra.'),
  PragueArea(id: 'praha-6', name: 'Praha 6', latitude: 50.0985, longitude: 14.3956, description: 'Dejvice, Břevnov, Vokovice a okolí.'),
  PragueArea(id: 'praha-7', name: 'Praha 7', latitude: 50.1029, longitude: 14.4337, description: 'Holešovice, Letná a Bubeneč.'),
  PragueArea(id: 'praha-8', name: 'Praha 8', latitude: 50.1042, longitude: 14.4757, description: 'Karlín, Libeň, Kobylisy a okolí.'),
  PragueArea(id: 'praha-9', name: 'Praha 9', latitude: 50.1104, longitude: 14.5006, description: 'Vysočany, Prosek a okolí.'),
  PragueArea(id: 'praha-10', name: 'Praha 10', latitude: 50.0746, longitude: 14.4924, description: 'Vršovice, Strašnice, Malešice a okolí.'),
  PragueArea(id: 'praha-11', name: 'Praha 11', latitude: 50.0317, longitude: 14.4906, description: 'Chodov, Háje a Jižní Město.'),
  PragueArea(id: 'praha-12', name: 'Praha 12', latitude: 50.0052, longitude: 14.4207, description: 'Modřany, Komořany a okolí.'),
  PragueArea(id: 'praha-13', name: 'Praha 13', latitude: 50.0479, longitude: 14.3429, description: 'Stodůlky, Lužiny a Nové Butovice.'),
  PragueArea(id: 'praha-14', name: 'Praha 14', latitude: 50.1097, longitude: 14.5774, description: 'Černý Most, Hloubětín a Kyje.'),
  PragueArea(id: 'praha-15', name: 'Praha 15', latitude: 50.0549, longitude: 14.5571, description: 'Hostivař a Horní Měcholupy.'),
  PragueArea(id: 'praha-16', name: 'Praha 16', latitude: 49.9811, longitude: 14.3618, description: 'Radotín a okolí.'),
  PragueArea(id: 'praha-17', name: 'Praha 17', latitude: 50.0671, longitude: 14.3119, description: 'Řepy a okolí.'),
  PragueArea(id: 'praha-18', name: 'Praha 18', latitude: 50.1364, longitude: 14.5169, description: 'Letňany a okolí.'),
  PragueArea(id: 'praha-19', name: 'Praha 19', latitude: 50.1342, longitude: 14.5518, description: 'Kbely a okolí.'),
  PragueArea(id: 'praha-20', name: 'Praha 20', latitude: 50.1121, longitude: 14.6117, description: 'Horní Počernice.'),
  PragueArea(id: 'praha-21', name: 'Praha 21', latitude: 50.0753, longitude: 14.6593, description: 'Újezd nad Lesy a okolí.'),
  PragueArea(id: 'praha-22', name: 'Praha 22', latitude: 50.0319, longitude: 14.5997, description: 'Uhříněves a okolí.'),
];

PragueArea getDefaultPragueArea() => pragueAreas.first;

PragueArea getPragueAreaById(String? id) {
  return pragueAreas.firstWhere(
    (area) => area.id == id,
    orElse: getDefaultPragueArea,
  );
}