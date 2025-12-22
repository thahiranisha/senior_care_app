enum CaregiverStatus {
  pendingVerification,
  verified,
  blocked,
}

CaregiverStatus caregiverStatusFromDoc(Map<String, dynamic> data) {
  final raw = (data['status'] as String?)?.toUpperCase().trim();

  // New statuses
  if (raw == 'PENDING_VERIFICATION') return CaregiverStatus.pendingVerification;
  if (raw == 'VERIFIED') return CaregiverStatus.verified;
  if (raw == 'BLOCKED') return CaregiverStatus.blocked;

  // Legacy compatibility
  if (raw == 'APPROVED') return CaregiverStatus.verified;
  if (raw == 'PENDING') return CaregiverStatus.pendingVerification;

  final isVerified = (data['isVerified'] as bool?) ?? false;
  if (isVerified) return CaregiverStatus.verified;

  return CaregiverStatus.pendingVerification;
}

String caregiverStatusToString(CaregiverStatus status) {
  switch (status) {
    case CaregiverStatus.pendingVerification:
      return 'PENDING_VERIFICATION';
    case CaregiverStatus.verified:
      return 'VERIFIED';
    case CaregiverStatus.blocked:
      return 'BLOCKED';
  }
}

bool caregiverIsVerified(CaregiverStatus status) => status == CaregiverStatus.verified;
