import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';

// This is the concrete implementation of the AuthRepository using Firebase.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') throw Exception('No user found for that email.');
      if (e.code == 'wrong-password') throw Exception('Wrong password provided for that user.');
      throw Exception('An error occurred during sign-in. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  @override
  Future<UserCredential> signUpWithEmailAndPassword({required String email, required String password}) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw Exception('The password provided is too weak.');
      if (e.code == 'email-already-in-use') throw Exception('An account already exists for that email.');
      throw Exception('An error occurred during sign-up. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(provider);
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In aborted by user.');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('An error occurred during Google Sign-In. Please try again.');
    }
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final isSignedInWithGoogle = await _googleSignIn.isSignedIn();
        if (isSignedInWithGoogle) {
          // Disconnect to revoke previous consent and ensure full sign-out
          try {
            await _googleSignIn.disconnect();
          } catch (_) {
            // Fallback to signOut if disconnect is not available/supported
            await _googleSignIn.signOut();
          }
        }
      }
      await _firebaseAuth.signOut();
    } catch (_) {
      // Swallow to avoid crashing callers; authStateChanges stream will reflect state
    }
  }
}
