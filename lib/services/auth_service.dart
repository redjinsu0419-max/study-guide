import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/school_selection.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<User> register({
    required String displayName,
    required String email,
    required String password,
    required SchoolLevel schoolLevel,
    required int grade,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: '회원 정보를 만들지 못했습니다.',
      );
    }

    try {
      await user.updateDisplayName(displayName.trim());
      await _firestore.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'uid': user.uid,
          'email': user.email ?? email.trim(),
          'displayName': displayName.trim(),
          'schoolLevel': schoolLevel.storeValue,
          'grade': grade,
          'role': 'student',
          'guardianConsentConfirmed': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      await user.delete();
      rethrow;
    }
    return user;
  }

  Future<void> signOut() => _auth.signOut();

  static String readableError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return '이메일 형식을 확인해 주세요.';
        case 'user-disabled':
          return '사용이 중지된 계정입니다.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다.';
        case 'weak-password':
          return '비밀번호는 6자 이상 입력해 주세요.';
        case 'too-many-requests':
          return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      }
      return error.message ?? '로그인 처리 중 오류가 발생했습니다.';
    }
    return error.toString();
  }
}
