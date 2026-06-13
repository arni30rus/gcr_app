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
  String _authTitle = 'систему'; 

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
        
        bool isCustom = await _dbConfigService.isCustomDb(); // Получаем статус Custom
        bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;
        
        if (isLoggedIn) {
          // ЗАПУСКАЕМ В ФОНЕ! Не ждём завершения.
          _dbConfigService.fetchAndCacheGymId(); 
        }

        setState(() {
          _isConfigured = true;
          _showAuth = !isLoggedIn; // Показываем авторизацию, если не залогинен (и для основного, и для своего облака!)
          _authTitle = isCustom ? 'свою базу данных' : 'основное облако'; // Динамический заголовок
          _isLoading = false;
        });
      } else {
        // Если ЛОКАЛЬНЫЙ режим - пропускаем Supabase
        setState(() {
          _isConfigured = true;
          _showAuth = false; 
          _authTitle = 'систему';
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
      
      bool isCustom = await _dbConfigService.isCustomDb(); // Получаем статус Custom
      bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

      if (isLoggedIn) {
        _dbConfigService.fetchAndCacheGymId();
      }

      setState(() {
        _isConfigured = true;
        _showAuth = !isLoggedIn; // Показываем авторизацию, если не залогинен
        _authTitle = isCustom ? 'свою базу данных' : 'основное облако'; // Динамический заголовок
        _isLoading = false;
      });
    } else {
      // Локальный режим
      setState(() {
        _isConfigured = true;
        _showAuth = false;
        _authTitle = 'систему';
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
        dbName: _authTitle, 
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

 String? _appPin; // Хранит текущий пароль
  int _selectedSyncDropdownValue = 60; // Значение для компактного выпадающего списка
  final TextEditingController _customMinutesController = TextEditingController(); // Для своего интервала

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
    _loadPin();
  }
// метод для пин кода
 Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appPin = prefs.getString('app_pin');
    });
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

 // Метод проверки пароля (вызывается перед опасными действиями)
  Future<bool> _verifyPin() async {
    if (_appPin == null) return true; // Если пароль не установлен, пропускаем
    
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Введите пароль'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'PIN-код'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text == _appPin),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

    // Метод установки/смены пароля
  Future<void> _showSetPinDialog() async {
    // Если пароль уже установлен, сначала просим его ввести для подтверждения прав
    if (_appPin != null) {
      final currentPinController = TextEditingController();
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Подтверждение'),
          content: TextField(
            controller: currentPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Введите текущий пароль'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, currentPinController.text == _appPin),
              child: const Text('Ок'),
            ),
          ],
        ),
      );

      // Если отменили или ввели неверно - выходим
      if (verified != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный текущий пароль'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    // Если пароля не было или старый введен верно — запрашиваем новый
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_appPin == null ? 'Установить пароль' : 'Сменить пароль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: c1, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Новый пароль')),
            TextField(controller: c2, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Подтвердите пароль')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (c1.text.isEmpty || c1.text != c2.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароли не совпадают или пусты')));
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_pin', c1.text);
              setState(() => _appPin = c1.text);
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль успешно установлен!')));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Метод удаления пароля
  Future<void> _removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin');
    setState(() => _appPin = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль отключен')));
  }


     // Диалог выбора интервала + кнопки управления БД и Аккаунтом
  void _showSettingsDialog() {
    // Синхронизируем значение выпадающего списка с сохраненным
    _selectedSyncDropdownValue = _syncIntervalMinutes;
    // Если текущее значение не стандартное, ставим кастомное
    if (![0, 30, 60, 120, 1440].contains(_syncIntervalMinutes)) {
      _selectedSyncDropdownValue = -1; // -1 будет означать "Свой вариант"
      _customMinutesController.text = _syncIntervalMinutes.toString();
    }

    showDialog(
      context: context, 
      builder: (BuildContext dialogContext) { 
        return StatefulBuilder(
          builder: (BuildContext statefulContext, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Настройки'),
              content: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- КОМПАКТНЫЙ ВЫБОР ИНТЕРВАЛА ---
                    Row(
                      children: [
                        const Expanded(child: Text('Синхронизация:', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _selectedSyncDropdownValue,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 30, child: Text('30 мин')),
                              DropdownMenuItem(value: 60, child: Text('1 час')),
                              DropdownMenuItem(value: 120, child: Text('2 часа')),
                              DropdownMenuItem(value: 1440, child: Text('1 раз в сутки')),
                              DropdownMenuItem(value: 0, child: Text('Вручную')),
                              DropdownMenuItem(value: -1, child: Text('Свой вариант')),
                            ],
                            onChanged: (val) {
                              setStateDialog(() {
                                _selectedSyncDropdownValue = val!;
                                if (val != -1) {
                                  _syncIntervalMinutes = val;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    // Поле ввода для своего варианта
                    if (_selectedSyncDropdownValue == -1) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Интервал в минутах',
                          border: OutlineInputBorder(),
                          isDense: true
                        ),
                        onChanged: (val) {
                          final mins = int.tryParse(val);
                          if (mins != null) _syncIntervalMinutes = mins;
                        },
                      ),
                    ],

                    const Divider(height: 30),

                    // --- БЕЗОПАСНОСТЬ ---
                    ListTile(
                      dense: true,
                      leading: Icon(_appPin == null ? Icons.lock_open : Icons.lock, color: Colors.orange),
                      title: Text(_appPin == null ? 'Установить пароль' : 'Сменить пароль'),
                      subtitle: Text(_appPin == null ? 'Защита опасных кнопок' : 'Пароль установлен'),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _showSetPinDialog();
                      },
                    ),
                    if (_appPin != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.lock_open, color: Colors.grey),
                        title: const Text('Отключить пароль'),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          if (await _verifyPin()) _removePin();
                        },
                      ),

                    const Divider(height: 20),

                    // --- ОПАСНЫЕ КНОПКИ (ЗАЩИЩЕННЫЕ ПАРОЛЕМ) ---
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined, color: Colors.grey),
                      title: const Text('Очистить локальный архив', style: TextStyle(fontSize: 14)),
                      onTap: () async {
                        Navigator.pop(dialogContext); 
                        if (!await _verifyPin()) return; // ПРОВЕРКА ПАРОЛЯ
                        
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDeleteDialog(itemName: 'все данные архивных клиентов и абонементов'),
                        );
                        if (confirmed == true) {
                          final dbHelper = DatabaseHelper();
                          await dbHelper.clearLocalArchive(); 
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Локальный архив очищен')),
                            );
                          }
                        }
                      },
                    ),

// --- ЭКСПОРТ / ИМПОРТ ---
                    ListTile(
                      leading: const Icon(Icons.upload_file, color: Colors.blue),
                      title: const Text('Экспорт базы данных', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Сохранить копию базы (.db файл)', style: TextStyle(fontSize: 11)),
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

                    ListTile(
                      leading: const Icon(Icons.download, color: Colors.orange),
                      title: const Text('Импорт базы данных', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Восстановить данные из файла бэкапа', style: TextStyle(fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(dialogContext); 
                        if (!await _verifyPin()) return; // Защита паролем при импорте!
                        
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Импорт отменен или файл не выбран')),
                              );
                            }
                          }
                        }
                      },
                    ),

                    const Divider(height: 20),

                    ListTile(
                      leading: const Icon(Icons.restore, color: Colors.deepOrange),
                      title: const Text('Сбросить все данные', style: TextStyle(fontSize: 14)),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        if (!await _verifyPin()) return; // ПРОВЕРКА ПАРОЛЯ
                        
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDeleteDialog(itemName: 'ВСЕ ДАННЫЕ (база будет пересоздана)'),
                        );
                        if (confirmed == true) {
                          final dbHelper = DatabaseHelper();
                          await dbHelper.resetDatabase();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('База данных сброшена! Перезапустите приложение.')),
                            );
                            Future.delayed(const Duration(seconds: 1), () => exit(0));
                          }
                        }
                      },
                    ),

                    ListTile(
                      leading: const Icon(Icons.exit_to_app, color: Colors.red),
                      title: const Text('Выйти / Сменить базу данных', style: TextStyle(fontSize: 14)),
                      onTap: () async {
                        Navigator.pop(dialogContext); 
                        if (!await _verifyPin()) return; // ПРОВЕРКА ПАРОЛЯ
                        
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDeleteDialog(itemName: 'текущую сессию и переключить режим'),
                        );
                        
                        if (confirmed == true) {
                          try { await Supabase.instance.client.auth.signOut(); } catch (e) {}
                          await _dbConfigService.clearCachedGymId();
                          await _dbConfigService.clearConfig();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Вы вышли. Перезапустите приложение.')),
                            );
                            Future.delayed(const Duration(seconds: 1), () => exit(0));
                          }
                        }
                      },
                    ),

                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), 
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_intervalPrefsKey, _syncIntervalMinutes);
                    
                    setState(() {}); 
                    _startSyncTimer(); 
                    
                    Navigator.pop(dialogContext); 
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