enum UserRole {
  citizen,
  volunteer,
  medic,
  firefighter,
  police,
  technician,
}

extension UserRoleLabel on UserRole {
  String get storageValue => switch (this) {
    UserRole.citizen => 'citizen',
    UserRole.volunteer => 'volunteer',
    UserRole.medic => 'medic',
    UserRole.firefighter => 'firefighter',
    UserRole.police => 'police',
    UserRole.technician => 'technician',
  };

  String get czechLabel => switch (this) {
    UserRole.citizen => 'Obyvatel',
    UserRole.volunteer => 'Dobrovolník',
    UserRole.medic => 'Zdravotník',
    UserRole.firefighter => 'Hasič',
    UserRole.police => 'Policista',
    UserRole.technician => 'Technik',
  };

  static UserRole fromStorageValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.storageValue == value,
      orElse: () => UserRole.citizen,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.ageGroup,
    required this.role,
    required this.district,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.medicalNotes,
    required this.needsMedication,
    required this.hasChildren,
    required this.hasSeniorAtHome,
    required this.hasPet,
    required this.preferredLanguage,
  });

  factory UserProfile.empty() {
    return const UserProfile(
      displayName: '',
      ageGroup: 'Dospělý',
      role: UserRole.citizen,
      district: 'Praha 1',
      emergencyContactName: '',
      emergencyContactPhone: '',
      medicalNotes: '',
      needsMedication: false,
      hasChildren: false,
      hasSeniorAtHome: false,
      hasPet: false,
      preferredLanguage: 'Čeština',
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String? ?? '',
      ageGroup: json['ageGroup'] as String? ?? 'Dospělý',
      role: UserRoleLabel.fromStorageValue(json['role'] as String? ?? 'citizen'),
      district: json['district'] as String? ?? 'Praha 1',
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      medicalNotes: json['medicalNotes'] as String? ?? '',
      needsMedication: json['needsMedication'] as bool? ?? false,
      hasChildren: json['hasChildren'] as bool? ?? false,
      hasSeniorAtHome: json['hasSeniorAtHome'] as bool? ?? false,
      hasPet: json['hasPet'] as bool? ?? false,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'Čeština',
    );
  }

  final String displayName;
  final String ageGroup;
  final UserRole role;
  final String district;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String medicalNotes;
  final bool needsMedication;
  final bool hasChildren;
  final bool hasSeniorAtHome;
  final bool hasPet;
  final String preferredLanguage;

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'ageGroup': ageGroup,
      'role': role.storageValue,
      'district': district,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'medicalNotes': medicalNotes,
      'needsMedication': needsMedication,
      'hasChildren': hasChildren,
      'hasSeniorAtHome': hasSeniorAtHome,
      'hasPet': hasPet,
      'preferredLanguage': preferredLanguage,
    };
  }
}