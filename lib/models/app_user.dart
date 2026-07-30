import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_selection.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.schoolLevel,
    required this.grade,
    required this.approved,
    required this.rejected,
    required this.guardianConsentRequested,
    required this.guardianConsentConfirmed,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final SchoolLevel schoolLevel;
  final int grade;
  final bool approved;
  final bool rejected;
  final bool guardianConsentRequested;
  final bool guardianConsentConfirmed;
  final DateTime? createdAt;

  factory AppUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    return AppUser(
      uid: document.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '학생',
      schoolLevel: schoolLevelFromStore(data['schoolLevel'] as String?),
      grade: (data['grade'] as num?)?.toInt() ?? 1,
      approved: data['approved'] as bool? ?? false,
      rejected: data['rejected'] as bool? ?? false,
      guardianConsentRequested:
          data['guardianConsentRequested'] as bool? ?? false,
      guardianConsentConfirmed:
          data['guardianConsentConfirmed'] as bool? ?? false,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
