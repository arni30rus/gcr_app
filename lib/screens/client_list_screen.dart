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
  
  // ОПТИМИЗАЦИЯ: Используем Map вместо List для типов абонементов
  // Поиск в Map происходит мгновенно (O(1)), в отличие от firstWhere (O(N))
  Map<int, SubscriptionType> _subTypesMap = {}; 
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clients = await _dbHelper.getAllClients();
    final types = await _dbHelper.getAllSubscriptionTypes();
    
    // Преобразуем список типов в словарь (Map), где ключ - это ID типа
    final typesMap = {for (var t in types) t.id!: t};

    setState(() {
      _subTypesMap = typesMap;
      _allClients = clients;
      _applyFilter();
    });
  }

  void _applyFilter() {
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

  Color? _getCardColor(Client client) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime endDate = DateTime.parse(client.endDate);
    if (today.isAfter(endDate)) {
      return Colors.red[100]; 
    }

    // ОПТИМИЗАЦИЯ: Берем тип из Map мгновенно
    final subType = _subTypesMap[client.subType];
    if (subType != null && subType.isVip) {
      return Colors.yellow[100]; 
    }

    return null; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список клиентов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
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
                    // ОПТИМИЗАЦИЯ: Фиксированная высота элемента. 
                    // ListView не будет тратить ресурсы на вычисление высоты каждой карточки!
                    // Если текст обрезается, увеличь это значение (например, до 95.0)
                    itemExtent: 80.0, 
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      
                      // ОПТИМИЗАЦИЯ: Мгновенный поиск имени типа в Map
                      String typeName = _subTypesMap[client.subType]?.name ?? 'Удален';

                      // Вычисляем цвет один раз
                      final cardColor = _getCardColor(client);
                      // Вычисляем размер шрифта для номера
                      final int clientIndex = index + 1;
                      final double fontSize = clientIndex > 9999 ? 9.0 : (clientIndex > 999 ? 10.5 : 14.0);

                        return Card(
                        elevation: 3,
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        // ДОБАВЛЯЕМ INKWELL ДЛЯ ОБРАБОТКИ НАЖАТИЙ НА ВСЮ КАРТОЧКУ
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientFormScreen(client: client),
                              ),
                            );
                            if (result == true) _loadData();
                          },
                          borderRadius: BorderRadius.circular(12), // Скругление эффекта волны
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                // 1. Квадрат с номером
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$clientIndex', 
                                    style: TextStyle(
                                      color: Colors.blue, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: fontSize,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16), 
                                
                                // 2. Блок с ФИО и деталями
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.fullName, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0), 
                                        maxLines: 2, 
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Тел: ${client.phone}\nТип: $typeName | До: ${DateFormatter.format(client.endDate)}',
                                        maxLines: 2, 
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.0),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 3. Блок справа (посещение и удаление)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Посещение:', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                        Text(DateFormatter.format(client.lastVisit), style: const TextStyle(fontSize: 12.0)),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => ConfirmDeleteDialog(itemName: client.fullName),
                                        );
                                        if (confirmed == true) {
                                          client.isActive = false;
                                          client.updatedAt = DateTime.now().toIso8601String();
                                          await _dbHelper.updateClient(client);
                                          _loadData();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
      List<Client> clientsToExport = _allClients.where((c) => c.isActive).toList();

      if (clientsToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет клиентов для экспорта')),
        );
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(["Штрихкод", "ФИО", "Телефон", "Тип абонемента", "Начало", "Окончание", "Последнее посещение"]);
      
      for (var client in clientsToExport) {
        // ОПТИМИЗАЦИЯ: тоже используем Map здесь
        String typeName = _subTypesMap[client.subType]?.name ?? 'Удален';
        
        rows.add([
          client.id,
          client.fullName,
          client.phone,
          typeName,
          DateFormatter.format(client.startDate),
          DateFormatter.format(client.endDate),   
          DateFormatter.format(client.lastVisit)
        ]);
      }

      String csvData = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);

      List<int> csvBytes = [0xEF, 0xBB, 0xBF]; 
      csvBytes.addAll(utf8.encode(csvData)); 

      final now = DateTime.now();
      final filename = 'Clients_Export_${now.year}${now.month}${now.day}.csv';

      if (Platform.isWindows) {
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить список клиентов',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(csvBytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Файл успешно сохранен: $outputPath')),
            );
          }
        }
      } else {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsBytes(csvBytes); 

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