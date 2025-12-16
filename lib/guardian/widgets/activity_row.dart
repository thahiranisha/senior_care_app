import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] as String?) ?? 'INFO';
    final desc = (data['description'] as String?) ?? '';
    final ts = data['time'] as Timestamp?;
    final time = ts?.toDate();
    final timeText = time == null ? '-' : TimeOfDay.fromDateTime(time).format(context);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.chevron_right),
      title: Text(desc),
      subtitle: Text('$type • $timeText'),
    );
  }
}
