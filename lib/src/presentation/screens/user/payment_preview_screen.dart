import 'package:flutter/material.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';

class PaymentPreviewScreen extends StatelessWidget {
  final Event event;
  final TicketTier selectedTier;
  final int quantity;
  final Map<String, String> userDetails;
  final VoidCallback onConfirmPayment;

  const PaymentPreviewScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.quantity,
    required this.userDetails,
    required this.onConfirmPayment,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = selectedTier.price * quantity;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Preview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // CeylonTix Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo/app_logo.png',
                    height: 60,
                    width: 60,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CeylonTix',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'Secure Payment Gateway',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Summary Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 20),
                    
                    _buildSummaryRow(context, 'Event', event.name),
                    _buildSummaryRow(context, 'Ticket Tier', selectedTier.name),
                    _buildSummaryRow(context, 'Unit Price', 'LKR ${selectedTier.price.toStringAsFixed(2)}'),
                    _buildSummaryRow(context, 'Quantity', quantity.toString()),
                    const Divider(height: 16),
                    _buildSummaryRow(
                      context,
                      'Total Amount', 
                      'LKR ${totalAmount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Customer Details Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 20),
                    
                    _buildSummaryRow(context, 'Name', '${userDetails['firstName']} ${userDetails['lastName']}'),
                    _buildSummaryRow(context, 'Phone', userDetails['phone'] ?? 'N/A'),
                    _buildSummaryRow(context, 'Address', userDetails['address'] ?? 'N/A'),
                    _buildSummaryRow(context, 'City', userDetails['city'] ?? 'N/A'),
                    _buildSummaryRow(context, 'NIC', userDetails['nic'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.security, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Secure Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You will be redirected to PayHere secure payment gateway',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onConfirmPayment,
                icon: const Icon(Icons.payment),
                label: Text('Pay LKR ${totalAmount.toStringAsFixed(2)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel Payment',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
