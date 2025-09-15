import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'login_or_register_screen.dart';
import 'ticket_view_screen.dart';
import '../../widgets/app_footer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepository = FirebaseAuthRepository();

  Stream<List<Booking>> _getUserBookings(String userId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: _authRepository.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return _buildUserProfile(user);
          }
          return const LoginOrRegisterScreen();
        },
      ),
     
    );
  }

  Widget _buildUserProfile(User user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 16),
                Text('Welcome, ${user.displayName ?? 'Guest'}!',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(user.email ?? 'No Email',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(thickness: 1),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('My Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: _getUserBookings(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('You have no bookings yet.'));
                }
                final bookings = snapshot.data!;
                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.confirmation_number_outlined),
                        title: Text(booking.eventName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:
                            Text('${booking.quantity} x ${booking.tierName} Ticket(s)'),
                        trailing:
                            Text(DateFormat.yMMMd().format(booking.bookingDate)),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TicketViewScreen(
                                booking: booking, bookingId: booking.id!),
                          ));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout,color:Color.fromARGB(255, 255, 255, 255)),
              label:  Text('Sign Out', style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255)),),
              onPressed: () async {
                await _authRepository.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}