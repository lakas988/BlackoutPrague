enum AppPowerMode {
  normal,
  batterySaver,
  ultra,
}

extension AppPowerModeLabel on AppPowerMode {
  String get storageValue => switch (this) {
    AppPowerMode.normal => 'normal',
    AppPowerMode.batterySaver => 'batterySaver',
    AppPowerMode.ultra => 'ultra',
  };

  String get czechLabel => switch (this) {
    AppPowerMode.normal => 'Normální',
    AppPowerMode.batterySaver => 'Úsporný',
    AppPowerMode.ultra => 'Ultra',
  };

  String get description => switch (this) {
    AppPowerMode.normal => 'Plný režim aplikace.',
    AppPowerMode.batterySaver => 'Úsporný režim omezuje zbytečné obnovování a doporučuje používat polohu jen ručně.',
    AppPowerMode.ultra => 'Ultra režim omezuje funkce, aby telefon vydržel déle.',
  };

  static AppPowerMode fromStorageValue(String? value) {
    return AppPowerMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppPowerMode.normal,
    );
  }
}