import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SetupOwnDbGuideScreen extends StatelessWidget {
  const SetupOwnDbGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Инструкция: Supabase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Как подключить свою базу данных',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supabase — это бесплатное облако (или сервер) для баз данных. Вы можете использовать облачный сервис или развернуть его на своем сервере (Ubuntu). Данных бесплатного тарифа более чем достаточно для спортзала.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // ВАРИАНТ 1: ОБЛАКО
            // ==========================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: const Text('ВАРИАНТ 1: Облако Supabase.com (Быстро)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            const SizedBox(height: 12),
            
            _buildStep(context, '1', 'Регистрация'),
            const Text('Перейдите на supabase.com и зарегистрируйтесь. Нажмите "New Project", выберите регион и дождитесь создания (2 минуты).'),
            const SizedBox(height: 16),

            _buildStep(context, '2', 'Настройка авторизации'),
            const Text('В панели Supabase откройте Authentication -> Providers -> Email. Включите "Enable Email signup". Рекомендуем отключить "Confirm email".'),
            const SizedBox(height: 24),

            // ==========================================
            // ВАРИАНТ 2: СВОЙ СЕРВЕР
            // ==========================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.deepPurple[50], borderRadius: BorderRadius.circular(8)),
              child: const Text('ВАРИАНТ 2: Свой сервер Ubuntu (Полный контроль)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ),
            const SizedBox(height: 12),
            
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Официальная инструкция Supabase (Docker)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12)
                ),
                onPressed: () async {
                  final uri = Uri.parse('https://supabase.com/docs/guides/self-hosting/docker#quick-start-linux');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            _buildStep(context, '1', 'Подготовка сервера'),
            const Text('Установите Docker и Git на ваш сервер Ubuntu. Затем выполните команды в терминале по очереди:'),
            Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.grey[200], child: const SelectableText(
              'git clone --depth 1 https://github.com/supabase/supabase\n'
              'mkdir supabase-project\n'
              'cp -rf supabase/docker/* supabase-project\n'
              'cp supabase/docker/.env.example supabase-project/.env\n'
              'cd supabase-project', 
              style: TextStyle(fontFamily: 'Courier', fontSize: 12)
            )),
            const SizedBox(height: 16),

            _buildStep(context, '2', 'Генерация ключей и запуск'),
            const Text('Выполните скрипты для генерации безопасных ключей и запуска сервера:'),
            Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.grey[200], child: const SelectableText(
              'sh utils/generate-keys.sh\n'
              'sh utils/add-new-auth-keys.sh\n'
              'sh run.sh start', 
              style: TextStyle(fontFamily: 'Courier', fontSize: 12)
            )),
            const SizedBox(height: 8),
            const Text('Остановить сервер можно командой: sh run.sh stop', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 24),

            // ОПТИМИЗАЦИЯ
            _buildStep(context, '3', 'Оптимизация (Защита от Bloat)'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Важно!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  SizedBox(height: 4),
                  Text('По умолчанию Supabase запускает сервисы логирования и аналитики, которые могут «раздуть» базу до десятков ГБ. Для работы данного приложения они не нужны.'),
                  SizedBox(height: 8),
                  Text('1. Откройте файл docker-compose.yml (например, через nano docker-compose.yml).'),
                  Text('2. Найдите и закомментируйте (поставьте # в начале строк) блоки сервисов:'),
                  Text('   - analytics (и все связанные с ним volumes)', style: TextStyle(fontFamily: 'Courier', fontSize: 12)),
                  Text('   - logflare', style: TextStyle(fontFamily: 'Courier', fontSize: 12)),
                  Text('   - realtime', style: TextStyle(fontFamily: 'Courier', fontSize: 12)),
                  Text('3. Сохраните файл и перезапустите сервер: sh run.sh stop && sh run.sh start'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildStep(context, '4', 'Порты и доступ'),
            const Text('Убедитесь, что в брандмауэре Ubuntu открыты порты 8000 и 3000.', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Панель управления будет доступна по http://ВАШ_IP:8000'),
            const SizedBox(height: 12),

            const Divider(height: 30),

            // ==========================================
            // ОБЩИЕ ШАГИ ДЛЯ ОБОИХ ВАРИАНТОВ
            // ==========================================
            const Text('ОБЩИЕ ШАГИ (Для облака и своего сервера):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _buildStep(context, '5', 'Создание таблиц (SQL)'),
            const Text('В панели Supabase откройте SQL Editor. Скопируйте ВЕСЬ код ниже и нажмите "Run":'),
            const SizedBox(height: 12),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[200],
              child: SelectableText(
                '''
-- 1. Таблица Залов
CREATE TABLE gyms ( id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW() );

-- 2. Таблица связи Пользователей и Залов
CREATE TABLE user_gyms ( user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, gym_id UUID REFERENCES gyms(id) ON DELETE CASCADE, role TEXT DEFAULT 'admin', PRIMARY KEY (user_id, gym_id) );

-- 3. Таблица Типов абонементов
CREATE TABLE subscription_types ( id INTEGER PRIMARY KEY, name TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL, is_unlimited_time INTEGER NOT NULL, allowed_days TEXT NOT NULL, is_vip INTEGER NOT NULL, updated_at TEXT NOT NULL, gym_id UUID REFERENCES gyms(id), is_active BOOLEAN DEFAULT true, is_one_time_visit BOOLEAN DEFAULT false );

-- 4. Таблица Клиентов
CREATE TABLE clients ( id TEXT PRIMARY KEY, full_name TEXT NOT NULL, phone TEXT NOT NULL, sub_type INTEGER NOT NULL, start_date TEXT NOT NULL, end_date TEXT NOT NULL, last_visit TEXT, updated_at TEXT NOT NULL, gym_id UUID REFERENCES gyms(id), is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW(), telegram_id TEXT );

-- 5. Таблица посещений
CREATE TABLE visits ( id BIGSERIAL PRIMARY KEY, client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), gym_id UUID REFERENCES gyms(id) );

-- 6. Таблица продлений
CREATE TABLE renewals ( id BIGSERIAL PRIMARY KEY, client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), gym_id UUID REFERENCES gyms(id) );

-- 7. Безопасность (RLS)
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE renewals ENABLE ROW LEVEL SECURITY;

-- 8. Правила доступа
CREATE POLICY "Users can view their gyms" ON gyms FOR SELECT USING (id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can view their gym links" ON user_gyms FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can manage sub types in their gym" ON subscription_types FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage clients in their gym" ON clients FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage visits in their gym" ON visits FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage renewals in their gym" ON renewals FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
''',
                style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 24),

            _buildStep(context, '6', 'Создание администратора зала'),
            const Text('1. Authentication -> Users -> Add User. Скопируйте ID пользователя (UUID).\n2. Table Editor -> gyms -> Insert row. Придумайте название. Скопируйте id зала.\n3. Table Editor -> user_gyms -> Insert row. Вставьте ID пользователя и ID зала.'),
            const SizedBox(height: 24),

            _buildStep(context, '7', 'Подключение в приложении'),
            const Text('Вернитесь в приложение. Вставьте URL и Key.\n(Для облака: Settings -> API)\n(Для сервера: http://ВАШ_IP:8000 и ANON_KEY из файла .env).\nНажмите "Подключиться" и перезапустите приложение.'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blue,
          child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}