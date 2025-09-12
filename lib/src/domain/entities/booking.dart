import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String? id;
  final String eventId;
  final String userId;
  final String userName; // Denormalized for easier access
  final String userEmail; // Denormalized for easier access
  final String eventName; // Denormalized for easier access
  final String tierName;
  final int quantity;
  final double totalPrice;
  final DateTime bookingDate;

  Booking({
    this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.eventName,
    required this.tierName,
    required this.quantity,
    required this.totalPrice,
    required this.bookingDate,
  });

  // Method to convert a Booking object to a JSON map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'eventName': eventName,
      'tierName': tierName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'bookingDate': Timestamp.fromDate(bookingDate),
    };
  }
}
