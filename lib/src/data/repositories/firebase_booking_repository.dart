import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/ticket_tier.dart';
import '../../domain/repositories/booking_repository.dart';

class FirebaseBookingRepository implements BookingRepository {
  final FirebaseFirestore _firestore;

  FirebaseBookingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createBooking({
    required Booking booking,
    required Event event,
    required String tierName,
    required int quantity,
  }) async {
    final eventRef = _firestore.collection('events').doc(event.id);
    final bookingRef = _firestore.collection('bookings').doc();

    return _firestore.runTransaction((transaction) async {
      // 1. Read the event document within the transaction
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists) {
        throw Exception("Event does not exist!");
      }

      // 2. Get the current list of ticket tiers
      final currentEventData = eventSnapshot.data() as Map<String, dynamic>;
      final List<dynamic> tierMaps = currentEventData['ticketTiers'];
      final List<TicketTier> currentTiers = tierMaps.map((tier) => TicketTier.fromJson(tier)).toList();

      // 3. Find the specific tier being booked
      final tierIndex = currentTiers.indexWhere((t) => t.name == tierName);
      if (tierIndex == -1) {
        throw Exception("Ticket tier not found.");
      }

      final targetTier = currentTiers[tierIndex];

      // 4. Check if enough tickets are available
      if (targetTier.quantity < quantity) {
        throw Exception("Not enough tickets available for the '${targetTier.name}' tier.");
      }

      // 5. Calculate the new quantity and update the list of tiers
      final updatedQuantity = targetTier.quantity - quantity;
      currentTiers[tierIndex] = TicketTier(
        name: targetTier.name,
        price: targetTier.price,
        quantity: updatedQuantity,
      );

      // Convert the updated list back to a list of maps
      final updatedTiersJson = currentTiers.map((t) => t.toJson()).toList();

      // 6. Update the event document with the new ticket tier quantities
      transaction.update(eventRef, {'ticketTiers': updatedTiersJson});

      // 7. Create the new booking document
      transaction.set(bookingRef, booking.toJson());
    });
  }
}
