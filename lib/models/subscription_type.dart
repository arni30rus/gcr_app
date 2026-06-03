// lib/models/subscription_type.dart

class SubscriptionType {
  final int? id;
  String name;
  String startTime;
  String endTime;
  bool isUnlimitedTime;
  String allowedDays;
  bool isVip;
  String updatedAt;
  String? gymId; // ДОБАВЛЕНО ПОЛЕ ID ЗАЛА
  bool isActive;

  SubscriptionType({
    this.id,
    required this.name,
    this.startTime = '00:00',
    this.endTime = '23:59',
    this.isUnlimitedTime = true,
    this.allowedDays = '',
    this.isVip = false,
    required this.updatedAt,
    this.gymId, // ДОБАВЛЕНО В КОНСТРУКТОР
    this.isActive = true,
  });

  factory SubscriptionType.fromMap(Map<String, dynamic> map) {
    return SubscriptionType(
      id: map['id'],
      name: map['name'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      isUnlimitedTime: map['is_unlimited_time'] == 1,
      allowedDays: map['allowed_days'] ?? '',
      isVip: map['is_vip'] == 1,
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      gymId: map['gym_id'], // ДОБАВЛЕНО ПРИ ЧТЕНИИ ИЗ БД
      // SQLite хранит boolean как 0 или 1
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'is_unlimited_time': isUnlimitedTime ? 1 : 0,
      'allowed_days': allowedDays,
      'is_vip': isVip ? 1 : 0,
      'updated_at': updatedAt,
      'gym_id': gymId, // ДОБАВЛЕНО ПРИ ЗАПИСИ В БД
      'is_active': isActive ? 1 : 0,
    };
  }
}