enum EmergencyMessageType {
  ok,
  sos,
  medical,
  water,
  medication,
  danger,
  info,
}

enum EmergencyMessagePriority {
  low,
  medium,
  high,
  critical,
}

extension EmergencyMessageTypeLabel on EmergencyMessageType {
  String get storageValue => switch (this) {
    EmergencyMessageType.ok => 'ok',
    EmergencyMessageType.sos => 'sos',
    EmergencyMessageType.medical => 'medical',
    EmergencyMessageType.water => 'water',
    EmergencyMessageType.medication => 'medication',
    EmergencyMessageType.danger => 'danger',
    EmergencyMessageType.info => 'info',
  };

  String get czechLabel => switch (this) {
    EmergencyMessageType.ok => 'Jsem v pořádku',
    EmergencyMessageType.sos => 'SOS',
    EmergencyMessageType.medical => 'Zdravotní pomoc',
    EmergencyMessageType.water => 'Voda',
    EmergencyMessageType.medication => 'Léky',
    EmergencyMessageType.danger => 'Nebezpečí',
    EmergencyMessageType.info => 'Informace',
  };

  static EmergencyMessageType fromStorageValue(String value) {
    return EmergencyMessageType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => EmergencyMessageType.info,
    );
  }
}

extension EmergencyMessagePriorityLabel on EmergencyMessagePriority {
  String get storageValue => switch (this) {
    EmergencyMessagePriority.low => 'low',
    EmergencyMessagePriority.medium => 'medium',
    EmergencyMessagePriority.high => 'high',
    EmergencyMessagePriority.critical => 'critical',
  };

  String get czechLabel => switch (this) {
    EmergencyMessagePriority.low => 'nízká',
    EmergencyMessagePriority.medium => 'střední',
    EmergencyMessagePriority.high => 'vysoká',
    EmergencyMessagePriority.critical => 'kritická',
  };

  static EmergencyMessagePriority fromStorageValue(String value) {
    return EmergencyMessagePriority.values.firstWhere(
      (priority) => priority.storageValue == value,
      orElse: () => EmergencyMessagePriority.medium,
    );
  }
}

class EmergencyMessage {
  const EmergencyMessage({
    required this.id,
    required this.type,
    required this.text,
    required this.createdAt,
    required this.senderAlias,
    required this.approximateArea,
    required this.priority,
    required this.ttlMinutes,
    required this.hopCount,
    required this.verifiedCount,
    required this.isOutgoing,
    required this.isOutdated,
  });

  factory EmergencyMessage.fromJson(Map<String, dynamic> json) {
    return EmergencyMessage(
      id: json['id'] as String? ?? '',
      type: EmergencyMessageTypeLabel.fromStorageValue(json['type'] as String? ?? 'info'),
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      senderAlias: json['senderAlias'] as String? ?? 'Neznámý odesílatel',
      approximateArea: json['approximateArea'] as String? ?? 'Praha',
      priority: EmergencyMessagePriorityLabel.fromStorageValue(json['priority'] as String? ?? 'medium'),
      ttlMinutes: json['ttlMinutes'] as int? ?? 120,
      hopCount: json['hopCount'] as int? ?? 0,
      verifiedCount: json['verifiedCount'] as int? ?? 0,
      isOutgoing: json['isOutgoing'] as bool? ?? false,
      isOutdated: json['isOutdated'] as bool? ?? false,
    );
  }

  final String id;
  final EmergencyMessageType type;
  final String text;
  final DateTime createdAt;
  final String senderAlias;
  final String approximateArea;
  final EmergencyMessagePriority priority;
  final int ttlMinutes;
  final int hopCount;
  final int verifiedCount;
  final bool isOutgoing;
  final bool isOutdated;

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes >= ttlMinutes;
  bool get isDemo => id.startsWith('demo_');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.storageValue,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'senderAlias': senderAlias,
      'approximateArea': approximateArea,
      'priority': priority.storageValue,
      'ttlMinutes': ttlMinutes,
      'hopCount': hopCount,
      'verifiedCount': verifiedCount,
      'isOutgoing': isOutgoing,
      'isOutdated': isOutdated,
    };
  }

  EmergencyMessage copyWith({
    int? hopCount,
    int? verifiedCount,
    bool? isOutdated,
  }) {
    return EmergencyMessage(
      id: id,
      type: type,
      text: text,
      createdAt: createdAt,
      senderAlias: senderAlias,
      approximateArea: approximateArea,
      priority: priority,
      ttlMinutes: ttlMinutes,
      hopCount: hopCount ?? this.hopCount,
      verifiedCount: verifiedCount ?? this.verifiedCount,
      isOutgoing: isOutgoing,
      isOutdated: isOutdated ?? this.isOutdated,
    );
  }
}