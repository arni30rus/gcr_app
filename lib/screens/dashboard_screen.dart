import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/confirm_delete_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _typeStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _dbHelper.getStats();
    final typeStats = await _dbHelper.getTypeStats();
    setState(() {
      _stats = stats;
      _typeStats = typeStats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика зала'),
        actions: [
          // КНОПКА ОЧИСТКИ ИСТОРИИ ВИЗИТОВ
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Очистить историю посещений',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => ConfirmDeleteDialog(
                  itemName: 'всю историю посещений (локально). При работе через SUPABASE данные в облаке сохранятся',
                ),
              );
              if (confirmed == true) {
                final dbHelper = DatabaseHelper();
                await dbHelper.clearVisits();
                _loadStats(); // Обновляем цифры на экране
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadStats();
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // БЛОК 1: Общая статистика
                  GridView.count(
                    crossAxisCount: 2, 
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    physics: const NeverScrollableScrollPhysics(), // Чтобы скроллился общий ListView
                    shrinkWrap: true, // Чтобы GridView не занимал бесконечную высоту
                    children: [
                      _buildStatCard(title: 'Посещений сегодня', value: _stats['visitsToday'] ?? 0, icon: Icons.login, color: Colors.blue),
                      _buildStatCard(title: 'Активных абонементов', value: _stats['active'] ?? 0, icon: Icons.check_circle, color: Colors.green),
                      _buildStatCard(title: 'Новых за сегодня', value: _stats['newToday'] ?? 0, icon: Icons.person_add, color: Colors.purple),
                      _buildStatCard(title: 'Новых за неделю', value: _stats['newWeek'] ?? 0, icon: Icons.date_range, color: Colors.indigo),
                      _buildStatCard(title: 'Новых за месяц', value: _stats['newMonth'] ?? 0, icon: Icons.calendar_today, color: Colors.teal),
                      _buildStatCard(title: 'Истекает через 3 дня', value: _stats['expiring'] ?? 0, icon: Icons.warning, color: Colors.orange),
                      // Разовые посещения выделяем отдельно
                      _buildStatCard(title: 'Разовых сегодня', value: _stats['oneTimeToday'] ?? 0, icon: Icons.money, color: Colors.redAccent),
                      _buildStatCard(title: 'Разовых за месяц', value: _stats['oneTimeMonth'] ?? 0, icon: Icons.attach_money, color: Colors.pink),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // БЛОК 2: Динамические карточки по типам
                  const Text(
                    'Статистика по типам абонементов:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  _typeStats.isEmpty
                      ? const Center(child: Text('Нет данных по типам'))
                      : Column(
                          children: _typeStats.map((type) => _buildTypeCard(type)).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Динамическая карточка типа абонемента
  Widget _buildTypeCard(Map<String, dynamic> type) {
    final String name = type['name'];
    final int newToday = type['newToday'];
    final int newMonth = type['newMonth'];
    final bool isVip = type['isVip'];

    return Card(
      elevation: 2,
      color: isVip ? Colors.yellow[50] : null, // Подсветка VIP
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isVip ? '$name (VIP)' : name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                _buildMiniStat('Сегодня', newToday, Colors.blue),
                const SizedBox(width: 16),
                _buildMiniStat('Месяц', newMonth, Colors.teal),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Маленькая цифра для динамической карточки
  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}