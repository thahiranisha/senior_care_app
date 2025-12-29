enum CaregiverStatus {
  draft,
  pendingVerification,
  verified,
  rejected,
  blocked,
}

CaregiverStatus caregiverStatusFromDoc(Map<String, dynamic> data) {
  final raw = (data['status'] as String?)?.toUpperCase().trim();

  if (raw == 'DRAFT') return CaregiverStatus.draft;

  // New statuses
  if (raw == 'PENDING_VERIFICATION') return CaregiverStatus.pendingVerification;
  if (raw == 'VERIFIED') return CaregiverStatus.verified;
  if (raw == 'REJECTED') return CaregiverStatus.rejected;
  if (raw == 'BLOCKED') return CaregiverStatus.blocked;

  // Legacy compatibility
  if (raw == 'APPROVED') return CaregiverStatus.verified;
  if (raw == 'PENDING') return CaregiverStatus.pendingVerification;

  // If status missing but profileSubmitted exists
  final submitted = (data['submittedAt'] != null) || (data['profileSubmitted'] == true);
  if (submitted) return CaregiverStatus.pendingVerification;

  final isVerified = (data['isVerified'] as bool?) ?? false;
  if (isVerified) return CaregiverStatus.verified;

  return CaregiverStatus.draft;
}

String caregiverStatusToString(CaregiverStatus status) {
  switch (status) {
    case CaregiverStatus.draft:
      return 'DRAFT';
    case CaregiverStatus.pendingVerification:
      return 'PENDING_VERIFICATION';
    case CaregiverStatus.verified:
      return 'VERIFIED';
    case CaregiverStatus.rejected:
      return 'REJECTED';
    case CaregiverStatus.blocked:
      return 'BLOCKED';
  }
}

bool caregiverIsVerified(CaregiverStatus status) => status == CaregiverStatus.verified;
