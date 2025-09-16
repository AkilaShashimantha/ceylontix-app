import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  String? _scannedData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Ticket QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front, color: Colors.white);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear, color: Colors.white);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: _handleBarcode,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Point the camera at a ticket QR code',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning ? 'Scanning...' : 'Processing...',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isScanning ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_scannedData != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showTicketDetails(_scannedData!),
                      child: const Text('View Last Scanned Ticket'),
                    ),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _scannedData = barcode.rawValue!;
          _isScanning = false;
        });
        _showTicketDetails(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _showTicketDetails(String qrData) async {
    try {
      // Parse QR code data
      final Map<String, dynamic> ticketData = jsonDecode(qrData);
      
      // Fetch booking details from Firestore
      final bookingId = ticketData['bookingId'];
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!mounted) return;

      if (!bookingDoc.exists) {
        _showErrorDialog('Invalid QR Code', 'This ticket could not be found in our system.');
        return;
      }

      final bookingData = bookingDoc.data()!;
      
      // Show ticket details dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ticket Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Event', bookingData['eventName'] ?? 'N/A'),
                  _buildDetailRow('Booking ID', bookingId),
                  _buildDetailRow('Customer', bookingData['userName'] ?? 'N/A'),
                  _buildDetailRow('Email', bookingData['userEmail'] ?? 'N/A'),
                  _buildDetailRow('Phone', bookingData['phone'] ?? 'N/A'),
                  _buildDetailRow('Ticket Tier', bookingData['tierName'] ?? 'N/A'),
                  _buildDetailRow('Quantity', '${bookingData['quantity'] ?? 'N/A'}'),
                  _buildDetailRow('Total Price', 'LKR ${(bookingData['totalPrice'] ?? 0.0).toStringAsFixed(2)}'),
                  _buildDetailRow('Status', bookingData['status'] ?? 'N/A'),
                  _buildDetailRow('Booking Date', 
                    bookingData['bookingDate'] != null 
                      ? (bookingData['bookingDate'] as Timestamp).toDate().toString()
                      : 'N/A'
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resumeScanning();
                },
                child: const Text('Close'),
              ),
              if (bookingData['status'] == 'confirmed')
                ElevatedButton(
                  onPressed: () => _markAsUsed(bookingId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Mark as Used'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Invalid QR Code', 'The QR code format is not recognized.');
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsUsed(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'used',
        'usedDate': Timestamp.now(),
      });
      
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket marked as used successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resumeScanning();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resumeScanning();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _resumeScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
