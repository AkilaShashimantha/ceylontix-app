import 'package:ceylontix_app/src/domain/entities/booking.dart';
import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_booking_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import 'profile_screen.dart';

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

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
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
        content: const Text('You need to be logged in to book tickets. Please log in or create an account.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Login / Sign Up'),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close the dialog
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleBooking() async {
    if (_selectedTier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a ticket tier.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final currentUser = _authRepository.authStateChanges.first;
    final user = await currentUser;

    if (user == null) {
      _showLoginPrompt();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newBooking = Booking(
        eventId: widget.event.id!,
        eventName: widget.event.name,
        userId: user.uid,
        userName: user.displayName ?? 'N/A',
        userEmail: user.email ?? 'N/A',
        tierName: _selectedTier!.name,
        quantity: _quantity,
        totalPrice: _selectedTier!.price * _quantity,
        bookingDate: DateTime.now(),
      );

      await _bookingRepository.createBooking(
        booking: newBooking,
        event: widget.event,
        tierName: _selectedTier!.name,
        quantity: _quantity,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Booking Successful!'),
            content: Text('You have successfully booked $_quantity ticket(s) for ${widget.event.name}. A confirmation will be sent to your email.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // Go back from detail screen
                },
              ),
            ],
          ),
        );
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
                  // Event Info
                  Text('Date: ${_formatDateTime(widget.event.date)}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Venue: ${widget.event.venue}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Text(widget.event.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const Divider(height: 40),

                  // Ticket Selection
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
                        _quantity = 1; // Reset quantity on tier change
                      }) : null,
                      activeColor: Theme.of(context).primaryColor,
                    );
                  }).toList(),
                  const SizedBox(height: 20),

                  // Quantity Selector
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

                  // Total Price and Booking Button
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
                                  onPressed: _handleBooking,
                                  icon: const Icon(Icons.confirmation_number),
                                  label: const Text('Book Now'),
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

