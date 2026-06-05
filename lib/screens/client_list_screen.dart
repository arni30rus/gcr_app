import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/client.dart';
import '../models/subscription_type.dart';
import 'client_form_screen.dart';
import '../widgets/confirm_delete_dialog.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../utils/date_formatter.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  List<SubscriptionType> _subTypes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clients = await _dbHelper.getAllClients();
    final types = await _dbHelper.getAllSubscriptionTypes();
    setState(() {
      _subTypes = types;
      _allClients = clients;
      _applyFilter();
    });
  }

    void _applyFilter() {
    // Сначала фильтруем только АКТИВНЫХ клиентов
    List<Client> activeClients = _allClients.where((c) => c.isActive).toList();

    if (_searchQuery.isEmpty) {
      _filteredClients = activeClients;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredClients = activeClients.where((client) {
        return client.fullName.toLowerCase().contains(query) ||
               client.phone.contains(query) ||
               client.id.contains(query);
      }).toList();
    }
  }

  // Логика определения цвета карточки
  Color? _getCardColor(Client client) {
    // 1. Проверяем, истек ли срок (Красный приоритет)
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime endDate = DateTime.parse(client.endDate);
    if (today.isAfter(endDate)) {
      return Colors.red[100]; // Истекший абонемент
    }

    // 2. Проверяем VIP статус (Желтый)
    SubscriptionType? subType = _subTypes.firstWhere(
      (t) => t.id == client.subType,
            orElse: () => SubscriptionType(name: 'Неизвестно', updatedAt: DateTime.now().toIso8601String()),
    );
    if (subType.isVip) {
      return Colors.yellow[100]; // VIP клиент
    }

    return null; // Обычный клиент (белый)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список клиентов'),
        actions: [
          // КНОПКА ЭКСПОРТА В CSV
          IconButton(
            icon: const Icon(Icons.download), // Иконка скачивания
            onPressed: _exportToCSV,
            tooltip: 'Экспорт в Excel/CSV',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClientFormScreen()),
          );
          if (result == true) _loadData();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск по ФИО, телефону или штрихкоду',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilter();
                });
              },
            ),
          ),
          Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text('Клиенты не найдены'))
                : ListView.builder(
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      
                      // Находим имя типа абонемента
                      String typeName = _subTypes.firstWhere(
                        (t) => t.id == client.subType,
                           orElse: () => SubscriptionType(name: 'Удален', updatedAt: DateTime.now().toIso8601String()),
                      ).name;

                      return Card(
                        color: _getCardColor(client), // Применяем цвет
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Тел: ${client.phone}\nТип: $typeName | До: ${DateFormatter.format(client.endDate)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Посещение:', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  Text(DateFormatter.format(client.lastVisit)),
                                ],
                              ),
                              // Кнопка удаления
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => ConfirmDeleteDialog(itemName: client.fullName),
                                  );
                                  if (confirmed == true) {
                                  // МЯГКОЕ УДАЛЕНИЕ: меняем статус и дату обновления
                                    client.isActive = false;
                                    client.updatedAt = DateTime.now().toIso8601String();
                                   await _dbHelper.updateClient(client);
                                   _loadData();
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientFormScreen(client: client),
                              ),
                            );
                            if (result == true) _loadData();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

    Future<void> _exportToCSV() async {
    try {
      // 1. Берем только активных клиентов для экспорта
      List<Client> clientsToExport = _allClients.where((c) => c.isActive).toList();

      if (clientsToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет клиентов для экспорта')),
        );
        return;
      }

      // 2. Формируем строки таблицы
      List<List<dynamic>> rows = [];
      
      // Заголовки колонок
      rows.add(["Штрихкод", "ФИО", "Телефон", "Тип абонемента", "Начало", "Окончание", "Последнее посещение"]);
      
      // Данные клиентов
      for (var client in clientsToExport) {
        String typeName = _subTypes.firstWhere(
          (t) => t.id == client.subType,
          orElse: () => SubscriptionType(name: 'Удален', updatedAt: ''),
        ).name;
        
        rows.add([
          client.id,
          client.fullName,
          client.phone,
          typeName,
          DateFormatter.format(client.startDate), // Изменено
          DateFormatter.format(client.endDate),   // Изменено
          DateFormatter.format(client.lastVisit)
        ]);
      }

      // 3. Конвертируем в CSV (ИСПОЛЬЗУЕМ ТОЧКУ С ЗАПЯТОЙ ДЛЯ EXCEL)
      String csvData = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);

      // 4. Формируем байты с BOM (Маркер кодировки UTF-8)
      List<int> csvBytes = [0xEF, 0xBB, 0xBF]; // Сам BOM
      csvBytes.addAll(utf8.encode(csvData)); // Добавляем сами данные в UTF-8

      final now = DateTime.now();
      final filename = 'Clients_Export_${now.year}${now.month}${now.day}.csv';

      // 5. РАЗДЕЛЯЕМ ЛОГИКУ ДЛЯ WINDOWS И ANDROID
      if (Platform.isWindows) {
        // ДЛЯ WINDOWS: Стандартный диалог "Сохранить как..."
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить список клиентов',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputPath != null) {
          // Пользователь выбрал путь, сохраняем ФАЙЛ КАК БАЙТЫ
          final file = File(outputPath);
          await file.writeAsBytes(csvBytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Файл успешно сохранен: $outputPath')),
            );
          }
        }
      } else {
        // ДЛЯ ANDROID: Сохраняем во временный файл и вызываем меню "Поделиться"
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsBytes(csvBytes); // Тоже сохраняем как байты!

        // Вызываем системное меню "Поделиться/Сохранить"
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Список клиентов GCR APP',
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

}