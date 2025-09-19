import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';
import 'add_event_screen.dart';
import 'edit_event_screen.dart';
import 'sales_report_screen.dart';
import 'qr_scanner_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuthRepository _authRepository = FirebaseAuthRepository();
  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _resolveImageUrl(String url) {
    if (url.contains('drive.google.com')) {
      final idMatch = RegExp(r"/d/([^/]+)").firstMatch(url) ??
          RegExp(r"[?&]id=([a-zA-Z0-9_-]+)").firstMatch(url);
      if (idMatch != null) {
        final id = idMatch.group(1);
        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    }
    if (url.contains('freeimage.host')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final last = segments.last;
          final id = last.split('.').first;
          if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
            return 'https://iili.io/$id.jpg';
          }
        }
      } catch (_) {}
    }
    return url;
  }

  void _navigateToEditScreen(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditEventScreen(event: event),
      ),
    );
  }

  void _confirmDelete(Event event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text('Do you want to permanently delete the event "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (mounted) {
                _eventRepository.deleteEvent(event.id!);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event deleted successfully'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Color.fromARGB(247, 255, 255, 255),fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: TextButton.icon(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan QR', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: TextButton.icon(
              icon: const Icon(Icons.analytics, color: Colors.white),
              label: const Text('Reports', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SalesReportScreen()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await _authRepository.signOut();
                if (!context.mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
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
                'No events found.\nTap the "+" button to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final events = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  onTap: () => _navigateToEditScreen(event),
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: event.posterUrl.isNotEmpty
                        ? NetworkImage(_resolveImageUrl(event.posterUrl))
                        : null,
                    child: event.posterUrl.isEmpty
                        ? const Icon(Icons.image_not_supported)
                        : null,
                  ),
                  title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${event.venue}\n${_formatDateTime(event.date)}'),
                  isThreeLine: true,
                  trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: () => _navigateToEditScreen(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(80, 36),
                    ),
                    ),
                      const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                          label: const Text('Delete'),
                          onPressed: () => _confirmDelete(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(80, 36),
                          ),
                        ),
                      ],
                    ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEventScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}