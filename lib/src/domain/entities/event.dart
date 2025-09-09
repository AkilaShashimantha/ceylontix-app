import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_tier.dart';

// Represents a single event.
class Event {
  final String? id; // Nullable for new events that don't have an ID yet.
  final String name;
  final String description;
  final String venue;
  final DateTime date;
  final String posterUrl;
  final List<TicketTier> ticketTiers;

  Event({
    this.id,
    required this.name,
    required this.description,
    required this.venue,
    required this.date,
    required this.posterUrl,
    required this.ticketTiers,
  });

  // Converts an Event instance to a Map, suitable for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'venue': venue,
      'date': Timestamp.fromDate(date), // Convert DateTime to Firestore Timestamp.
      'posterUrl': posterUrl,
      'ticketTiers': ticketTiers.map((tier) => tier.toJson()).toList(),
    };
  }

  // **NEW**: Factory constructor to create an Event from a Firestore document.
  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Event(
      id: doc.id, // Get the document ID from Firestore.
      name: data['name'] as String,
      description: data['description'] as String,
      venue: data['venue'] as String,
      date: (data['date'] as Timestamp).toDate(), // Convert Firestore Timestamp back to DateTime.
      posterUrl: data['posterUrl'] as String,
      ticketTiers: (data['ticketTiers'] as List<dynamic>)
          .map((tierData) => TicketTier.fromJson(tierData as Map<String, dynamic>))
          .toList(),
    );
  }
}

