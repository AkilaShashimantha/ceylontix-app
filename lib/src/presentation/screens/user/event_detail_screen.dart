import 'package:flutter/foundation.dart' show kIsWeb; // Import to check for web platform
import 'package:ceylontix_app/src/domain/entities/booking.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import if not present
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_booking_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import 'profile_screen.dart';
import 'ticket_view_screen.dart';
import '../../../data/services/payhere_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseBookingRepository _bookingRepository = FirebaseBookingRepository();
  final FirebaseAuthRepository _authRepository = FirebaseAuthRepository();

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
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            child: const Text('Login / Sign Up'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }

  // Main checkout function that decides which flow to use
  Future<void> _handleCheckout() async {
    if (_selectedTier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a ticket tier.')));
      return;
    }
    final currentUser = await _authRepository.authStateChanges.first;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }
    setState(() => _isLoading = true);

    // PLATFORM-SPECIFIC PAYMENT LOGIC
    if (kIsWeb) {
      // WEB FLOW: Redirect to PayHere website
      await _handleWebCheckout(currentUser);
    } else {
      // MOBILE FLOW: Use the native SDK
      _handleMobileCheckout(currentUser);
    }
  }

  // Handles the Web Checkout Flow
  Future<void> _handleWebCheckout(currentUser) async {
    final orderId = '${currentUser.uid}-${DateTime.now().millisecondsSinceEpoch}';
    final totalAmount = _selectedTier!.price * _quantity;
    final merchantId = PayHereService.sandboxMerchantId;
    final currency = 'LKR';

    final uri = Uri.https(
      'us-central1-ceylontix-app.cloudfunctions.net',
      '/payHereCheckout',
      {
        'merchant_id': merchantId,
        'order_id': orderId,
        'items': '${_quantity}x ${_selectedTier!.name} Ticket(s) for ${widget.event.name}',
        'amount': totalAmount.toStringAsFixed(2),
        'currency': currency,
        'first_name': currentUser.displayName?.split(' ').first ?? 'John',
        'last_name': currentUser.displayName?.split(' ').last ?? 'Doe',
        'email': currentUser.email ?? '',
        'phone': '0771234567',
        'address': 'No. 1, Galle Road',
        'city': 'Colombo',
        'country': 'Sri Lanka',
        'sandbox': 'true',
      },
    );

    // Directly open the payment form in a new tab
    if (!mounted) return;
    final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open payment page. Please allow pop-ups and try again.')),

      );
    } else {
      // Optionally, you can create the booking after payment confirmation
      // await _createBookingInFirestore(currentUser);
    }
  }

  // Handles the Mobile Checkout Flow
  void _handleMobileCheckout(currentUser) {
    final customerDetails = {
      'firstName': currentUser.displayName?.split(' ').first ?? 'John',
      'lastName': currentUser.displayName?.split(' ').last ?? 'Doe',
      'email': currentUser.email ?? 'no-email@test.com',
      'phone': '0771234567',
      'address': 'No. 1, Galle Road',
      'city': 'Colombo'
    };
    final orderId = '${currentUser.uid}-${DateTime.now().millisecondsSinceEpoch}';
    final totalAmount = _selectedTier!.price * _quantity;

    PayHereService.startPayment(
      context: context,
      amount: totalAmount,
      orderId: orderId,
      itemName: '${_quantity}x ${_selectedTier!.name} Ticket(s)',
      customerDetails: customerDetails,
      onSuccess: (paymentId) => _createBookingInFirestore(currentUser),
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $error'), backgroundColor: Colors.red));
        if (mounted) setState(() => _isLoading = false);
      },
      onDismissed: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment process was cancelled.')));
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }
  
  // Creates the booking record in Firestore after a successful payment
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
          builder: (_) => TicketViewScreen(booking: newBooking, bookingId: newBookingId),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking Failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
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
              title: Text(widget.event.name, style: const TextStyle(shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              background: Hero(
                tag: 'event_poster_${widget.event.id ?? widget.event.posterUrl.hashCode}',
                child: Image.network(
                  widget.event.posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
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
                  Text('Date: ${_formatDateTime(widget.event.date)}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Venue: ${widget.event.venue}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Text(widget.event.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const Divider(height: 40),
                  const Text('Select Ticket Tier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...widget.event.ticketTiers.map((tier) {
                    final bool isAvailable = tier.quantity > 0;
                    return RadioListTile<TicketTier>(
                      title: Text(tier.name),
                      subtitle: Text('LKR ${tier.price.toStringAsFixed(2)} - ${isAvailable ? "${tier.quantity} available" : "Sold Out"}'),
                      value: tier,
                      groupValue: _selectedTier,
                      onChanged: isAvailable ? (value) => setState(() {
                        _selectedTier = value;
                        _quantity = 1;
                      }) : null,
                      activeColor: Theme.of(context).primaryColor,
                    );
                  }),
                  const SizedBox(height: 20),
                  if (_selectedTier != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(onPressed: _decrementQuantity, icon: const Icon(Icons.remove_circle_outline)),
                        Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: _incrementQuantity, icon: const Icon(Icons.add_circle_outline)),
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
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _handleCheckout,
                                  icon: const Icon(Icons.shopping_cart_checkout),
                                  label: const Text('Proceed to Checkout'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
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