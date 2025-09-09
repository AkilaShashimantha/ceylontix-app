import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';

class FirebaseEventRepository implements EventRepository {
  final FirebaseFirestore _firestore;

  FirebaseEventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get the 'events' collection reference
  CollectionReference<Map<String, dynamic>> get _eventsCollection => _firestore.collection('events');

  @override
  Future<void> addEvent(Event event) async {
    try {
      await _eventsCollection.add(event.toJson());
    } catch (e) {
      throw Exception('Error adding event: $e');
    }
  }

  @override
  Stream<List<Event>> getEventsStream() {
    return _eventsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsCollection.doc(eventId).delete();
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  // **NEW**: Implementation to update an existing event document.
  @override
  Future<void> updateEvent(Event event) async {
    // We must have an event ID to update it.
    if (event.id == null) {
      throw Exception('Event ID is required to update.');
    }
    try {
      await _eventsCollection.doc(event.id).update(event.toJson());
    } catch (e) {
      throw Exception('Error updating event: $e');
    }
  }
}