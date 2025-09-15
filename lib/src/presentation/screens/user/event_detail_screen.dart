import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;
import 'package:crypto/crypto.dart' as crypto;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceylontix_app/src/domain/entities/booking.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_booking_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import 'profile_screen.dart';
import 'ticket_view_screen.dart';
import '../../../data/services/payhere_service.dart';
import '../../../data/repositories/firebase_event_repository.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseBookingRepository _bookingRepository =
      FirebaseBookingRepository();
  final AuthRepository _authRepository = FirebaseAuthRepository();
  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();


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
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }

  // This is the single, correct checkout function that handles both platforms.
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

    // PLATFORM-AWARE LOGIC: Checks if the app is running on the web.
    if (kIsWeb) {
      await _handleWebCheckout(currentUser);
    } else {
      _handleMobileCheckout(currentUser);
    }
  }

  // WEB FLOW: Create a pending booking, post to PayHere, and let notify_url confirm.
  Future<void> _handleWebCheckout(currentUser) async {
    final orderId = const Uuid().v4();
    final totalAmount = _selectedTier!.price * _quantity;
    final merchantId = PayHereService.sandboxMerchantId;
    final currency = "LKR";

    try {
      // 1) Create pending booking for server-side confirmation
      await _createPendingBooking(orderId, currentUser, totalAmount);

      // 2) Compute hash per PayHere docs
      const payHereSecret = 'MzgxNjc1NDc1MzQwODQyMTI0NzAyMDk0MzUzNzQzMzcxMzU4OTI0MA==';
      final secretMd5 = crypto.md5.convert(utf8.encode(payHereSecret)).toString().toUpperCase();
      final amountStr = totalAmount.toStringAsFixed(2);
      final preHash = merchantId + orderId + amountStr + currency + secretMd5;
      final String hash = crypto.md5.convert(utf8.encode(preHash)).toString().toUpperCase();

      // 3) Submit POST form to PayHere
      final origin = kIsWeb ? html.window.location.origin : 'http://localhost';
      final Map<String, String> fields = {
        'merchant_id': merchantId,
        'return_url': origin,
        'cancel_url': origin,
        'notify_url': 'https://us-central1-ceylontix-app.cloudfunctions.net/payhereNotify',
        'order_id': orderId,
        'items': '${_quantity}x ${_selectedTier!.name} Ticket(s) for ${widget.event.name}',
        'amount': amountStr,
        'currency': currency,
        'hash': hash,
        'first_name': (currentUser.displayName ?? 'John Doe').trim().split(' ').first,
        'last_name': (currentUser.displayName ?? 'John Doe').trim().split(' ').length > 1 ? (currentUser.displayName ?? 'John Doe').trim().split(' ').sublist(1).join(' ') : 'Doe',
        'email': currentUser.email ?? '',
        'phone': '0771234567',
        'address': 'No. 1, Galle Road',
        'city': 'Colombo',
        'country': 'Sri Lanka',
      };

      final form = html.FormElement()
        ..method = 'POST'
        ..action = 'https://sandbox.payhere.lk/pay/checkout';
      // Persist minimal pending booking data in localStorage as a fallback
      final pendingData = {
        'orderId': orderId,
        'eventId': widget.event.id!,
        'eventName': widget.event.name,
        'userId': currentUser.uid,
        'userName': currentUser.displayName ?? 'N/A',
        'userEmail': currentUser.email ?? 'N/A',
        'tierName': _selectedTier!.name,
        'quantity': _quantity,
        'totalPrice': totalAmount,
        'bookingDate': DateTime.now().toIso8601String(),
      };
      html.window.localStorage['ph_pending_' + orderId] = jsonEncode(pendingData);

      fields.forEach((name, value) {
        final input = html.InputElement(type: 'hidden')
          ..name = name
          ..value = value;
        form.append(input);
      });
      html.document.body!.append(form);
      form.submit();
      form.remove();

      // Do not create booking here; wait for notify_url to confirm
    } catch (e) {
      debugPrint("Error during web checkout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Web checkout failed. See console for details.'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createPendingBooking(String orderId, dynamic currentUser, double totalAmount) async {
    try {
      await FirebaseFirestore.instance.collection('pending_bookings').doc(orderId).set({
        'orderId': orderId,
        'eventId': widget.event.id!,
        'eventName': widget.event.name,
        'userId': currentUser.uid,
        'userName': currentUser.displayName ?? 'N/A',
        'userEmail': currentUser.email ?? 'N/A',
        'tierName': _selectedTier!.name,
        'quantity': _quantity,
        'totalPrice': totalAmount,
        'bookingDate': DateTime.now(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Failed to create pending booking: $e');
      rethrow;
    }
  }

  // MOBILE FLOW: USES the native PayHere SDK.
  void _handleMobileCheckout(currentUser) {
    final customerDetails = {
      'firstName': currentUser.displayName?.split(' ').first ?? 'John',
      'lastName': currentUser.displayName?.split(' ').last ?? 'Doe',
      'email': currentUser.email ?? 'no-email@test.com',
      'phone': '0771234567',
      'address': 'No. 1, Galle Road',
      'city': 'Colombo'
    };
    final orderId = const Uuid().v4();
    final totalAmount = _selectedTier!.price * _quantity;

    PayHereService.startPayment(
      context: context,
      amount: totalAmount,
      orderId: orderId,
      itemName: '${_quantity}x ${_selectedTier!.name} Ticket(s)',
      customerDetails: customerDetails,
      onSuccess: (paymentId) => _createBookingInFirestore(currentUser),
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Payment Failed: $error'),
              backgroundColor: Colors.red));
        }
        if (mounted) setState(() => _isLoading = false);
      },
      onDismissed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Payment process was cancelled.')));
        }
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  // Creates the booking record in Firestore after a successful payment.
  Future<void> _createBookingInFirestore(currentUser) async {
    try {
      final newBooking = Booking(
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

      final newBookingId = await _bookingRepository.createBooking(
        booking: newBooking,
        event: widget.event,
        tierName: _selectedTier!.name,
        quantity: _quantity,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              TicketViewScreen(booking: newBooking, bookingId: newBookingId),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Booking Failed: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Event>(
        stream: _eventRepository.getEventStream(widget.event.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
                child: Text('Error: Could not load event details.'));
          }
          final currentEvent = snapshot.data!;

          if (_selectedTier != null) {
            _selectedTier = currentEvent.ticketTiers
                .firstWhere((t) => t.name == _selectedTier!.name);
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(currentEvent.name,
                      style: const TextStyle(
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                  background: Hero(
                    tag: 'event_poster_${currentEvent.id}',
                    child: Image.network(
                      currentEvent.posterUrl,
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
                          'Date: ${DateFormat.yMMMd().add_jm().format(currentEvent.date)}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Venue: ${currentEvent.venue}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      Text(currentEvent.description,
                          style:
                              const TextStyle(fontSize: 16, height: 1.5)),
                      const Divider(height: 40),
                      const Text('Select Ticket Tier',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...currentEvent.ticketTiers.map((tier) {
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
                                icon:
                                    const Icon(Icons.remove_circle_outline)),
                            Text('$_quantity',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                            const SizedBox(height: 20),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleCheckout,
                                      icon: const Icon(Icons
                                          .shopping_cart_checkout),
                                      label: const Text('Proceed to Checkout'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        textStyle:
                                            const TextStyle(fontSize: 18),
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
          );
        },
      ),
    );
  }
}
