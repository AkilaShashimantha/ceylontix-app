import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;
import 'package:crypto/crypto.dart' as crypto;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceylontix_app/src/domain/entities/booking.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'payment_preview_screen.dart';
import '../../../data/services/payhere_service.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../widgets/app_footer.dart';

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

  // Normalize common share links (Google Drive, FreeImage.host) to direct image URLs
  String _resolveImageUrl(String url) {
    // Google Drive shared links -> direct view
    if (url.contains('drive.google.com')) {
      final idMatch = RegExp(r"/d/([^/]+)").firstMatch(url) ??
          RegExp(r"[?&]id=([a-zA-Z0-9_-]+)").firstMatch(url);
      if (idMatch != null) {
        final id = idMatch.group(1);
        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    }

    // FreeImage.host share page -> iili.io direct image
    if (url.contains('freeimage.host')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final last = segments.last; // e.g., KIH72Bs
          final id = last.split('.').first; // strip any extension if present
          if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
            // Use standard jpg; the CDN also supports size variants like .md.jpg
            return 'https://iili.io/$id.jpg';
          }
        }
      } catch (_) {}
    }

    return url;
  }

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

    final details = await _promptUserDetails(initialName: currentUser.displayName, initialEmail: currentUser.email);
    if (details == null) return; // cancelled

    setState(() => _isLoading = true);

    // Show payment preview screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentPreviewScreen(
          event: widget.event,
          selectedTier: _selectedTier!,
          quantity: _quantity,
          userDetails: details,
          onConfirmPayment: () async {
            Navigator.of(context).pop(); // Close preview screen
            
            if (kIsWeb) {
              await _handleWebCheckout(currentUser, details);
            } else {
              _handleMobileCheckout(currentUser, details);
            }
          },
        ),
      ),
    ).then((_) {
      // Reset loading state when user returns
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<Map<String, String>?> _promptUserDetails({String? initialName, String? initialEmail}) async {
    final nameParts = (initialName ?? '').trim().split(' ');
    final firstNameController = TextEditingController(text: nameParts.isNotEmpty ? nameParts.first : '');
    final lastNameController = TextEditingController(text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    final phoneController = TextEditingController();
    final nicController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController(text: 'Colombo');
    final formKey = GlobalKey<FormState>();

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Your Details'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        final reg = RegExp(r'^0\d{9}$');
                        if (!reg.hasMatch(s)) return 'Enter valid 10-digit phone (starts with 0)';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: nicController,
                      decoration: const InputDecoration(labelText: 'NIC'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        final oldNic = RegExp(r'^\d{9}[vVxX]$');
                        final newNic = RegExp(r'^\d{12}$');
                        if (!(oldNic.hasMatch(s) || newNic.hasMatch(s))) return 'Enter valid NIC (9 digits + V/X or 12 digits)';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(ctx).pop({
                    'firstName': firstNameController.text.trim(),
                    'lastName': lastNameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'nic': nicController.text.trim(),
                    'address': addressController.text.trim(),
                    'city': cityController.text.trim(),
                  });
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // WEB FLOW: Create a pending booking, post to PayHere, and let notify_url confirm.
  Future<void> _handleWebCheckout(currentUser, Map<String, String> details) async {
    final orderId = const Uuid().v4();
    final totalAmount = _selectedTier!.price * _quantity;
    final merchantId = PayHereService.sandboxMerchantId;
    final currency = "LKR";

    try {
      // 1) Create pending booking for server-side confirmation
      await _createPendingBooking(orderId, currentUser, totalAmount, details: details);

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
        'first_name': details['firstName']!,
        'last_name': details['lastName']!,
        'email': currentUser.email ?? '',
        'phone': details['phone']!,
        'address': details['address']!,
        'city': details['city']!,
        'country': 'Sri Lanka',
        'custom_1': details['nic']!,
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
        'userName': '${details['firstName']!.trim()} ${details['lastName']!.trim()}'.trim(),
        'userEmail': currentUser.email ?? 'N/A',
        'phone': details['phone'],
        'address': details['address'],
        'nic': details['nic'],
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

  Future<void> _createPendingBooking(String orderId, dynamic currentUser, double totalAmount, {Map<String, String>? details}) async {
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
  void _handleMobileCheckout(currentUser, Map<String, String> details) {
    final customerDetails = {
      'firstName': details['firstName']!,
      'lastName': details['lastName']!,
      'email': currentUser.email ?? 'no-email@test.com',
      'phone': details['phone']!,
      'address': details['address']!,
      'city': details['city'] ?? 'Colombo'
    };
    final orderId = const Uuid().v4();
    final totalAmount = _selectedTier!.price * _quantity;

    PayHereService.startPayment(
      context: context,
      amount: totalAmount,
      orderId: orderId,
      itemName: '${_quantity}x ${_selectedTier!.name} Ticket(s)',
      customerDetails: customerDetails,
      onSuccess: (paymentId) => _createBookingInFirestore(currentUser, details),
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
  Future<void> _createBookingInFirestore(currentUser, [Map<String, String>? details]) async {
    try {
      final newBooking = Booking(
        eventId: widget.event.id!,
        eventName: widget.event.name,
        userId: currentUser.uid,
        userName: details != null && (details['firstName']?.isNotEmpty == true)
            ? '${details['firstName']!.trim()} ${details['lastName']!.trim()}'.trim()
            : (currentUser.displayName ?? 'N/A'),
        userEmail: currentUser.email ?? 'N/A',
        tierName: _selectedTier!.name,
        quantity: _quantity,
        totalPrice: _selectedTier!.price * _quantity,
        bookingDate: DateTime.now(),
        phone: details?['phone'],
        address: details?['address'],
        nic: details?['nic'],
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

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Image at the top with back button overlay
                      Stack(
                        children: [
                          Hero(
                            tag: 'event_poster_${currentEvent.id}',
                            child: Image.network(
                              _resolveImageUrl(currentEvent.posterUrl),
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: 300,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (ctx, err, st) => Container(
                                width: double.infinity,
                                height: 300,
                                color: Colors.grey[200],
                                child: const Center(
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey, size: 50)),
                              ),
                            ),
                          ),
                          // Back button
                          Positioned(
                            top: 40,
                            left: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Event Details
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event Name
                            Text(
                              currentEvent.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
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
                        const AppFooter(),
                    ],
                  ),                
                ),
              ),
           ],
          );
        },
      ),
    );
  }
}



