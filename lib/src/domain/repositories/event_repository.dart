import '../entities/event.dart';

// The contract for our event data source.
abstract class EventRepository {
  Future<void> addEvent(Event event);

  Stream<List<Event>> getEventsStream();

  Future<void> deleteEvent(String eventId);

  // **NEW**: A method to update an existing event.
  Future<void> updateEvent(Event event);
}