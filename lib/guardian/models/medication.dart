import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String name;
  final String? dosage;
  final String? route;
  final List<String> times; // ["08:00","20:00"]
  final String? instructions;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.route,
    required this.times,
    this.instructions,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore({required String actorUid}) {
    return {
      'name': name,
      'dosage': dosage,
      'route': route,
      'times': times,
      'instructions': instructions,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'isActive': isActive,
      'updatedBy': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Medication fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? dt(dynamic v) => v is Timestamp ? v.toDate() : null;

    return Medication(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      dosage: data['dosage'] as String?,
      route: data['route'] as String?,
      times: ((data['times'] ?? []) as List).map((e) => e.toString()).toList(),
      instructions: data['instructions'] as String?,
      startDate: dt(data['startDate']),
      endDate: dt(data['endDate']),
      isActive: (data['isActive'] as bool?) ?? true,
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      createdAt: dt(data['createdAt']),
      updatedAt: dt(data['updatedAt']),
    );
  }
}
