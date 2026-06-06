import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Иконка приложения
              Icon(
                Icons.fitness_center,
                size: 80,
                color: Colors.blue,
              ),
              SizedBox(height: 24),
                            
              // Название
              Text(
                'GCR - GYM Client Registration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              
              // Версия и дата
              Text(
                'Версия: 1.0.2',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              Text(
                '© 2026 г. - arni30rus',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 40),
              
              Divider(),
              SizedBox(height: 20),
              
              // Контакты
              Text(
                'Поддержка:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              // Заменили ListTile на Row для выравнивания по центру
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('E-mail: xokcod4@gmail.com'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Telegram: @arni30rus'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}