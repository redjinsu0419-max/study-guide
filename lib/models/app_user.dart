import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_selection.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.schoolLevel,
    required this.grade,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final SchoolLevel schoolLevel;
  final int grade;
  final DateTime? createdAt;

  factory AppUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    return AppUser(
      uid: document.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      schoolLevel: schoolLevelFromStore(data['schoolLevel'] as String?),
      grade: (data['grade'] as num?)?.toInt() ?? 1,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
