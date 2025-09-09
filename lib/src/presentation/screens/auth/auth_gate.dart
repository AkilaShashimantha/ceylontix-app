import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/repositories/auth_repository.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Instantiate the repository to access the auth state stream.
    final authRepository = FirebaseAuthRepository();

    return StreamBuilder<User?>(
      // Listen to our repository's auth state stream, not directly to Firebase.
      // This maintains the separation of concerns.
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        // Show a loading indicator while connecting to the stream
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If the snapshot has data (a User object), the user is logged in.
        if (snapshot.hasData) {
          // Navigate to the admin dashboard.
          return const AdminDashboardScreen();
        } else {
          // If there's no data, the user is logged out.
          // Navigate to the login screen.
          return const AdminLoginScreen();
        }
      },
    );
  }
}
