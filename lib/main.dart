import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/scanner_screen.dart';
import 'screens/client_list_screen.dart';
import 'screens/subscription_types_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/auth_screen.dart';
import 'services/sync_service.dart';
import 'services/db_config_service.dart';
import 'database/database_helper.dart';
import 'screens/about_screen.dart';
import 'widgets/confirm_delete_dialog.dart';
import 'screens/dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: const AppLoader(), // Приложение теперь начинается с загрузчика

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Поддерживаем русский
        Locale('en', 'US'), // И английский (обязательно для базы)
      ],
      locale: const Locale('ru', 'RU'),

    );
  }
}

// ==========================================
// ЭКРАН ЗАГРУЗКИ (Решает, куда направить)
// ==========================================
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  final DbConfigService _dbConfigService = DbConfigService();
  bool _isLoading = true;
  bool _isConfigured = false;
  bool _showAuth = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
   bool configured = await _dbConfigService.isConfigured();
    
    if (configured) {
      bool isLocal = await _dbConfigService.isLocalDb();
      
      if (!isLocal) {
        // Если облако - инициализируем Supabase
        String url = await _dbConfigService.getUrl();
        String key = await _dbConfigService.getAnonKey();
        await Supabase.initialize(url: url, anonKey: key);
        
        bool isCustom = await _dbConfigService.isCustomDb();
        bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;
        
        if (isLoggedIn && !isCustom) {
          // ЗАПУСКАЕМ В ФОНЕ! Не ждём завершения (await убран).
          // Таймаут внутри метода не даст ему зависнуть навечно.
          _dbConfigService.fetchAndCacheGymId(); 
        }

        setState(() {
          _isConfigured = true;
          _showAuth = !isCustom && !isLoggedIn;
          _isLoading = false;
        });
      } else {
        // Если ЛОКАЛЬНЫЙ режим - пропускаем Supabase
        setState(() {
          _isConfigured = true;
          _showAuth = false; // Авторизация не нужна
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isConfigured = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _onSetupComplete(String url, String anonKey) async {
    setState(() => _isLoading = true);
    
    bool isLocal = await _dbConfigService.isLocalDb();

    if (!isLocal && url.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: anonKey);
      
      bool isCustom = await _dbConfigService.isCustomDb();
      bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

      if (isLoggedIn && !isCustom) {
        // Тоже запускаем в фоне при перенастройке
        _dbConfigService.fetchAndCacheGymId();
      }

      setState(() {
        _isConfigured = true;
        _showAuth = !isCustom && !isLoggedIn;
        _isLoading = false;
      });
    } else {
      // Локальный режим
      setState(() {
        _isConfigured = true;
        _showAuth = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isConfigured) {
      return SetupScreen(
        dbConfigService: _dbConfigService,
        onConfigComplete: _onSetupComplete,
      );
    }

   if (_showAuth) {
      return AuthScreen(
        onSuccess: () async {
          await _dbConfigService.fetchAndCacheGymId();
          setState(() => _showAuth = false);
        },
        // ДОБАВЛЕНО: Возврат на экран настройки базы данных
        onBack: () async {
          // Сбрасываем настройку, чтобы приложение "забыло" выбранное облако
          await _dbConfigService.clearConfig();
          setState(() {
            _isConfigured = false; // Показываем SetupScreen
            _showAuth = false;
          });
        },
      );
    }

    return const HomeScreen();
  }
}

// ==========================================
// ГЛАВНЫЙ ЭКРАН ПРИЛОЖЕНИЯ (Ваш код)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _syncStatus = '';
  final SyncService _syncService = SyncService();
  final DbConfigService _dbConfigService = DbConfigService(); // Добавлено для смены БД

  // Настройки таймера
  int _syncIntervalMinutes = 60; // По умолчанию 1 раз в час
  Timer? _syncTimer;
  final String _intervalPrefsKey = 'sync_interval';

  static const List<Widget> _widgetOptions = <Widget>[
    ScannerScreen(),
    ClientListScreen(),
    SubscriptionTypesScreen(),
    DashboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStartTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // Загрузка настроек и запуск таймера
 Future<void> _loadSettingsAndStartTimer() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncIntervalMinutes = prefs.getInt(_intervalPrefsKey) ?? 60;
    });
    
    bool isLocal = await _dbConfigService.isLocalDb();
    
    if (!isLocal) {
      _checkAndSyncOnLaunch();
      _startSyncTimer();       
    }
  }

  // Проверка: нужно ли синхронизировать при запуске приложения
  Future<void> _checkAndSyncOnLaunch() async {
    if (_syncIntervalMinutes == 0) return;

    final lastSync = await _syncService.getLastSyncTime();
    if (lastSync == null) {
      _manualSync(); 
    } else {
      final difference = DateTime.now().difference(lastSync).inMinutes;
      if (difference >= _syncIntervalMinutes) {
        _manualSync(); 
      }
    }
  }

  // Запуск таймера
  void _startSyncTimer() {
    _syncTimer?.cancel(); 
    if (_syncIntervalMinutes > 0) {
      _syncTimer = Timer.periodic(Duration(minutes: _syncIntervalMinutes), (timer) {
        _manualSync();
      });
    }
  }

  Future<void> _manualSync() async {
    bool isLocal = await _dbConfigService.isLocalDb();
    if (isLocal) {
      // В локальном режиме просто показываем уведомление
      setState(() => _syncStatus = 'Локальный режим. Синхронизация отключена.');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncStatus = '');
      });
      return;
    }

    setState(() => _syncStatus = 'Синхронизация...');
    final result = await _syncService.synchronize();
    setState(() => _syncStatus = result);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _syncStatus = '');
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

   // Диалог выбора интервала + кнопки управления БД и Аккаунтом
  void _showSettingsDialog() {
    showDialog(
      context: context, // Контекст экрана HomeScreen
      builder: (BuildContext dialogContext) { // Используем отдельное имя для контекста диалога
        return StatefulBuilder(
          builder: (BuildContext statefulContext, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Настройки'),
              content: SingleChildScrollView( // Добавил ScrollView, чтобы не вылезало за экран на маленьких телефонах
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Интервал синхронизации:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<int>(
                      title: const Text('Каждые 15 минут'),
                      value: 15,
                      groupValue: _syncIntervalMinutes,
                      onChanged: (val) => setStateDialog(() => _syncIntervalMinutes = val!),
                    ),
                    RadioListTile<int>(
                      title: const Text('Каждый час'),
                      value: 60,
                      groupValue: _syncIntervalMinutes,
                      onChanged: (val) => setStateDialog(() => _syncIntervalMinutes = val!),
                    ),
                    RadioListTile<int>(
                      title: const Text('Каждые 2 часа'),
                      value: 120,
                      groupValue: _syncIntervalMinutes,
                      onChanged: (val) => setStateDialog(() => _syncIntervalMinutes = val!),
                    ),
                    RadioListTile<int>(
                      title: const Text('1 раз в сутки'),
                      value: 1440,
                      groupValue: _syncIntervalMinutes,
                      onChanged: (val) => setStateDialog(() => _syncIntervalMinutes = val!),
                    ),
                    RadioListTile<int>(
                      title: const Text('Только вручную'),
                      value: 0,
                      groupValue: _syncIntervalMinutes,
                      onChanged: (val) => setStateDialog(() => _syncIntervalMinutes = val!),
                    ),
                    const Divider(height: 20),
                    
                                    // КНОПКА ОЧИСТКИ ЛОКАЛЬНОГО АРХИВА
                                    // КНОПКА ОЧИСТКИ ЛОКАЛЬНОГО АРХИВА
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: Colors.grey),
                    title: const Text('Очистить локальный архив'),
                    subtitle: const Text('Удалить скрытых клиентов и абонементы из памяти'), // Обновили текст
                    onTap: () async {
                      Navigator.pop(dialogContext); 
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmDeleteDialog(itemName: 'все данные архивных клиентов и абонементов'), // Обновили текст
                      );
                      if (confirmed == true) {
                        final dbHelper = DatabaseHelper();
                        await dbHelper.clearLocalArchive(); // Вызываем новый метод
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Локальный архив очищен')),
                          );
                        }
                      }
                    },
                  ),

                  const Divider(height: 20),

// ЭКСПОРТ БАЗЫ
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.blue),
                    title: const Text('Экспорт базы данных'),
                    subtitle: const Text('Сохранить копию базы (.db файл)'),
                    onTap: () async {
                      Navigator.pop(dialogContext); 
                      try {
                        final dbHelper = DatabaseHelper();
                        await dbHelper.exportDatabase();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка экспорта: $e')),
                          );
                        }
                      }
                    },
                  ),

                  // ИМПОРТ БАЗЫ
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.orange),
                    title: const Text('Импорт базы данных'),
                    subtitle: const Text('Восстановить данные из файла бэкапа'),
                    onTap: () async {
                      Navigator.pop(dialogContext); 
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmDeleteDialog(itemName: 'ТЕКУЩИЕ ДАННЫЕ (они будут заменены данными из файла)'),
                      );
                      if (confirmed == true) {
                        final dbHelper = DatabaseHelper();
                        bool success = await dbHelper.importDatabase();
                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('База успешно импортирована! Перезапустите приложение.')),
                            );
                            Future.delayed(const Duration(seconds: 2), () => exit(0));
                          } else {
                            // ДОБАВЛЕНО: Если отменили выбор файла
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Импорт отменен или файл не выбран')),
                            );
                          }
                        }
                      }
                    },
                  ),

                  // ЕДИНАЯ КНОПКА ВЫХОДА / ОТКЛЮЧЕНИЯ
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text('Выйти / Сменить базу данных'),
                    subtitle: const Text('Вернуться на экран выбора подключения'),
                    onTap: () async {
                      Navigator.pop(dialogContext); // Закрываем диалог настроек
                      
                      try {
                        // 1. Выходим из аккаунта Supabase (если были в Основном облаке)
                        await Supabase.instance.client.auth.signOut();
                      } catch (e) {
                        // Игнорируем ошибку, если сессии нет (например, при "Своей базе")
                      }

                      // 2. Очищаем кэш зала и настройки подключения
                      await _dbConfigService.clearCachedGymId();
                      await _dbConfigService.clearConfig();

                      // 3. Перезапускаем приложение
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Вы вышли. Перезапустите приложение.')),
                        );
                        Future.delayed(const Duration(seconds: 1), () => exit(0));
                      }
                    },
                  ),


                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), // Используем контекст диалога
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_intervalPrefsKey, _syncIntervalMinutes);
                    
                    setState(() {}); 
                    _startSyncTimer(); 
                    
                    Navigator.pop(dialogContext); // Используем контекст диалога
                    // Показываем снэкбар используя контекст экрана, а не диалога!
                    ScaffoldMessenger.of(context).showSnackBar( 
                      const SnackBar(content: Text('Настройки сохранены')),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GYM client registration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            onPressed: _manualSync,
            tooltip: 'Синхронизация',
          ),
            IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
            tooltip: 'О приложении',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_syncStatus.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue,
              padding: const EdgeInsets.all(8),
              child: Text(_syncStatus, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
          Expanded(child: Center(child: _widgetOptions.elementAt(_selectedIndex))),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Сканер',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Клиенты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership),
            label: 'Абонементы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Статистика', // НОВОЕ
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, 
      ),
    );
  }
}