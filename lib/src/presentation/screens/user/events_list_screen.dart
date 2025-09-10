import 'package:flutter/material.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';
import '../../widgets/event_card.dart';
import '../auth/auth_gate.dart';
import 'profile_screen.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseEventRepository eventRepository = FirebaseEventRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CeylonTix - Upcoming Events'),
        actions: [
          // User account/profile
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Account',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          // Admin panel access
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Admin Login',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AuthGate()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: eventRepository.getEventsStream(),
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
                'No upcoming events at the moment.\nPlease check back later!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final events = snapshot.data!;
          // Sort events by date, showing the soonest first.
          events.sort((a, b) => a.date.compareTo(b.date));

          // Use a LayoutBuilder to make the grid responsive.
          return LayoutBuilder(
            builder: (context, constraints) {
              // Determine the number of columns based on the screen width.
              int crossAxisCount;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 3; // For large desktop screens
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 2; // For tablets or smaller desktop windows
              } else {
                crossAxisCount = 1; // For mobile phones
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16.0, // Spacing between columns
                  mainAxisSpacing: 16.0,  // Spacing between rows
                  childAspectRatio: 0.75, // Adjust this ratio to make cards taller or shorter
                ),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return EventCard(event: events[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

