import 'package:flutter/material.dart';
import 'dart:io';
import '../services/db_config_service.dart';
import 'setup_own_db_guide_screen.dart';

class SetupScreen extends StatefulWidget {
  final DbConfigService dbConfigService;
  final Function(String url, String anonKey) onConfigComplete;

  const SetupScreen({
    super.key, 
    required this.dbConfigService, 
    required this.onConfigComplete,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _customUrlController = TextEditingController();
  final _customKeyController = TextEditingController();
  bool _showCustomFields = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Настройка базы данных',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Выберите, где будут храниться данные ваших клиентов.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  
                  // ВАРИАНТ 1: Основное облако
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: () async {
                      await widget.dbConfigService.setDefaultConfig();
                      widget.onConfigComplete(DbConfigService.defaultUrl, DbConfigService.defaultAnonKey);
                    },
                    icon: const Icon(Icons.cloud_outlined),
                    label: const Text('Основное облако (С авторизацией)', style: TextStyle(fontSize: 16)),
                  ),
                  
                  const SizedBox(height: 16),

                  // ВАРИАНТ 2: Локальная база
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () async {
                      await widget.dbConfigService.setLocalConfig();
                      widget.onConfigComplete('', ''); 
                    },
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Локальная база (Без интернета)', style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // ВАРИАНТ 3: Свое облако / Свой сервер
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    onPressed: () {
                      setState(() {
                        _showCustomFields = !_showCustomFields;
                      });
                    },
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Свое облако Supabase / Свой сервер', style: TextStyle(fontSize: 16)),
                  ),

                  if (_showCustomFields) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SetupOwnDbGuideScreen()));
                      },
                      label: const Text('Инструкция: Как создать базу или развернуть сервер', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    TextField(
                      controller: _customUrlController,
                      decoration: const InputDecoration(labelText: 'Supabase URL', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customKeyController,
                      decoration: const InputDecoration(labelText: 'Supabase Anon Key', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (_customUrlController.text.isEmpty || _customKeyController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните URL и Key')));
                          return;
                        }
                        await widget.dbConfigService.setCustomConfig(_customUrlController.text, _customKeyController.text);
                        
                        // Перезапуск для применения нового URL
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Настройки сохранены. Перезапустите приложение!')),
                          );
                          Future.delayed(const Duration(seconds: 1), () => exit(0));
                        }
                      },
                      child: const Text('Подключиться'),
                    )
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}