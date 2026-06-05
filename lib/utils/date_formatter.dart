// lib/utils/date_formatter.dart

class DateFormatter {
  // Превращает "2026-05-28" или "2026-05-28T10:22:29" в "28-05-2026"
  static String format(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty || isoDate.length < 10) return 'Нет';
    try {
      final datePart = isoDate.substring(0, 10); // Берем только дату, отсекаем время
      final parts = datePart.split('-');
      return '${parts[2]}-${parts[1]}-${parts[0]}'; // Меняем местами
    } catch (e) {
      return isoDate; // Если что-то пошло не так, возвращаем как есть
    }
  }
}