import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../../data/repositories/auth_repository.dart'; 

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();
  final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(); // Auth repository instance

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder for responsive column count
    return Scaffold(
      appBar: AppBar(
        title: const Text('CeylonTix - Upcoming Events'),
        backgroundColor: Theme.of(context).primaryColor,
        // Use a StreamBuilder to dynamically change the app bar actions based on auth state
        actions: [
          StreamBuilder<User?>(
            stream: _authRepository.authStateChanges,
            builder: (context, snapshot) {
              // If user is logged in, show profile avatar
              if (snapshot.connectionState == ConnectionState.active && snapshot.hasData) {
                final user = snapshot.data!;
                return Row(
                  children: [
                    // Admin button visible only if the user has admin claim
                    FutureBuilder<IdTokenResult>(
                      future: user.getIdTokenResult(true),
                      builder: (context, tokenSnap) {
                        final isAdmin = tokenSnap.data?.claims?["admin"] == true;
                        if (tokenSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (!isAdmin) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: 'Admin Panel',
                          icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            );
                          },
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          backgroundColor: Colors.grey[200],
                          child: user.photoURL == null
                              ? const Icon(Icons.person_outline, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // If user is not logged in, show Sign In and Sign Up buttons
              return Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine number of columns based on screen width
          int crossAxisCount;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 3; // Large screens
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 2; // Medium screens (tablets)
          } else {
            crossAxisCount = 1; // Small screens (phones)
          }

          return StreamBuilder<List<Event>>(
            stream: _eventRepository.getEventsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('An error occurred: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No events available at the moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }

              final events = snapshot.data!;

              return GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.8, // Adjust aspect ratio for better card appearance
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return EventCard(
                    event: event,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

