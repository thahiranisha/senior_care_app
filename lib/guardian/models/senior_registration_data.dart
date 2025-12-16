import 'package:cloud_firestore/cloud_firestore.dart';

class SeniorRegistrationData {
  final String fullName;
  final DateTime dob;

  final String? gender;
  final String? phone;
  final String? address;

  final String? emergencyContactName;
  final String? emergencyContactPhone;

  final String? medicalConditions;
  final String? allergies;
  final String? currentMedications;

  final String mobilityLevel;
  final String? notes;

  const SeniorRegistrationData({
    required this.fullName,
    required this.dob,
    this.gender,
    this.phone,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalConditions,
    this.allergies,
    this.currentMedications,
    required this.mobilityLevel,
    this.notes,
  });

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName,
    'dob': Timestamp.fromDate(dob),
    'gender': gender,
    'phone': phone,
    'address': address,
    'emergencyContactName': emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
    'medicalConditions': medicalConditions,
    'allergies': allergies,
    'currentMedications': currentMedications,
    'mobilityLevel': mobilityLevel,
    'notes': notes,
  };
}
