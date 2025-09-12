import '../entities/booking.dart';
import '../entities/event.dart';

// The contract for our booking data source.
abstract class BookingRepository {
  Future<void> createBooking({
    required Booking booking,
    required Event event,
    required String tierName,
    required int quantity,
  });
}
