import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AppUser?> get userStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromMap(user.uid, doc.data()!);
      }
      return AppUser(uid: user.uid, name: '학생', email: '');
    });
  }

  Future<void> signInWithName(String name) async {
    final userCredential = await _auth.signInAnonymously();
    final uid = userCredential.user!.uid;

    await _db.collection('users').doc(uid).set({
      'name': name.trim().isEmpty ? '학생' : name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
