import 'package:flutter/material.dart';

class ConfirmDeleteDialog extends StatefulWidget {
  final String itemName;

  const ConfirmDeleteDialog({super.key, required this.itemName});

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog> {
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Подтверждение удаления'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Вы уверены, что хотите удалить «${widget.itemName}»?'),
          const SizedBox(height: 16),
          const Text(
            'Это действие нельзя будет отменить.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Я понимаю и подтверждаю удаление'),
            value: _isConfirmed,
            onChanged: (bool? value) {
              setState(() {
                _isConfirmed = value ?? false;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Нет'),
        ),
        ElevatedButton(
          onPressed: _isConfirmed ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Да, удалить'),
        ),
      ],
    );
  }
}