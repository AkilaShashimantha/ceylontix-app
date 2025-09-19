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
import '../../widgets/app_footer.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();
  final FirebaseAuthRepository _authRepository = FirebaseAuthRepository();

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePayHereReturn());
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _query) {
        setState(() => _query = next.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        final key = 'ph_pending_$orderId';
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
        if ((tiers[idx]['quantity'] as int) < (data['quantity'] as int)) {
          throw Exception('Not enough tickets');
        }
        tiers[idx]['quantity'] = (tiers[idx]['quantity'] as int) - (data['quantity'] as int);
        t.update(eventRef, {'ticketTiers': tiers});

        final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(orderId);
        t.set(bookingRef, {
          'eventId': data['eventId'],
          'eventName': data['eventName'],
          'userId': data['userId'],
          'userName': data['userName'],
          'userEmail': data['userEmail'],
          'tierName': data['tierName'],
          'quantity': data['quantity'],
          'totalPrice': (data['totalPrice'] as num).toDouble(),
          'bookingDate': Timestamp.fromDate(DateTime.parse(data['bookingDate'] ?? DateTime.now().toIso8601String())),
          'status': 'confirmed',
        });
        if (snap.exists) {
          t.delete(pendingRef);
        }
      });

      // cleanup localStorage
      html.window.localStorage.remove('ph_pending_$orderId');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed. Booking created.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm booking: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 1000;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
        toolbarHeight: isDesktop ? 90 : kToolbarHeight,
        leadingWidth: isDesktop ? 140 : 80,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/logo/app_logo.png',
              height: isDesktop ? 56 : 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: const Text(
          'CeylonTix - Upcoming Events',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isDesktop ? 80 : 70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Center(
              child: SizedBox(
                width: width * 0.5, // Half of screen width
                child: _SearchBar(
                  controller: _searchController,
                  isDesktop: isDesktop,
                  onClear: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ),
          ),
        ),
        actions: [
          StreamBuilder<User?>(
            stream: _authRepository.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active && snapshot.hasData) {
                final user = snapshot.data!;
                return Row(
                  children: [
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
          int crossAxisCount;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = 2;
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
                return const Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'No events available at the moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ),
                    ),
                    AppFooter(),
                  ],
                );
              }

              final events = snapshot.data!;
              final filtered = _query.isEmpty
                  ? events
                  : events.where((e) => e.name.toLowerCase().contains(_query)).toList();

              if (filtered.isEmpty) {
                return const Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text('No events match your search.', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    AppFooter(),
                  ],
                );
              }

              final sidePad = constraints.maxWidth >= 1200
                  ? constraints.maxWidth * (2 / 12)
                  : 16.0;

              return Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final event = filtered[index];
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
                    ),
                  ),
                  const AppFooter(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDesktop;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isDesktop,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final double height = isDesktop ? 50 : 44;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2), spreadRadius: 0),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search events by name...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 12);
              return IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: onClear,
              );
            },
          ),
        ],
      ),
    );
  }
}

