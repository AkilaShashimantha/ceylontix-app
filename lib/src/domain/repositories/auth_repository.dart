import 'package:firebase_auth/firebase_auth.dart';

// The contract for our authentication service.
abstract class AuthRepository {
  // For Admin login
  Future<void> signInWithEmailAndPassword({required String email, required String password});

  // **NEW**: For user sign-up
  Future<UserCredential> signUpWithEmailAndPassword({required String email, required String password});
  
  // **NEW**: For Google Sign-In
  Future<UserCredential> signInWithGoogle();

  // For both admin and users
  Stream<User?> get authStateChanges;
  Future<void> signOut();
}


