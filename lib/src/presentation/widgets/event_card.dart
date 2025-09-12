import 'package:flutter/material.dart';
import '../../domain/entities/event.dart';
import '../screens/user/event_detail_screen.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  const EventCard({Key? key, required this.event, this.onTap}) : super(key: key);

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  // Build a unique, stable hero tag even if id is null
  String _heroTag() => 'event_poster_${event.id ?? event.posterUrl.hashCode}';

  // Normalize common share links (Google Drive, FreeImage.host) to direct image URLs
  String _resolveImageUrl(String url) {
    // Google Drive shared links -> direct view
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

    // FreeImage.host share page -> iili.io direct image
    if (url.contains('freeimage.host')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final last = segments.last; // e.g., KIH72Bs
          final id = last.split('.').first; // strip any extension if present
          if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
            // Use standard jpg; the CDN also supports size variants like .md.jpg
            return 'https://iili.io/$id.jpg';
          }
        }
      } catch (_) {}
    }

    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias, // Ensures the image respects the card's rounded corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(event: event),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Poster Image
            Expanded(
              child: Hero(
                tag: _heroTag(), // Unique, stable hero tag
                child: Image.network(
                  _resolveImageUrl(event.posterUrl),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Placeholder and error handling for the image
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                    );
                  },
                ),
              ),
            ),
            // Event Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_formatDate(event.date), style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
