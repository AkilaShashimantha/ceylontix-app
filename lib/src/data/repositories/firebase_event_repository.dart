import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';

class FirebaseEventRepository implements EventRepository {
  final FirebaseFirestore _firestore;

  FirebaseEventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _firestore.collection('events');

  @override
  Future<void> addEvent(Event event) async {
    await _eventsCol.add(event.toJson());
  }

  @override
  Stream<List<Event>> getEventsStream() {
    return _eventsCol
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _eventsCol.doc(eventId).delete();
  }

  @override
  Future<void> updateEvent(Event event) async {
    if (event.id == null) {
      throw ArgumentError('Event id is required to update');
    }
    await _eventsCol.doc(event.id).update(event.toJson());
  }

  @override
  Stream<Event> getEventStream(String eventId) {
    return _eventsCol.doc(eventId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception('Event not found!');
      }
      return Event.fromFirestore(doc);
    });
  }
}


