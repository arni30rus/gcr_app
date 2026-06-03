import '../models/client.dart';
import '../models/subscription_type.dart';

class SubscriptionResult {
  final bool isActive;
  final String reason;
  final bool isVip; // Передаем VIP статус дальше на экран

  SubscriptionResult({required this.isActive, required this.reason, this.isVip = false});
}

class SubscriptionService {

  SubscriptionResult checkSubscription(Client client, SubscriptionType subType, DateTime now) {
    // 1. Проверяем VIP статус (передаем в результат)
    bool isVip = subType.isVip;

    // 2. Проверяем даты
    DateTime startDate = DateTime.parse(client.startDate);
    DateTime endDate = DateTime.parse(client.endDate);
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime startDay = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (today.isBefore(startDay)) {
      return SubscriptionResult(isActive: false, reason: 'Абонемент еще не начался', isVip: isVip);
    }
    if (today.isAfter(endDay)) {
      return SubscriptionResult(isActive: false, reason: 'Срок абонемента истек', isVip: isVip);
    }

    // 3. Проверяем дни недели (если заданы)
    if (subType.allowedDays.isNotEmpty) {
      List<int> allowedDays = subType.allowedDays.split(',').map(int.parse).toList();
      if (!allowedDays.contains(now.weekday)) {
        return SubscriptionResult(isActive: false, reason: 'Абонемент не действует в этот день недели', isVip: isVip);
      }
    }

    // 4. Проверяем время (если не безлимит по времени)
    if (!subType.isUnlimitedTime) {
      int startMinutes = _parseTime(subType.startTime);
      int endMinutes = _parseTime(subType.endTime);
      int nowMinutes = now.hour * 60 + now.minute;

      if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
        return SubscriptionResult(
          isActive: false, 
          reason: 'Абонемент действует с ${subType.startTime} до ${subType.endTime}', 
          isVip: isVip
        );
      }
    }

    // Если все проверки пройдены
    return SubscriptionResult(isActive: true, reason: 'Абонемент активен', isVip: isVip);
  }

  // Вспомогательный метод: переводит "08:00" в минуты от начала дня (480)
  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}