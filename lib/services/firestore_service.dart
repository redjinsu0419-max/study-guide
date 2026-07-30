import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/solution_result.dart';

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

  Future<String> saveSolution({
    required String uid,
    required SolutionResult result,
  }) async {
    final reference = userReference(uid).collection('history').doc();
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
