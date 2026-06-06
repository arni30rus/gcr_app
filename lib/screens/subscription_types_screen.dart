import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/subscription_type.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../services/sync_service.dart';

class SubscriptionTypesScreen extends StatefulWidget {
  const SubscriptionTypesScreen({super.key});

  @override
  State<SubscriptionTypesScreen> createState() => _SubscriptionTypesScreenState();
}

class _SubscriptionTypesScreenState extends State<SubscriptionTypesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<SubscriptionType> _types = [];

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

 Future<void> _loadTypes() async {
    final types = await _dbHelper.getAllSubscriptionTypes();
    setState(() {
      // ПОКАЗЫВАЕМ ТОЛЬКО АКТИВНЫЕ ТИПЫ (isActive == true)
      _types = types.where((t) => t.isActive).toList();
    });
  }

   void _showForm(SubscriptionType? type) {
    final nameController = TextEditingController(text: type?.name ?? '');
    final startController = TextEditingController(text: type?.startTime ?? '08:00');
    final endController = TextEditingController(text: type?.endTime ?? '16:00');
    bool isUnlimited = type?.isUnlimitedTime ?? false;
    String allowedDays = type?.allowedDays ?? '';
    bool isVip = type?.isVip ?? false;
    bool isSaving = false; // Переменная для блокировки кнопки
     bool isOneTimeVisit = type?.isOneTimeVisit ?? false; 

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(type == null ? 'Новый тип абонемента' : 'Редактирование'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название (например: Дневной)')),
                    SwitchListTile(
                      title: const Text('Безлимит по времени'), 
                      value: isUnlimited, 
                      onChanged: (v) => setStateDialog(() => isUnlimited = v),
                    ),
                    if (!isUnlimited) ...[
                      TextField(controller: startController, decoration: const InputDecoration(labelText: 'Начало (HH:mm)')),
                      TextField(controller: endController, decoration: const InputDecoration(labelText: 'Конец (HH:mm)')),
                    ],
                    const Divider(),
                    const Text('Дни недели (1-Пн, 2-Вт... 7-Вс). Оставьте пустым для всех дней:'),
                    TextField(
                      controller: TextEditingController(text: allowedDays),
                      onChanged: (v) => allowedDays = v,
                      decoration: const InputDecoration(hintText: 'Например: 1,5,6,7'),
                    ),
                    SwitchListTile(
                      title: const Text('VIP Абонемент'), 
                      value: isVip, 
                      onChanged: (v) => setStateDialog(() => isVip = v),
                    ),
                     SwitchListTile(
                      title: const Text('Разовое посещение'), 
                      subtitle: const Text('Не учитывается в статистике абонементов'),
                      value: isOneTimeVisit, 
                      onChanged: (v) => setStateDialog(() => isOneTimeVisit = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext), 
                  child: const Text('Отмена')
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async { // Блокируем кнопку, если уже сохраняем
                    if (isSaving) return;
                    
                    setStateDialog(() => isSaving = true); // Включаем загрузку

                    try {
                      final syncService = SyncService();
                      final gymId = await syncService.getCurrentUserGymId();

                      final newType = SubscriptionType(
                        id: type?.id,
                        name: nameController.text,
                        startTime: startController.text,
                        endTime: endController.text,
                        isUnlimitedTime: isUnlimited,
                        allowedDays: allowedDays,
                        isVip: isVip,
                        isOneTimeVisit: isOneTimeVisit,
                        updatedAt: DateTime.now().toIso8601String(),
                        gymId: gymId,
                      );
                      
                      if (type == null) {
                        await _dbHelper.insertSubscriptionType(newType);
                      } else {
                        await _dbHelper.updateSubscriptionType(newType);
                      }
                      
                      // Проверяем, не закрыт ли уже диалог, перед тем как его закрыть
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      _loadTypes(); // Обновляем список на экране
                      
                    } catch (e) {
                      // Если ошибка — показываем снэкбар и разблокируем кнопку
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка сохранения: $e')),
                      );
                      setStateDialog(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'), // Показываем колесо загрузки вместо текста
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
      appBar: AppBar(title: const Text('Типы абонементов')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _types.length,
        itemBuilder: (context, index) {
          final type = _types[index];
          String daysText = type.allowedDays.isEmpty ? 'Все дни' : 'Дни: ${type.allowedDays}';
          String timeText = type.isUnlimitedTime ? 'Безлимит по времени' : '${type.startTime} - ${type.endTime}';
          
          return Card(
            color: type.isVip ? Colors.yellow[100] : null, // Подсветка VIP
            child: ListTile(
              title: Text('${type.name} ${type.isVip ? "(VIP)" : ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$timeText | $daysText'),
                            trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => ConfirmDeleteDialog(itemName: type.name),
                  );
                  if (confirmed == true) {
                   // МЯГКОЕ УДАЛЕНИЕ ТИПА АБОНЕМЕНТА
                    type.isActive = false;
                    type.updatedAt = DateTime.now().toIso8601String();
                    await _dbHelper.updateSubscriptionType(type);
                    _loadTypes(); // Метод обновления списка типов
                  }
                },
              ),
              onTap: () => _showForm(type),
            ),
          );
        },
      ),
    );
  }
}