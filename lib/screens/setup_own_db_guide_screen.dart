import 'package:flutter/material.dart';

class SetupOwnDbGuideScreen extends StatelessWidget {
  const SetupOwnDbGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Инструкция: Своя база')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Как подключить свою базу данных (Supabase)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Supabase — это бесплатное облако для баз данных. Вы создаете свой аккаунт, и данные ваших клиентов хранятся только у вас. Бесплатного тарифа более чем достаточно для спортзала.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            _buildStep(context, '1', 'Регистрация в Supabase'),
            const Text('Перейдите на сайт supabase.com и зарегистрируйтесь (можно через GitHub). Нажмите "New Project", придумайте пароль для базы, выберите ближайший регион и дождитесь создания проекта (около 2 минут).'),
            const SizedBox(height: 24),

            _buildStep(context, '2', 'Настройка авторизации'),
            const Text('В левом меню Supabase откройте Authentication -> Providers -> Email. Убедитесь, что тумблер "Enable Email signup" ВКЛЮЧЕН (это позволит вам создавать администраторов). Рекомендуем отключить "Confirm email" для упрощения входа.'),
            const SizedBox(height: 24),

            _buildStep(context, '3', 'Создание таблиц (Самое важное!)'),
            const Text('В левом меню откройте SQL Editor. Нажмите "+ New query". Скопируйте ВЕСЬ код ниже, вставьте в редактор и нажмите зеленую кнопку "Run":'),
            const SizedBox(height: 12),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[200],
              child: SelectableText(
                '''
-- 1. Таблица Залов
CREATE TABLE gyms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Таблица связи Пользователей и Залов
CREATE TABLE user_gyms (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  gym_id UUID REFERENCES gyms(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'admin',
  PRIMARY KEY (user_id, gym_id)
);

-- 3. Таблица Типов абонементов
CREATE TABLE subscription_types (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  is_unlimited_time INTEGER NOT NULL,
  allowed_days TEXT NOT NULL,
  is_vip INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  gym_id UUID REFERENCES gyms(id),
  is_active BOOLEAN DEFAULT true,
  is_one_time_visit BOOLEAN DEFAULT false
);

-- 4. Таблица Клиентов (ОБНОВЛЕНО: добавлено created_at)
CREATE TABLE clients (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  sub_type INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  last_visit TEXT,
  updated_at TEXT NOT NULL,
  gym_id UUID REFERENCES gyms(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Таблица истории посещений
CREATE TABLE visits (
  id BIGSERIAL PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  gym_id UUID REFERENCES gyms(id)
);

-- 6. Таблица истории продлений (НОВАЯ)
CREATE TABLE renewals (
  id BIGSERIAL PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  gym_id UUID REFERENCES gyms(id)
);

-- 7. Включаем безопасность (RLS)
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE renewals ENABLE ROW LEVEL SECURITY;

-- 8. Правила доступа (Пользователь видит только свой зал)
CREATE POLICY "Users can view their gyms" ON gyms FOR SELECT USING (id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can view their gym links" ON user_gyms FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can manage sub types in their gym" ON subscription_types FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage clients in their gym" ON clients FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage visits in their gym" ON visits FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage renewals in their gym" ON renewals FOR ALL USING (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid())) WITH CHECK (gym_id IN (SELECT gym_id FROM user_gyms WHERE user_id = auth.uid()));
''',
                style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 24),

            _buildStep(context, '4', 'Создание администратора'),
            const Text('1. В Supabase откройте Authentication -> Users -> Add User -> Create new user. Введите Email и Пароль. Скопируйте сгенерированный ID пользователя (UUID).'),
            const Text('2. В Supabase откройте Table Editor -> gyms -> Insert row. Придумайте название зала (например, "Мой зал"). Поле id ОСТАВЬТЕ ПУСТЫМ! Скопируйте сгенерированный id зала.'),
            const Text('3. В Supabase откройте Table Editor -> user_gyms -> Insert row. Вставьте ID пользователя и ID зала. Сохраните.'),
            const SizedBox(height: 24),

            _buildStep(context, '5', 'Получение ключей'),
            const Text('В Supabase откройте Settings (шестеренка) -> API. Скопируйте два значения:'),
            const SizedBox(height: 8),
            const Text('• Project URL (выглядит как https://xxxxx.supabase.co)'),
            const Text('• anon public key (очень длинная строка, начинается на eyJ...)'),
            const SizedBox(height: 24),

            _buildStep(context, '6', 'Подключение в приложении'),
            const Text('Вернитесь в приложение. На экране выбора базы нажмите "Использовать свою базу Supabase". Вставьте скопированные URL и Key. Нажмите "Подключиться". Введите Email и Пароль, которые вы создали в Шаге 4. Готово!'),
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