import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../database/database_helper.dart';
import '../models/client.dart';
import '../services/subscription_service.dart';
import 'client_form_screen.dart';
import '../models/subscription_type.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Контроллер для скрытого поля (Windows HID сканер)
  final TextEditingController _hidController = TextEditingController();
  final FocusNode _hidFocusNode = FocusNode();
   // Контроллер для ручного ввода на Android
  final TextEditingController _manualInputController = TextEditingController();

  // Сервисы и БД
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SubscriptionService _subService = SubscriptionService();

  // Переменные
  Client? _currentClient;
  SubscriptionResult? _subResult;
  bool _isLoading = false;
  String _scannedCode = '';
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  bool _hasCameraPermission = false;

   List<SubscriptionType> _subTypes = [];

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _hidController.addListener(_onHidScan);
    }
    // Проверяем разрешение при открытии экрана (для Android)
    _checkCameraPermission();
    _loadSubTypes();
  }

  Future<void> _loadSubTypes() async {
    final types = await _dbHelper.getAllSubscriptionTypes();
    setState(() {
      _subTypes = types; // Убрали .where((t) => t.isActive).toList()
      // Сканер должен знать о ВСЕХ типах, включая архивы, чтобы корректно отображать старых клиентов
    });
  }

  Future<void> _checkCameraPermission() async {
    if (!Platform.isAndroid) return; // Для Windows не нужно

    var status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _hasCameraPermission = true);
    } else {
      // Если не дали - запрашиваем
      var result = await Permission.camera.request();
      setState(() => _hasCameraPermission = result.isGranted);
    }
  }
  @override
  void dispose() {
    _hidController.dispose();
    _hidFocusNode.dispose();
     _manualInputController.dispose();
    super.dispose();
  }

  // Обработка ввода от USB/Bluetooth сканера на Windows
  void _onHidScan() {
    String text = _hidController.text;
    // Сканеры обычно быстро вводят 13 цифр и нажимают Enter
    // Мы ловим момент, когда длина стала 13
    if (text.length == 13 && int.tryParse(text) != null) {
      _processBarcode(text);
      _hidController.clear(); // Очищаем для следующего сканирования
    }
  }

  // Общий обработчик отсканированного кода (и с камеры, и с HID)
  Future<void> _processBarcode(String code) async {
    // 1. Защита от множественных вызовов
    if (_isLoading) return;
    
    // 2. КУЛДАУН: Если тот же штрихкод сканируется менее чем за 3 секунды - игнорируем
    if (code == _lastScannedCode && _lastScanTime != null && DateTime.now().difference(_lastScanTime!).inSeconds < 3) {
      return;
    }

    // Запоминаем время и код сканирования
    _lastScannedCode = code;
    _lastScanTime = DateTime.now();

    setState(() {
      _isLoading = true;
      _scannedCode = code;
      _currentClient = null;
      _subResult = null;
    });

    Client? client = await _dbHelper.getClient(code);

    if (client != null) {

// ПРОВЕРКА НА АРХИВНОГО КЛИЕНТА
      if (!client.isActive) {
        setState(() {
          _currentClient = client;
          _subResult = SubscriptionResult(
            isActive: false, 
            reason: 'Клиент находится в архиве (удален)',
            isVip: false
          );
          _isLoading = false;
        });
        return; // Прерываем дальнейшую проверку абонемента
      }

      // Получаем все типы абонементов из БД
      List<SubscriptionType> types = await _dbHelper.getAllSubscriptionTypes();
      
      // Находим тип абонемента, который привязан к клиенту (по ID)
      // client.subType содержит ID (1, 2, 3...)
      SubscriptionType clientSubType = types.firstWhere(
        (t) => t.id == client.subType,
        orElse: () => types.first, // Запасной вариант, если тип не найден
      );

       // Вызываем проверку с тремя параметрами!
            final result = _subService.checkSubscription(client, clientSubType, DateTime.now());

      if (result.isActive) {
        // 1. Проверка на повторный вход (сравниваем только дату без времени)
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final isSecondVisit = client.lastVisit != null && client.lastVisit!.substring(0, 10) == today;

        // 2. Обновляем время посещения
        client.lastVisit = DateTime.now().toIso8601String();
        client.updatedAt = DateTime.now().toIso8601String();
        await _dbHelper.updateClient(client);

        // 3. Формируем текст (с предупреждением или без)
        final finalReason = isSecondVisit
            ? '${result.reason}\n\n⚠️ ВНИМАНИЕ: Повторное посещение сегодня!'
            : result.reason;

        // Перезаписываем результат с обновленной причиной
        _subResult = SubscriptionResult(isActive: result.isActive, reason: finalReason, isVip: result.isVip);
      } else {
        _subResult = result;
      }

      // Один setState для всех сценариев
      setState(() {
        _currentClient = client;
        _isLoading = false;
      });

    } else {
      setState(() {
        _currentClient = null;
        _subResult = null;
        _isLoading = false;
      });
      _showCreateDialog(code);
    }

    if (Platform.isWindows) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _hidFocusNode.requestFocus();
      });
    }
  }

  // Диалог создания нового клиента
  void _showCreateDialog(String code) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Клиент не найден'),
          content: Text('Клиента со штрихкодом $code нет в базе. Создать нового?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                // МГНОВЕННО закрываем диалог перед переходом!
                Navigator.pop(dialogContext);
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientFormScreen(initialBarcode: code),
                  ),
                );
                if (result == true) {
                  _processBarcode(code);
                }
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканер абонементов')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (Platform.isWindows) {
            _hidFocusNode.requestFocus();
          }
          // Скрываем клавиатуру при клике по пустому месту на Android
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView( // ДОБАВЛЕНА ПРОКРУТКА
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- БЛОК СКАНЕРА ---
                if (Platform.isWindows)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Поднесите карту к сканеру или введите номер',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 400,
                          child: TextField(
                            controller: _hidController,
                            focusNode: _hidFocusNode,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, letterSpacing: 2.0),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Штрихкод (EAN13)',
                              hintText: '0000000000000',
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) _processBarcode(value);
                              _hidController.clear();
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      if (_hasCameraPermission)
                    SizedBox(
                      height: 250,
                      child: MobileScanner(
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null && !_isLoading) {
                              _processBarcode(barcode.rawValue!);
                            }
                          }
                        },
                      ),
                    )
                  else
                    // ЕСТЬ НЕТ РАЗРЕШЕНИЯ - ПОКАЗЫВАЕМ КНОПКУ
                    SizedBox(
                      height: 250,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _checkCameraPermission,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Разрешить доступ к камере'),
                        ),
                      ),
                    ),
                      const SizedBox(height: 24),
                      const Text(
                        'Или введите номер карты вручную:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: TextField(
                          controller: _manualInputController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, letterSpacing: 1.5),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelText: 'Штрихкод (EAN13)',
                            hintText: '0000000000000',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.blue),
                              onPressed: () {
                                final code = _manualInputController.text.trim();
                                if (code.isNotEmpty) {
                                  _processBarcode(code);
                                  _manualInputController.clear();
                                }
                              },
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _processBarcode(value);
                              _manualInputController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // --- БЛОК РЕЗУЛЬТАТА ---
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: CircularProgressIndicator(),
                  )
                else if (_currentClient != null && _subResult != null)
                  _buildClientCard()
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: Text('Ожидание карты клиента', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // Виджет карточки клиента с результатом
  Widget _buildClientCard() {
    final client = _currentClient!;
    final result = _subResult!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.isActive ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isActive ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(client.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Тел: ${client.phone}', style: const TextStyle(fontSize: 16)),
          const Divider(height: 20),
          Text('Тип: ${_subTypes.firstWhere((t) => t.id == _currentClient!.subType, orElse: () => SubscriptionType(name: 'Удален', updatedAt: '')).name}${_currentClient!.subType != null && _subTypes.firstWhere((t) => t.id == _currentClient!.subType, orElse: () => SubscriptionType(name: '', updatedAt: '')).isVip ? " (VIP)" : ""}'),
          Text('Период: ${client.startDate} - ${client.endDate}'),
          Text('Последнее посещение: ${client.lastVisit != null ? client.lastVisit!.substring(0, 10) : "Нет данных"}'),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(8),
            color: result.isActive ? Colors.green : Colors.red,
            child: Text(
              'СТАТУС: ${result.isActive ? "АКТИВЕН" : "НЕ АКТИВЕН"}\n${result.reason}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

}