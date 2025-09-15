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
  final String? status;

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
    this.status,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      tierName: data['tierName'] ?? '',
      quantity: data['quantity'] ?? 0,
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      bookingDate: (data['bookingDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'confirmed',
    );
  }

  // CRITICAL FIX: Renamed from toFirestore() to toJson() to match the repository call
  Map<String, dynamic> toJson() {
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
      'status': status,
    };
  }
}