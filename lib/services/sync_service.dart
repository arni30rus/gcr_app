import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/client.dart';
import '../models/subscription_type.dart';
import 'db_config_service.dart'; 

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // Используем геттер (lazy initialization). 
  // Supabase.instance.client будет вызван ТОЛЬКО когда мы обратимся к _supabase внутри метода synchronize()
  SupabaseClient get _supabase => Supabase.instance.client; 

  // Ключ для хранения времени последней синхронизации
  final String _lastSyncKey = 'last_sync_time';

  // Получить время последней синхронизации
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? timeStr = prefs.getString(_lastSyncKey);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null; // Если никогда не синхронизировались
  }

  // Сохранить время синхронизации
  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  // Основной метод синхронизации
  Future<String> synchronize() async {
    try {
      final DateTime? lastSync = await getLastSyncTime();
      final DateTime now = DateTime.now();

      // Получаем текущий gym_id из кэша (если пользователь авторизован в облаке)
      final dbConfigService = DbConfigService();
      final String? currentGymId = await dbConfigService.getCachedGymId();

      // ==========================================
      // 1. СИНХРОНИЗАЦИЯ ТИПОВ АБОНЕМЕНТОВ
      // ==========================================
      var typeQuery = _supabase.from('subscription_types').select();
      if (lastSync != null) {
        typeQuery = typeQuery.gte('updated_at', lastSync.toIso8601String());
      }
      final List<dynamic> remoteTypes = await typeQuery;

      for (var remoteData in remoteTypes) {
        SubscriptionType remoteType = SubscriptionType.fromMap(remoteData);
        SubscriptionType? localType = (await _dbHelper.getAllSubscriptionTypes())
            .where((t) => t.id == remoteType.id)
            .firstOrNull;

        if (localType == null) {
          await _dbHelper.insertSubscriptionType(remoteType);
        } else {
          DateTime localUpdated = DateTime.parse(localType.updatedAt);
          DateTime remoteUpdated = DateTime.parse(remoteType.updatedAt);
          if (remoteUpdated.isAfter(localUpdated)) {
            await _dbHelper.updateSubscriptionType(remoteType);
          }
        }
      }

      List<SubscriptionType> allLocalTypes = await _dbHelper.getAllSubscriptionTypes();
      List<SubscriptionType> typesToPush = [];
      for (var localType in allLocalTypes) {
        
        // АВТОПРИВЯЗКА К ЗАЛУ: Если тип из локальной базы без gym_id, а мы авторизованы
        bool wasModified = false;
        if (localType.gymId == null && currentGymId != null) {
          localType.gymId = currentGymId;
          localType.updatedAt = now.toIso8601String(); // Обновляем дату, чтобы сервер принял
          await _dbHelper.updateSubscriptionType(localType); // Сохраняем локально
          wasModified = true;
        }

        if (lastSync == null || wasModified) {
          typesToPush.add(localType);
        } else {
          DateTime localUpdated = DateTime.parse(localType.updatedAt);
          if (localUpdated.isAfter(lastSync)) {
            typesToPush.add(localType);
          }
        }
      }
      if (typesToPush.isNotEmpty) {
        await _supabase.from('subscription_types').upsert(typesToPush.map((t) => t.toMap()).toList());
      }

      // ==========================================
      // 2. СИНХРОНИЗАЦИЯ КЛИЕНТОВ
      // ==========================================
      var query = _supabase.from('clients').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> remoteClients = await query;

      for (var remoteData in remoteClients) {
        Client remoteClient = Client.fromMap(remoteData);
        Client? localClient = await _dbHelper.getClient(remoteClient.id);

        if (localClient == null) {
          await _dbHelper.insertClient(remoteClient);
        } else {
          DateTime localUpdated = DateTime.parse(localClient.updatedAt);
          DateTime remoteUpdated = DateTime.parse(remoteClient.updatedAt);

          if (remoteUpdated.isAfter(localUpdated)) {
            await _dbHelper.updateClient(remoteClient);
          }
        }
      }

      List<Client> allLocalClients = await _dbHelper.getAllClients();
      List<Client> clientsToPush = [];

      for (var localClient in allLocalClients) {
        
        // АВТОПРИВЯЗКА К ЗАЛУ: Если клиент из локальной базы без gym_id, а мы авторизованы
        bool wasModified = false;
        if (localClient.gymId == null && currentGymId != null) {
          localClient.gymId = currentGymId;
          localClient.updatedAt = now.toIso8601String(); // Обновляем дату
          await _dbHelper.updateClient(localClient); // Сохраняем локально
          wasModified = true;
        }

        if (lastSync == null || wasModified) {
          clientsToPush.add(localClient);
        } else {
          DateTime localUpdated = DateTime.parse(localClient.updatedAt);
          if (localUpdated.isAfter(lastSync)) {
            clientsToPush.add(localClient);
          }
        }
      }

      if (clientsToPush.isNotEmpty) {
        final List<Map<String, dynamic>> pushData = clientsToPush.map((c) => c.toMap()).toList();
        await _supabase.from('clients').upsert(pushData);
      }

      await _saveLastSyncTime(now);

      return 'Синхронизация успешна!\nТипы: +${remoteTypes.length}/↑${typesToPush.length}\nКлиенты: +${remoteClients.length}/↑${clientsToPush.length}';
    } catch (e) {
      return 'Ошибка синхронизации: $e';
    }
  }
  
  // Получить ID зала текущего пользователя ИЗ КЭША
  Future<String?> getCurrentUserGymId() async {
    final dbConfigService = DbConfigService();
    return await dbConfigService.getCachedGymId();
  }
}