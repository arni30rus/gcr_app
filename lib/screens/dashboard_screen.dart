import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _dbHelper.getStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика зала')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadStats();
              },
              child: GridView.count(
                padding: const EdgeInsets.all(12),
                crossAxisCount: 2, // 2 колонки
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    title: 'Посещений сегодня',
                    value: _stats['visitsToday'] ?? 0,
                    icon: Icons.login,
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    title: 'Активных абонементов',
                    value: _stats['active'] ?? 0,
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    title: 'Новых за сегодня',
                    value: _stats['newToday'] ?? 0,
                    icon: Icons.person_add,
                    color: Colors.purple,
                  ),
                  _buildStatCard(
                    title: 'Новых за неделю',
                    value: _stats['newWeek'] ?? 0,
                    icon: Icons.date_range,
                    color: Colors.indigo,
                  ),
                  _buildStatCard(
                    title: 'Новых за месяц',
                    value: _stats['newMonth'] ?? 0,
                    icon: Icons.calendar_today,
                    color: Colors.teal,
                  ),
                  _buildStatCard(
                    title: 'Истекает через 3 дня',
                    value: _stats['expiring'] ?? 0,
                    icon: Icons.warning,
                    color: Colors.orange,
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0), // Уменьшили боковые отступы
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color), // Уменьшили иконку до 28
            const SizedBox(height: 6), // Уменьшили промежуток
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 26, // Уменьшили цифры до 26
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4), // Уменьшили промежуток
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12, // Уменьшили текст до 12
                color: Colors.grey,
                height: 1.2, // ДОБАВЛЕНО: Сжимает межстрочный интервал, если текст в 2 строки
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}