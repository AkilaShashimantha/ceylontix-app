import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/auth_repository.dart';

// This is the concrete implementation of the AuthRepository using Firebase.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  // Constructor requires an instance of FirebaseAuth.
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Use the Firebase SDK to sign in with the provided credentials.
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Catch specific Firebase exceptions and re-throw them as more general exceptions
      // or handle them as needed. This helps in displaying user-friendly error messages.
      if (e.code == 'user-not-found') {
        throw Exception('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Wrong password provided for that user.');
      } else {
        throw Exception('An error occurred during sign-in. Please try again.');
      }
    } catch (e) {
      // Catch any other generic errors.
      throw Exception('An unexpected error occurred.');
    }
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      // It's rare for signOut to fail, but we can handle it if needed.
      throw Exception('An error occurred during sign-out.');
    }
  }
}

