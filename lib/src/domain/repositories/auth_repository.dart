// This is the contract that any authentication repository must follow.
// It decouples our application logic from the specific implementation (like Firebase).

import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Stream<User?> get authStateChanges;

  Future<void> signOut();
}
