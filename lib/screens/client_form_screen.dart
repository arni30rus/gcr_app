import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/client.dart';
import '../models/subscription_type.dart';
import '../services/sync_service.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  final String? initialBarcode;

  const ClientFormScreen({super.key, this.client, this.initialBarcode});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();
  bool _isSaving = false;

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late int? _selectedSubTypeId; // Теперь храним ID типа из БД
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  List<SubscriptionType> _subTypes = [];

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.client?.id ?? widget.initialBarcode ?? '');
    _nameController = TextEditingController(text: widget.client?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _selectedSubTypeId = widget.client?.subType; // subType теперь это ID
    String start = widget.client?.startDate ?? DateTime.now().toIso8601String().substring(0, 10);
    String end = widget.client?.endDate ?? DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
    _startDateController = TextEditingController(text: start);
    _endDateController = TextEditingController(text: end);

    _loadSubTypes();
  }

  Future<void> _loadSubTypes() async {
    final types = await dbHelper.getAllSubscriptionTypes();
    setState(() {
      _subTypes = types;
      // Если создаем нового клиента и типы есть, ставим первый по умолчанию
      if (widget.client == null && types.isNotEmpty && _selectedSubTypeId == null) {
        _selectedSubTypeId = types.first.id;
      }
    });
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate() && _selectedSubTypeId != null) {
      if (_isSaving) return; // Защита от двойного клика
      setState(() => _isSaving = true);

      try {
        final now = DateTime.now().toIso8601String();
        final syncService = SyncService();
        final gymId = await syncService.getCurrentUserGymId();

        final client = Client(
          id: _idController.text,
          fullName: _nameController.text,
          phone: _phoneController.text,
          subType: _selectedSubTypeId!,
          startDate: _startDateController.text,
          endDate: _endDateController.text,
          lastVisit: widget.client?.lastVisit,
          updatedAt: now,
          gymId: gymId,
        );

        if (widget.client == null) {
          await dbHelper.insertClient(client);
        } else {
          await dbHelper.updateClient(client);
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Ошибка сохранения клиента: $e')),
           );
         }
      } finally {
         if (mounted) {
           setState(() => _isSaving = false);
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Новый клиент' : 'Редактирование'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Штрихкод (EAN13)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                enabled: widget.client == null,
                validator: (value) => (value == null || value.length != 13) ? 'Введите 13 цифр' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ФИО', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Введите ФИО' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Динамический выпадающий список
              DropdownButtonFormField<int>(
                initialValue: _selectedSubTypeId,
                decoration: const InputDecoration(labelText: 'Тип абонемента', border: OutlineInputBorder()),
                items: _subTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type.id,
                    child: Text(type.name + (type.isVip ? " (VIP)" : "")),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSubTypeId = value),
                validator: (value) => value == null ? 'Выберите тип' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      decoration: const InputDecoration(labelText: 'Начало', border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () => _selectDate(_startDateController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      decoration: const InputDecoration(labelText: 'Окончание', border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () => _selectDate(_endDateController),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveClient,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Text('СОХРАНИТЬ', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}