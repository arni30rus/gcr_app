import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/client.dart';
import '../models/subscription_type.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    // ИЗМЕНЕНО ИМЯ ФАЙЛА: Это заставит создать БД с нуля по новой схеме!
    final path = join(dbPath, 'gcr_app_db_v4.db');

    return await openDatabase(
      path,
      version: 1, // Версия снова 1, так как это новая БД
      onCreate: _onCreate,
    );
  }

  // Создание БД с нуля (для новых пользователей или при смене имени файла)
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subscription_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_unlimited_time INTEGER NOT NULL,
        allowed_days TEXT NOT NULL,
        is_vip INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        gym_id TEXT,
        is_active INTEGER DEFAULT 1,
        is_one_time_visit INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        sub_type INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        last_visit TEXT,
        updated_at TEXT NOT NULL,
        gym_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // НОВАЯ ТАБЛИЦА: История посещений
    await db.execute('''
      CREATE TABLE visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        gym_id TEXT
      )
    ''');

// НОВАЯ ТАБЛИЦА: История продлений
    await db.execute('''
      CREATE TABLE renewals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        gym_id TEXT
      )
  ''');
  }


  // --- CRUD ДЛЯ КЛИЕНТОВ ---
  Future<void> insertClient(Client client) async {
    final db = await database;
    await db.insert('clients', client.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Client?> getClient(String id) async {
    final db = await database;
    final maps = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Client.fromMap(maps.first);
    return null;
  }

  Future<void> updateClient(Client client) async {
    final db = await database;
    await db.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  Future<List<Client>> getAllClients() async {
    final db = await database;
    final maps = await db.query('clients');
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD ДЛЯ ТИПОВ АБОНЕМЕНТОВ ---
  Future<List<SubscriptionType>> getAllSubscriptionTypes() async {
    final db = await database;
    final maps = await db.query('subscription_types');
    return maps.map((map) => SubscriptionType.fromMap(map)).toList();
  }

  Future<void> insertSubscriptionType(SubscriptionType type) async {
    final db = await database;
    await db.insert('subscription_types', type.toMap());
  }

  Future<void> updateSubscriptionType(SubscriptionType type) async {
    final db = await database;
    await db.update('subscription_types', type.toMap(), where: 'id = ?', whereArgs: [type.id]);
  }

  Future<void> deleteSubscriptionType(int id) async {
    final db = await database;
    await db.delete('subscription_types', where: 'id = ?', whereArgs: [id]);
  }

// --- CRUD ДЛЯ ВИЗИТОВ ---
  Future<void> insertVisit(String clientId, String? gymId) async {
    final db = await database;
    await db.insert('visits', {
      'client_id': clientId,
      'created_at': DateTime.now().toIso8601String(),
      'gym_id': gymId, // Обязательно передаем gymId
    });
  }

  // --- CRUD ДЛЯ ПРОДЛЕНИЙ ---
  Future<void> insertRenewal(String clientId, String? gymId) async {
    final db = await database;
    await db.insert('renewals', {
      'client_id': clientId,
      'created_at': DateTime.now().toIso8601String(),
      'gym_id': gymId,
    });
  }

  // Физически удаляем из локальной БД всех архивных клиентов и типов абонементов
  Future<void> clearLocalArchive() async {
    final db = await database;
    await db.delete('clients', where: 'is_active = ?', whereArgs: [0]);
    await db.delete('subscription_types', where: 'is_active = ?', whereArgs: [0]);
  }

  // ЭКСПОРТ: Сохранить/Отправить текущую базу данных
  Future<void> exportDatabase() async {
    final db = await database; 
    final String path = db.path;
    final file = File(path);

    if (await file.exists()) {
      final now = DateTime.now();
      final filename = 'GCR_APP_Backup_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.db';

      if (Platform.isWindows) {
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить резервную копию базы данных',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (outputPath != null) {
          await file.copy(outputPath);
        }
      } else {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Бэкап базы данных GCR APP',
          subject: filename,
        );
      }
    } else {
      throw Exception('Файл базы данных не найден по пути: $path');
    }
  }

  // ИМПОРТ: Выбрать файл и заменить им текущую базу
  Future<bool> importDatabase() async {
    final db = await database; 
    final String destPath = db.path;

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: Platform.isWindows ? FileType.custom : FileType.any,
        allowedExtensions: Platform.isWindows ? ['db'] : null,
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        await File(sourcePath).copy(destPath);
        return true;
      }
      return false; 
    } catch (e) {
      print('ОШИБКА ИМПОРТА: $e');
      return false;
    } finally {
      _database = null;
      await database; 
    }
  }

   // Получить общую статистику для дашборда
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final now = DateTime.now();
    
    final todayStr = now.toIso8601String().substring(0, 10);
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoStr = weekAgo.toIso8601String();
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthAgoStr = monthAgo.toIso8601String();
    final threeDaysLater = now.add(const Duration(days: 3));
    final threeDaysLaterStr = threeDaysLater.toIso8601String().substring(0, 10);

    int getCount(List<Map<String, dynamic>> result) {
      if (result.isNotEmpty && result.first.containsKey('count')) {
        return result.first['count'] as int;
      }
      return 0;
    }

    // 1. ВСЕГО ПОСЕЩЕНИЙ СЕГОДНЯ (из таблицы visits - самая точная цифра)
    int visitsToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM visits WHERE created_at LIKE ?", ['%$todayStr%']
    ));

    // 2. АКТИВНЫЕ РЕАЛЬНЫЕ АБОНЕМЕНТЫ (Исключаем разовые)
    int active = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients c JOIN subscription_types st ON c.sub_type = st.id WHERE c.is_active = 1 AND c.end_date >= ? AND st.is_one_time_visit = 0", [todayStr]
    ));

    // 3. ИСТЕКАЕТ СКОРО (Реальные)
    int expiring = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients c JOIN subscription_types st ON c.sub_type = st.id WHERE c.is_active = 1 AND c.end_date >= ? AND c.end_date <= ? AND st.is_one_time_visit = 0", [todayStr, threeDaysLaterStr]
    ));

    // 4. НОВЫХ РЕАЛЬНЫХ ЗА СЕГОДНЯ/НЕДЕЛЮ/МЕСЯЦ (ИСПРАВЛЕНО: используем created_at)
    int newToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients c JOIN subscription_types st ON c.sub_type = st.id WHERE c.created_at LIKE ? AND st.is_one_time_visit = 0", ['%$todayStr%']
    ));
    int newWeek = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients c JOIN subscription_types st ON c.sub_type = st.id WHERE c.created_at >= ? AND st.is_one_time_visit = 0", [weekAgoStr]
    ));
    int newMonth = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients c JOIN subscription_types st ON c.sub_type = st.id WHERE c.created_at >= ? AND st.is_one_time_visit = 0", [monthAgoStr]
    ));

    // 5. ПРОДЛЕНО СЕГОДНЯ И ЗА МЕСЯЦ (НОВОЕ)
    int renewedToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM renewals WHERE created_at LIKE ?", ['%$todayStr%']
    ));
    int renewedMonth = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM renewals WHERE created_at >= ?", [monthAgoStr]
    ));

     // 6. РАЗОВЫЕ ПОСЕЩЕНИЯ ЗА СЕГОДНЯ И МЕСЯЦ (Стало проще, не нужен JOIN clients)
    int oneTimeToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM visits v JOIN subscription_types st ON v.client_id IN (SELECT id FROM clients WHERE sub_type = st.id) WHERE v.created_at LIKE ? AND st.is_one_time_visit = 1", ['%$todayStr%']
    ));
    int oneTimeMonth = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM visits v JOIN subscription_types st ON v.client_id IN (SELECT id FROM clients WHERE sub_type = st.id) WHERE v.created_at >= ? AND st.is_one_time_visit = 1", [monthAgoStr]
    ));

    return {
      'visitsToday': visitsToday,
      'active': active,
      'expiring': expiring,
      'newToday': newToday,
      'newWeek': newWeek,
      'newMonth': newMonth,
      'renewedToday': renewedToday,
      'renewedMonth': renewedMonth,
      'oneTimeToday': oneTimeToday,
      'oneTimeMonth': oneTimeMonth,
    };
  }

  // Получить статистику по каждому типу абонемента (для динамических карточек)
  Future<List<Map<String, dynamic>>> getTypeStats() async {
    final db = await database;
    final now = DateTime.now();
    
    final todayStr = now.toIso8601String().substring(0, 10);
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthAgoStr = monthAgo.toIso8601String();

    // Берем все АКТИВНЫЕ и НЕ РАЗОВЫЕ типы
    final types = await db.query(
      'subscription_types',
      where: 'is_active = ? AND is_one_time_visit = ?',
      whereArgs: [1, 0],
    );

    List<Map<String, dynamic>> stats = [];

    for (var type in types) {
      final typeId = type['id'];

      // Считаем новых клиентов за сегодня по этому типу
      int newToday = 0;
      final todayResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM clients WHERE sub_type = ? AND updated_at LIKE ?",
        [typeId, '%$todayStr%']
      );
      if (todayResult.isNotEmpty) newToday = todayResult.first['count'] as int;

      // Считаем новых клиентов за месяц по этому типу
      int newMonth = 0;
      final monthResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM clients WHERE sub_type = ? AND updated_at >= ?",
        [typeId, monthAgoStr]
      );
      if (monthResult.isNotEmpty) newMonth = monthResult.first['count'] as int;

      stats.add({
        'name': type['name'],
        'newToday': newToday,
        'newMonth': newMonth,
        'isVip': (type['is_vip'] == 1 || type['is_vip'] == true),
      });
    }

    return stats;
  }

  // Очистить таблицу визитов (освободить место)
  Future<void> clearVisits() async {
    final db = await database;
    await db.delete('visits');
  }

  // Полностью удаляем файл базы данных для чистого старта
  Future<void> resetDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gcr_app_db_v4.db');
    final file = File(path);
    
    if (await file.exists()) {
      await file.delete();
    }
  }
}