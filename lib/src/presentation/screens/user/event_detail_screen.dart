import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
// ** CORRECTED IMPORTS TO RESPECT YOUR PROJECT STRUCTURE **
import '../../../domain/entities/booking.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_booking_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import 'profile_screen.dart';
import 'ticket_view_screen.dart';
import 'dart:html' as html; 
import 'dart:convert';
import 'package:crypto/crypto.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  // ** LINTER FIX: USE SUPER PARAMETERS **
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  // Using the Sandbox Merchant ID you provided.
  static const String _sandboxMerchantId = "1232005"; // Your Merchant ID

  final FirebaseBookingRepository _bookingRepository = FirebaseBookingRepository();
  // ** LINTER FIX: PROGRAM TO THE INTERFACE AS REQUESTED **
  final AuthRepository _authRepository = FirebaseAuthRepository();

  TicketTier? _selectedTier;
  int _quantity = 1;
  bool _isLoading = false;

  void _incrementQuantity() {
    if (_selectedTier != null && _quantity < _selectedTier!.quantity) {
      setState(() => _quantity++);
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to be logged in to book tickets.'),
        actions: [
          TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            child: const Text('Login / Sign Up'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
    if (_selectedTier == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a ticket tier.')));
      }
      return;
    }
    final currentUser = await _authRepository.authStateChanges.first;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }
    setState(() => _isLoading = true);

    // Create a pending booking first, which gives us a stable orderId
    final orderId = await _createPendingBooking(currentUser);

    if (orderId == null) {
      // Handle error if pending booking fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not initiate checkout. Please try again.'),
            backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      if (kIsWeb) {
        await _handleWebCheckout(currentUser, orderId);
      } else {
        _handleMobileCheckout(currentUser, orderId);
      }
    } finally {
      // On web, the user is redirected, so we don't need to manage the loading state here.
      // On mobile, the PayHere SDK callbacks will manage the loading state.
    }
  }



String generatePayHereHash({
  required String merchantId,
  required String orderId,
  required String amount,
  required String currency,
  required String merchantSecret,
}) {
  final secretHash =
      md5.convert(utf8.encode(merchantSecret)).toString().toUpperCase();
  final raw = merchantId + orderId + amount + currency + secretHash;
  return md5.convert(utf8.encode(raw)).toString().toUpperCase();
}


Future<void> _handleWebCheckout(User currentUser, String orderId) async {
  final totalAmount = _selectedTier!.price * _quantity;
  final merchantId = _sandboxMerchantId;
  const merchantSecret = "MzgxNjc1NDc1MzQwODQyMTI0NzAyMDk0MzUzNzQzMzcxMzU4OTI0MA==";
  final currency = "LKR";
  final amountFormatted = totalAmount.toStringAsFixed(2);

  final returnUrl = Uri.base.toString();
  final cancelUrl = Uri.base.toString();
  const projectId = "ceylontix-app";
  const region = "us-central1";
  final notifyUrl = 'https://$region-$projectId.cloudfunctions.net/payhereNotify';

  // Generate secure hash
  final hash = generatePayHereHash(
    merchantId: merchantId,
    orderId: orderId,
    amount: amountFormatted,
    currency: currency,
    merchantSecret: merchantSecret,
  );

  final Map<String, String> params = {
    'merchant_id': merchantId,
    'return_url': returnUrl,
    'cancel_url': cancelUrl,
    'notify_url': notifyUrl,
    'order_id': orderId,
    'items':
        '${_quantity}x ${_selectedTier!.name} Ticket(s) for ${widget.event.name}',
    'amount': amountFormatted,
    'currency': currency,
    'first_name': currentUser.displayName?.split(' ').first ?? 'John',
    'last_name': currentUser.displayName?.split(' ').last ?? 'Doe',
    'email': currentUser.email ?? '',
    'phone': '0771234567',
    'address': 'No. 1, Galle Road',
    'city': 'Colombo',
    'country': 'Sri Lanka',
    'hash': hash, // 👈 critical field
  };

  final form = html.FormElement()
    ..method = 'POST'
    ..action = 'https://sandbox.payhere.lk/pay/checkout';

  params.forEach((key, value) {
    form.append(html.InputElement()
      ..type = 'hidden'
      ..name = key
      ..value = value);
  });

  html.document.body!.append(form);
  form.submit();
}



  void _handleMobileCheckout(User currentUser, String orderId) {
    final totalAmount = _selectedTier!.price * _quantity;

    // **IMPORTANT**: Replace with your project details
    const projectId = "ceylontix-app"; // Your Firebase Project ID
    const region = "us-central1"; // The region of your function
    final notifyUrl =
        'https://$region-$projectId.cloudfunctions.net/payhereNotify';

    // --- 1. CRITICAL: Set up the Payment Object for SANDBOX ---
    Map<String, dynamic> paymentObject = {
      // THIS IS THE MOST IMPORTANT PART FOR TESTING.
      "sandbox": true,

      // --- 2. Use your SANDBOX credentials ---
      "merchant_id": _sandboxMerchantId,

      // --- 3. Payment Details ---
      "notify_url": notifyUrl, // Your backend endpoint
      "order_id": orderId,
      "items":
          '${_quantity}x ${_selectedTier!.name} Ticket(s) for ${widget.event.name}',
      "amount": totalAmount.toStringAsFixed(2),
      "currency": "LKR",

      // --- 4. Customer Details (Prefill for a better user experience) ---
      "first_name": currentUser.displayName?.split(' ').first ?? 'Saman',
      "last_name": currentUser.displayName?.split(' ').last ?? 'Perera',
      "email": currentUser.email ?? 'saman.perera@example.com',
      "phone": "0771234567",
      "address": "No. 1, Galle Road",
      "city": "Colombo",
      "country": "Sri Lanka",
    };

    // --- 5. Start the Payment Gateway ---
    PayHere.startPayment(
      paymentObject,
      (paymentId) {
        debugPrint("PayHere Payment Success. Payment Id: $paymentId");
        // The booking is now handled by the notify_url.
        // We just show a confirmation message and can navigate away.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Payment successful! Your ticket is being processed.'),
            backgroundColor: Colors.green));
        // Optionally, navigate to a "My Bookings" screen
        Navigator.of(context).pop();
      },
      (error) {
        debugPrint("PayHere Payment Failed. Error: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Payment Failed: $error'),
              backgroundColor: Colors.red));
          setState(() => _isLoading = false);
        }
      },
      () {
        debugPrint("PayHere Payment Dismissed by User");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment process was cancelled.')));
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<String?> _createPendingBooking(User currentUser) async {
    try {
      final pendingBooking = Booking(
        eventId: widget.event.id!,
        eventName: widget.event.name,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'N/A',
        userEmail: currentUser.email ?? 'N/A',
        tierName: _selectedTier!.name,
        quantity: _quantity,
        totalPrice: _selectedTier!.price * _quantity,
        bookingDate: DateTime.now(),
      );

      final docRef = await FirebaseFirestore.instance
          .collection('pending_bookings')
          .add(pendingBooking.toFirestore());

      return docRef.id; // This ID is our secure order_id
    } catch (e) {
      debugPrint("Error creating pending booking: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.event.name,
                  style: const TextStyle(
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              background: Hero(
                tag: 'event_poster_${widget.event.id}',
                child: Image.network(
                  widget.event.posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.grey, size: 50)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Date: ${DateFormat.yMMMd().add_jm().format(widget.event.date)}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Venue: ${widget.event.venue}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Text(widget.event.description,
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  const Divider(height: 40),
                  const Text('Select Ticket Tier',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...widget.event.ticketTiers.map((tier) {
                    final bool isAvailable = tier.quantity > 0;
                    return RadioListTile<TicketTier>(
                      title: Text(tier.name),
                      subtitle: Text(
                          'LKR ${tier.price.toStringAsFixed(2)} - ${isAvailable ? "${tier.quantity} available" : "Sold Out"}'),
                      value: tier,
                      groupValue: _selectedTier,
                      onChanged: isAvailable
                          ? (value) => setState(() {
                                _selectedTier = value;
                                _quantity = 1;
                              })
                          : null,
                      activeColor: Theme.of(context).primaryColor,
                    );
                  }),
                  const SizedBox(height: 20),
                  if (_selectedTier != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            onPressed: _decrementQuantity,
                            icon: const Icon(Icons.remove_circle_outline)),
                        Text('$_quantity',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                            onPressed: _incrementQuantity,
                            icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  Center(
                    child: Column(
                      children: [
                        if (_selectedTier != null)
                          Text(
                            'Total: LKR ${(_selectedTier!.price * _quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _handleCheckout,
                                  icon:
                                      const Icon(Icons.shopping_cart_checkout),
                                  label: const Text('Proceed to Checkout'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    textStyle: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}