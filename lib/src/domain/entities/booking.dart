import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String? id;
  final String eventId;
  final String eventName;
  final String userId;
  final String userName;
  final String userEmail;
  final String tierName;
  final int quantity;
  final double totalPrice;
  final DateTime bookingDate;

  Booking({
    this.id,
    required this.eventId,
    required this.eventName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.tierName,
    required this.quantity,
    required this.totalPrice,
    required this.bookingDate,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'tierName': tierName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'bookingDate': Timestamp.fromDate(bookingDate),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'eventName': eventName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'tierName': tierName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'bookingDate': Timestamp.fromDate(bookingDate),
    };
  }
}
