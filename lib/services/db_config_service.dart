import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class DbConfigService {
  static const String _isConfiguredKey = 'is_db_configured';
  static const String _isCustomDbKey = 'is_custom_db';
  static const String _customUrlKey = 'custom_supabase_url';
  static const String _customAnonKey = 'custom_supabase_anon_key';

  // ВАШИ КЛЮЧИ ОТ ОСНОВНОГО ОБЛАКА (ДЛЯ ВАШИХ ЗАЛОВ)
  static const String defaultUrl = 'https://zxpulnhzoaxueuabemon.supabase.co';
  static const String defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4cHVsbmh6b2F4dWV1YWJlbW9uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3NTk3OTAsImV4cCI6MjA5NTMzNTc5MH0.l-Z_-8G_JYK1nxi_5f0f6QnfgzzxKa2CiR_JMZX4tmE';

  Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isConfiguredKey) ?? false;
  }

  Future<bool> isCustomDb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isCustomDbKey) ?? false;
  }

  Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    if (await isCustomDb()) {
      return prefs.getString(_customUrlKey) ?? '';
    }
    return defaultUrl;
  }

  Future<String> getAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (await isCustomDb()) {
      return prefs.getString(_customAnonKey) ?? '';
    }
    return defaultAnonKey;
  }

  Future<void> setDefaultConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isConfiguredKey, true);
    await prefs.setBool(_isCustomDbKey, false);
  }

  Future<void> setCustomConfig(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isConfiguredKey, true);
    await prefs.setBool(_isCustomDbKey, true);
    await prefs.setString(_customUrlKey, url);
    await prefs.setString(_customAnonKey, anonKey);
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isConfiguredKey);
    await prefs.remove(_isCustomDbKey);
    await prefs.remove(_customUrlKey);
    await prefs.remove(_customAnonKey);
    await prefs.remove(_isLocalDbKey); // ДОБАВИТЬ
    await prefs.remove(_cachedGymIdKey);
  }

    // =========== КЭШИРОВАНИЕ GYM_ID ===========
  final String _cachedGymIdKey = 'cached_gym_id';

  Future<String?> getCachedGymId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cachedGymIdKey);
  }

    Future<void> fetchAndCacheGymId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Сначала формируем запрос и сохраняем его в переменную (как Future)
      final queryFuture = Supabase.instance.client
          .from('user_gyms')
          .select('gym_id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      // 2. Затем ожидаем результат с таймаутом 5 секунд
      final response = await queryFuture.timeout(const Duration(seconds: 10));

      if (response != null) {
        final gymId = response['gym_id'] as String?;
        if (gymId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cachedGymIdKey, gymId);
        }
      }
    } catch (e) {
      // Если таймаут или ошибка сети - просто игнорируем. 
      // Приложение будет использовать старый закэшированный gym_id.
      print('Ошибка/Таймаут получения gym_id: $e');
    }
  }

  Future<void> clearCachedGymId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedGymIdKey);
  }

  static const String _isLocalDbKey = 'is_local_db';

  Future<bool> isLocalDb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLocalDbKey) ?? false;
  }

  Future<void> setLocalConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isConfiguredKey, true);
    await prefs.setBool(_isCustomDbKey, false); // Не custom, а именно локальная
    await prefs.setBool(_isLocalDbKey, true);
  }

}