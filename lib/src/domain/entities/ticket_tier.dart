// Represents a single pricing tier for an event.
class TicketTier {
  final String name;
  final double price;
  final int quantity;

  TicketTier({
    required this.name,
    required this.price,
    required this.quantity,
  });

  // Converts a TicketTier instance to a Map, suitable for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  // Creates a TicketTier instance from a Map (e.g., from Firestore).
  factory TicketTier.fromJson(Map<String, dynamic> json) {
    return TicketTier(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
    );
  }
}
