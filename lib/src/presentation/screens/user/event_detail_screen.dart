import 'package:flutter/material.dart';
import '../../../domain/entities/event.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;
  const EventDetailScreen({Key? key, required this.event}) : super(key: key);

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  // Normalize common share links (e.g., Google Drive) to direct-view URLs
  String _resolveImageUrl(String url) {
    if (url.contains('drive.google.com')) {
      final idMatch = RegExp(r"/d/([^/]+)").firstMatch(url) ?? RegExp(r"[?&]id=([a-zA-Z0-9_-]+)").firstMatch(url);
      if (idMatch != null) {
        final id = idMatch.group(1);
        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with the event poster that collapses on scroll
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                event.name,
                style: const TextStyle(shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
              ),
              background: Hero(
                tag: 'event_poster_${event.id}', // Match the tag from EventCard
                child: Image.network(
                  _resolveImageUrl(event.posterUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 80)),
                    );
                  },
                ),
              ),
            ),
          ),
          // The rest of the event details
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(context, Icons.calendar_today_outlined, 'Date & Time', _formatDateTime(event.date)),
                      const Divider(height: 32),
                      _buildDetailRow(context, Icons.location_on_outlined, 'Venue', event.venue),
                      const Divider(height: 32),
                      Text('About this Event', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(event.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                      const Divider(height: 32),
                      Text('Ticket Tiers', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...event.ticketTiers.map((tier) => Card(
                        child: ListTile(
                          title: Text(tier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Available: ${tier.quantity}'),
                          trailing: Text('LKR ${tier.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                      )),
                      const SizedBox(height: 32),
                      // This button is a placeholder for now.
                      // We will add the booking functionality in the next step.
                      ElevatedButton.icon(
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Book Tickets'),
                        onPressed: () {
                           // TODO: Implement booking flow
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booking functionality will be added soon!')),
                           );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to create consistent-looking detail rows
  Widget _buildDetailRow(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.deepPurple, size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
          ],
        )
      ],
    );
  }
}
