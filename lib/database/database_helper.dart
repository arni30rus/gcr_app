import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
    final path = join(dbPath, 'gcr_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade,
    );
  }

  // Создание БД с нуля (для новых пользователей)
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
        is_active INTEGER DEFAULT 1
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
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Зарезервировано для будущих обновлений базы данных
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

  Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
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
        // ДЛЯ WINDOWS: Стандартный диалог "Сохранить как..."
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
        // ДЛЯ ANDROID: Меню "Поделиться" (Сохранить в файлы, отправить в Telegram и т.д.)
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
    // 1. Получаем путь к текущей БД, пока она открыта
    final db = await database; 
    final String destPath = db.path;

    // 2. Закрываем текущее соединение с БД
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    try {
      // 3. Небольшая задержка, чтобы ОС освободила файл
      await Future.delayed(const Duration(milliseconds: 300));

      // 4. Открываем диалог выбора файла
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: Platform.isWindows ? FileType.custom : FileType.any, // ИЗМЕНЕНО: Для Android используем FileType.any
        allowedExtensions: Platform.isWindows ? ['db'] : null,     // ИЗМЕНЕНО: Для Android нет ограничений
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        
        // 5. Копируем выбранный файл поверх активной базы
        await File(sourcePath).copy(destPath);
        return true; // Успешно
      }
      
      // Если пользователь отменил выбор - возвращаем false
      return false; 
    } catch (e) {
      print('ОШИБКА ИМПОРТА: $e');
      return false;
    } finally {
      // ВАЖНО: В ЛЮБОМ СЛУЧАЕ (даже при ошибке или отмене) 
      // переинициализируем базу данных, чтобы приложение не зависло!
      _database = null;
      await database; 
    }
  }

    // Получить статистику для дашборда
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final now = DateTime.now();
    
    // Форматируем даты для SQL запросов
    final todayStr = now.toIso8601String().substring(0, 10); // YYYY-MM-DD
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoStr = weekAgo.toIso8601String();
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthAgoStr = monthAgo.toIso8601String();
    
    // Истекает в ближайшие 3 дня
    final threeDaysLater = now.add(const Duration(days: 3));
    final threeDaysLaterStr = threeDaysLater.toIso8601String().substring(0, 10);

    // Вспомогательная функция для безопасного получения числа из запроса
    int getCount(List<Map<String, dynamic>> result) {
      if (result.isNotEmpty && result.first.containsKey('count')) {
        return result.first['count'] as int;
      }
      return 0;
    }

    // 1. Посещений сегодня (last_visit начинается с сегодняшней даты)
    int visitsToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE is_active = 1 AND last_visit LIKE ?", ['%$todayStr%']
    ));

    // 2. Активные абонементы (не в архиве и дата окончания >= сегодня)
    int active = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE is_active = 1 AND end_date >= ?", [todayStr]
    ));

    // 3. Новых за сегодня (updated_at начинается с сегодняшней даты)
    int newToday = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE updated_at LIKE ?", ['%$todayStr%']
    ));

    // 4. Новых за неделю (updated_at >= 7 дней назад)
    int newWeek = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE updated_at >= ?", [weekAgoStr]
    ));

    // 5. Новых за месяц (updated_at >= 30 дней назад)
    int newMonth = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE updated_at >= ?", [monthAgoStr]
    ));

    // 6. Истекает скоро (end_date от сегодня до +3 дня)
    int expiring = getCount(await db.rawQuery(
      "SELECT COUNT(*) as count FROM clients WHERE is_active = 1 AND end_date >= ? AND end_date <= ?", [todayStr, threeDaysLaterStr]
    ));

    return {
      'visitsToday': visitsToday,
      'active': active,
      'newToday': newToday,
      'newWeek': newWeek,
      'newMonth': newMonth,
      'expiring': expiring,
    };
  }

}