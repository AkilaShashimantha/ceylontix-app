import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:html' as html;
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
void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePayHereReturn());
  }

  Future<void> _handlePayHereReturn() async {
    final orderId = Uri.base.queryParameters['order_id'];
    if (orderId == null || orderId.isEmpty) return;
    debugPrint('Detected PayHere return with order_id=$orderId');

    try {
      final pendingRef = FirebaseFirestore.instance.collection('pending_bookings').doc(orderId);
      final snap = await pendingRef.get();
      Map<String, dynamic>? data;
      if (snap.exists) {
        data = snap.data() as Map<String, dynamic>;
      } else {
        // fallback to localStorage if pending doc was not created due to rules
        final key = 'ph_pending_' + orderId;
        final raw = html.window.localStorage[key];
        if (raw != null) {
          data = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
      if (data == null) return;

      await FirebaseFirestore.instance.runTransaction((t) async {
        final eventRef = FirebaseFirestore.instance.collection('events').doc(data!['eventId']);
        final eventSnap = await t.get(eventRef);
        if (!eventSnap.exists) {
          throw Exception('Event not found');
        }
        final eventData = eventSnap.data() as Map<String, dynamic>;
        final List<dynamic> tiers = List<dynamic>.from(eventData['ticketTiers']);
        final int idx = tiers.indexWhere((e) => e['name'] == data!['tierName']);
        if (idx == -1) throw Exception('Tier not found');
        if ((tiers[idx]['quantity'] as int) < (data!['quantity'] as int)) {
          throw Exception('Not enough tickets');
        }
        tiers[idx]['quantity'] = (tiers[idx]['quantity'] as int) - (data!['quantity'] as int);
        t.update(eventRef, {'ticketTiers': tiers});

        final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(orderId);
        t.set(bookingRef, {
          'eventId': data!['eventId'],
          'eventName': data!['eventName'],
          'userId': data!['userId'],
          'userName': data!['userName'],
          'userEmail': data!['userEmail'],
          'tierName': data!['tierName'],
          'quantity': data!['quantity'],
          'totalPrice': (data!['totalPrice'] as num).toDouble(),
          'bookingDate': Timestamp.fromDate(DateTime.parse(data!['bookingDate'] ?? DateTime.now().toIso8601String())),
          'status': 'confirmed',
        });
        if (snap.exists) {
          t.delete(pendingRef);
        }
      });

      // cleanup localStorage
      html.window.localStorage.remove('ph_pending_' + orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed. Booking created.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm booking: $e'), backgroundColor: Colors.red));
    }
  }

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