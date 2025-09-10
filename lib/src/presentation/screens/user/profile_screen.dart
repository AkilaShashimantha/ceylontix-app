    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:flutter/material.dart';
    import '../../../data/repositories/auth_repository.dart';
    import 'login_or_register_screen.dart';

    class ProfileScreen extends StatelessWidget {
      const ProfileScreen({Key? key}) : super(key: key);

      @override
      Widget build(BuildContext context) {
        final authRepository = FirebaseAuthRepository();

        return StreamBuilder<User?>(
          stream: authRepository.authStateChanges,
          builder: (context, snapshot) {
            // If user is not logged in, show the login/register screen
            if (!snapshot.hasData || snapshot.data == null) {
              return const LoginOrRegisterScreen();
            }

            // If user is logged in, show their profile
            final user = snapshot.data!;

            return Scaffold(
              appBar: AppBar(
                title: const Text('My Profile'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                        child: user.photoURL == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        user.displayName ?? 'Welcome!',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email ?? 'No email provided',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                       // TODO: Add list of user's booked tickets here
                      const Text("Your booked tickets will appear here."),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        onPressed: () async {
                          await authRepository.signOut();
                          // The stream will automatically rebuild to show the login screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size(200, 50),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    }
    
