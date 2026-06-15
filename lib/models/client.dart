// lib/models/client.dart

class Client {
  final String id; // EAN13 штрихкод
  String fullName;
  String phone;
  int subType; // 1-Дневной, 2-Вечерний, 3-Безлимит, 4-Выходного дня
  String startDate; // Формат 'YYYY-MM-DD'
  String endDate;   // Формат 'YYYY-MM-DD'
  String? lastVisit; // Может быть null, если еще не посещал
  String updatedAt;  // Дата последнего изменения (для синхронизации)
  String? gymId; // id зала
  bool isActive;  
  String createdAt;
  String? telegramId;

  Client({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.subType,
    required this.startDate,
    required this.endDate,
    this.lastVisit,
    required this.updatedAt,
    this.gymId,
    this.isActive = true,
    required this.createdAt,
    this.telegramId,
  });

  // Метод для преобразования из Map (когда читаем из SQLite)
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      fullName: map['full_name'],
      phone: map['phone'],
      subType: map['sub_type'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      lastVisit: map['last_visit'],
      updatedAt: map['updated_at'],
      gymId: map['gym_id'],
       // SQLite хранит boolean как 0 или 1
      isActive: (map['is_active'] == 1 || map['is_active'] == true), 
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(), 
      telegramId: map['telegram_id'],
    );
  }

  // Метод для преобразования в Map (когда пишем в SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'sub_type': subType,
      'start_date': startDate,
      'end_date': endDate,
      'last_visit': lastVisit,
      'updated_at': updatedAt,
      'gym_id': gymId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'telegram_id': telegramId, 
    };
  }
}