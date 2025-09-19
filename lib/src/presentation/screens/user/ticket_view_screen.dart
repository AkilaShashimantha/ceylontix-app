import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../domain/entities/booking.dart';

class TicketViewScreen extends StatelessWidget {
  final Booking booking;
  final String bookingId;

  const TicketViewScreen({
    super.key,
    required this.booking,
    required this.bookingId,
  });

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Ticket'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      booking.eventName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: jsonEncode({
                        'bookingId': bookingId,
                        'eventName': booking.eventName,
                        'userName': booking.userName,
                        'userEmail': booking.userEmail,
                        'phone': booking.phone,
                        'address': booking.address,
                        'nic': booking.nic,
                        'tier': booking.tierName,
                        'quantity': booking.quantity,
                        'bookingDate': booking.bookingDate.toIso8601String(),
                      }),
                      version: QrVersions.auto,
                      size: math.min(screenSize.height * 0.5, screenSize.width * 0.8),
                      gapless: false,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan this QR code at the entrance',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const Divider(height: 30),
                    _buildTicketDetailRow(Icons.person_outline, 'Booked By', booking.userName),
                    _buildTicketDetailRow(Icons.confirmation_number_outlined, 'Tier', booking.tierName),
                    _buildTicketDetailRow(Icons.people_alt_outlined, 'Quantity', booking.quantity.toString()),
                    _buildTicketDetailRow(Icons.calendar_today_outlined, 'Date', _formatDate(booking.bookingDate)),
                    const SizedBox(height: 10),
                     Text(
                      'ID: $bookingId',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
               const SizedBox(height: 20),
              // This is where you would call a function to send a real email.
              OutlinedButton.icon(
                icon: const Icon(Icons.email_outlined),
                label: const Text('Resend to Email'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email sending functionality would be implemented here.'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[700], size: 20),
              const SizedBox(width: 10),
              Text('$label:', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}