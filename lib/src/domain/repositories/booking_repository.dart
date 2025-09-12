import '../entities/booking.dart';
import '../entities/event.dart';

// The contract for our booking data source.
abstract class BookingRepository {
  // Returns the created booking document ID
  Future<String> createBooking({
    required Booking booking,
    required Event event,
    required String tierName,
    required int quantity,
  });
}
