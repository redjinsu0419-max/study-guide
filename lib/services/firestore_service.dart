import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/solution_result.dart';
import 'app_exception.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> userReference(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) {
    return userReference(uid).snapshots().map(
          (document) =>
              document.exists ? AppUser.fromDocument(document) : null,
        );
  }

  Stream<List<AppUser>> watchApprovalRequests() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppUser.fromDocument).toList(growable: false),
        );
  }

  Future<void> setApproval({
    required AppUser user,
    required bool approved,
    required bool guardianConsentConfirmed,
  }) async {
    if (approved && !guardianConsentConfirmed) {
      throw const AppException('보호자 동의 확인 후 승인할 수 있습니다.');
    }

    if (approved && !user.approved) {
      final approvedSnapshot = await _firestore
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();
      final approvedStudentCount = approvedSnapshot.docs
          .where(
            (document) => !AppConfig.isAdminEmail(
              document.data()['email'] as String?,
            ),
          )
          .length;
      if (approvedStudentCount >= AppConfig.maxApprovedUsers) {
        throw AppException(
          '승인 가능한 ${AppConfig.maxApprovedUsers}명에 도달했습니다.',
        );
      }
    }

    await userReference(user.uid).update(
      <String, dynamic>{
        'approved': approved,
        'rejected': false,
        'guardianConsentConfirmed': guardianConsentConfirmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> reject(AppUser user) {
    return userReference(user.uid).update(
      <String, dynamic>{
        'approved': false,
        'rejected': true,
        'guardianConsentConfirmed': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<String> saveSolution({
    required String uid,
    required SolutionResult result,
  }) async {
    final reference =
        userReference(uid).collection('history').doc();
    await reference.set(
      result.toMap(createdAtValue: FieldValue.serverTimestamp()),
    );
    return reference.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistory(String uid) {
    return userReference(uid)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWrongNotes(String uid) {
    return userReference(uid)
        .collection('wrongNotes')
        .orderBy('notedAt', descending: true)
        .snapshots();
  }

  Future<void> setWrongNote({
    required String uid,
    required String historyId,
    required SolutionResult result,
    required bool value,
  }) async {
    final history = userReference(uid).collection('history').doc(historyId);
    final note = userReference(uid).collection('wrongNotes').doc(historyId);
    final batch = _firestore.batch();

    batch.update(history, <String, dynamic>{'isWrong': value});
    if (value) {
      final data = result.copyWith(isWrong: true).toMap();
      data['historyId'] = historyId;
      data['notedAt'] = FieldValue.serverTimestamp();
      batch.set(note, data);
    } else {
      batch.delete(note);
    }
    await batch.commit();
  }
}
